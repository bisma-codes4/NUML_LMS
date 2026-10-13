const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
app.use(cors());
app.use(express.json());

mongoose.connect('mongodb://localhost:27017/NUML_LMS')
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.log(err));

const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret-numl-lms-2026';

// Sirf in emails wale students app se data add/edit/delete kar sakte hain
// Apni email yahan add karo (lowercase mein)
const ADMIN_EMAILS = ['bisma@gmail.com', 'malaika123@gmail.com'];
const isAdminEmail = e => ADMIN_EMAILS.includes(String(e || '').trim().toLowerCase());

// Roles: 'student' (default), 'teacher', 'admin'. Role Students collection ke "role" field se aata hai.
// ADMIN_EMAILS wale hamesha admin hote hain.
const roleOf = st => {
  if (!st) return 'student';
  if (isAdminEmail(st.email) || st.role === 'admin') return 'admin';
  return st.role === 'teacher' ? 'teacher' : 'student';
};
// Teacher sirf in collections ko manage kar sakta hai (admin sab kuch)
const TEACHER_COLS = ['assignments', 'announcements', 'attendance', 'marks', 'submissions', 'timetable'];
const allowed = (role, c) => role === 'admin' || (role === 'teacher' && TEACHER_COLS.includes(c));
// Ek student maximum itne credit hours le sakta hai
const MAX_CREDITS = 18;

// ---------- simple rate limit (5 galat koshishein / 15 min / IP) ----------
const fails = {};
const tooMany = ip => {
  const f = fails[ip];
  return f && f.count >= 5 && Date.now() - f.first < 15 * 60 * 1000;
};
const addFail = ip => {
  const f = fails[ip];
  if (!f || Date.now() - f.first >= 15 * 60 * 1000) fails[ip] = { count: 1, first: Date.now() };
  else f.count++;
};

// signup spam limit (10 accounts / ghanta / IP)
const signups = {};
const signupBlocked = ip => {
  const s = signups[ip];
  return s && s.count >= 10 && Date.now() - s.first < 60 * 60 * 1000;
};
const addSignup = ip => {
  const s = signups[ip];
  if (!s || Date.now() - s.first >= 60 * 60 * 1000) signups[ip] = { count: 1, first: Date.now() };
  else s.count++;
};

// ---------- AUTH middleware ----------
function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const t = h.startsWith('Bearer ') ? h.slice(7) : '';
  try {
    req.user = jwt.verify(t, JWT_SECRET);
    next();
  } catch (e) {
    res.status(401).json({ error: 'Unauthorized' });
  }
}

// ---------- LOGIN ----------
app.post('/login', async (req, res) => {
  const { email, password } = req.body || {};
  if (typeof email !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ error: 'Email and password required' });
  }
  if (tooMany(req.ip)) {
    return res.status(429).json({ error: 'Too many attempts. Try again in 15 minutes.' });
  }
  const col = mongoose.connection.db.collection('Students');
  const em = email.trim();
  const st = await col.findOne({ email: { $in: [em, em.toLowerCase()] }, deletedDate: null });
  let ok = false;
  if (st && typeof st.password === 'string') {
    if (st.password.startsWith('$2')) {
      ok = await bcrypt.compare(password, st.password);
    } else if (st.password === password) {
      // purana plain-text password: pehli login par hash mein badal do
      ok = true;
      await col.updateOne({ _id: st._id }, { $set: { password: await bcrypt.hash(password, 10) } });
    }
  }
  if (!ok) {
    addFail(req.ip);
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  delete fails[req.ip];
  const token = jwt.sign({ studentId: st.studentId }, JWT_SECRET, { expiresIn: '12h' });
  res.json({ token, student: { studentId: st.studentId, name: st.name, email: st.email, isAdmin: roleOf(st) === 'admin', role: roleOf(st) } });
});

// ---------- helpers ----------
const clean = (v, max) => (typeof v === 'string' ? v.trim().slice(0, max) : null);
const col = name => mongoose.connection.db.collection(name);

async function nextId(collection, field, prefix) {
  const all = await col(collection).find({}, { projection: { [field]: 1 } }).toArray();
  let max = 0;
  for (const d of all) {
    const n = parseInt(String(d[field] || '').replace(/\D/g, ''), 10);
    if (n > max) max = n;
  }
  return prefix + String(max + 1).padStart(3, '0');
}

async function checkPassword(st, plain) {
  if (!st || typeof st.password !== 'string') return false;
  if (st.password.startsWith('$2')) return bcrypt.compare(plain, st.password);
  return st.password === plain;
}

const myStudent = req => col('Students').findOne({ studentId: req.user.studentId, deletedDate: null });

// Student wale features (course add/drop, ID card, assignment submit, registration) sirf students ke liye
async function studentOnly(req, res, next) {
  const st = await myStudent(req);
  if (!st) return res.status(404).json({ error: 'Student not found' });
  if (roleOf(st) !== 'student') {
    return res.status(403).json({ error: 'This feature is only for students.' });
  }
  next();
}

// staffOnly ke baad lagao: sirf admin
function adminRole(req, res, next) {
  if (req.role !== 'admin') return res.status(403).json({ error: 'Only an admin can do this.' });
  next();
}

// ---------- PUBLIC: signup form ke dropdowns ----------
app.get('/public/options', async (req, res) => {
  try {
    const get = n => col(n).find({ deletedDate: null }).toArray();
    const [deps, genders, areas, cities] = await Promise.all([
      get('department'), get('gender'), get('area'), get('city'),
    ]);
    const m = (l, k) => l.map(d => ({ id: d[k], label: d.name }));
    res.json({
      departments: m(deps, 'departmentId'),
      genders: m(genders, 'genderId'),
      areas: m(areas, 'areaId'),
      cities: m(cities, 'cityId'),
    });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

// ---------- PUBLIC: CREATE ACCOUNT ----------
app.post('/signup', async (req, res) => {
  try {
    if (signupBlocked(req.ip)) {
      return res.status(429).json({ error: 'Too many accounts created. Try again later.' });
    }
    const b = req.body || {};
    const name = clean(b.name, 100), fName = clean(b.fName, 100);
    const emailRaw = clean(b.email, 100);
    const email = emailRaw && emailRaw.toLowerCase();
    const rollNo = clean(b.rollNo, 30), registrationNo = clean(b.registrationNo, 30);
    const genderId = clean(b.genderId, 20), departmentId = clean(b.departmentId, 20);
    const areaId = clean(b.areaId, 20), cityId = clean(b.cityId, 20);
    const phone = clean(b.phone, 20) || '', address = clean(b.address, 200) || '';
    const dob = new Date(String(b.DateOfBirth || ''));
    const password = typeof b.password === 'string' ? b.password : '';

    if (![name, fName, email, rollNo, registrationNo, genderId, departmentId, areaId, cityId].every(Boolean)) {
      return res.status(400).json({ error: 'Please fill in all required fields.' });
    }
    if (!/^\S+@\S+\.\S+$/.test(email)) return res.status(400).json({ error: 'Invalid email address.' });
    if (isNaN(dob.getTime())) return res.status(400).json({ error: 'Invalid date of birth.' });
    if (password.length < 6) return res.status(400).json({ error: 'Password must be at least 6 characters.' });
    if (isAdminEmail(email)) return res.status(403).json({ error: 'This email cannot be used for signup.' });
    if (phone && !/^[0-9+\-\s]{7,20}$/.test(phone)) return res.status(400).json({ error: 'Invalid phone number.' });

    const refs = [
      ['gender', 'genderId', genderId], ['department', 'departmentId', departmentId],
      ['area', 'areaId', areaId], ['city', 'cityId', cityId],
    ];
    for (const [c, k, v] of refs) {
      if (!(await col(c).findOne({ [k]: v, deletedDate: null }))) {
        return res.status(400).json({ error: `${k} was not found in the database.` });
      }
    }
    const dupEmail = await col('Students').findOne({ email: { $in: [email, emailRaw] }, deletedDate: null });
    if (dupEmail) return res.status(400).json({ error: 'This email is already registered.' });
    if (await col('Students').findOne({ rollNo, deletedDate: null })) {
      return res.status(400).json({ error: 'This roll number already exists.' });
    }

    const id = await nextId('Students', 'studentId', 'S');
    await col('Students').insertOne({
      studentId: id, name, fName, caste: '', genderId, departmentId, rollNo, registrationNo,
      DateOfBirth: dob, email, phone, address, areaId, cityId,
      password: await bcrypt.hash(password, 10),
      createdId: id, createdDate: new Date(),
      updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
    });
    addSignup(req.ip);
    res.json({ ok: true });
  } catch (e) {
    console.log(e);
    res.status(500).json({ error: 'Could not create the account.' });
  }
});

// ---------- CHANGE PASSWORD ----------
app.post('/change-password', auth, async (req, res) => {
  const { oldPassword, newPassword } = req.body || {};
  if (typeof oldPassword !== 'string' || typeof newPassword !== 'string') {
    return res.status(400).json({ error: 'Both current and new passwords are required.' });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters.' });
  }
  if (newPassword === oldPassword) {
    return res.status(400).json({ error: 'New password must be different from the current one.' });
  }
  const st = await myStudent(req);
  if (!(await checkPassword(st, oldPassword))) {
    return res.status(400).json({ error: 'Current password is incorrect.' });
  }
  await col('Students').updateOne(
    { _id: st._id },
    { $set: { password: await bcrypt.hash(newPassword, 10), updatedBy: st.studentId, updatedDate: new Date() } }
  );
  res.json({ ok: true });
});

// ---------- PROFILE EDIT (sirf phone aur address) ----------
app.put('/profile', auth, async (req, res) => {
  const phone = clean((req.body || {}).phone, 20);
  const address = clean((req.body || {}).address, 200);
  if (phone === null || address === null) {
    return res.status(400).json({ error: 'Phone and address must be text.' });
  }
  if (phone && !/^[0-9+\-\s]{7,20}$/.test(phone)) {
    return res.status(400).json({ error: 'Invalid phone number.' });
  }
  const st = await myStudent(req);
  if (!st) return res.status(404).json({ error: 'Student not found' });
  await col('Students').updateOne(
    { _id: st._id },
    { $set: { phone, address, updatedBy: st.studentId, updatedDate: new Date() } }
  );
  res.json({ ok: true });
});

// ---------- ASSIGNMENT SUBMIT ----------
app.post('/assignments/:id/submit', auth, studentOnly, async (req, res) => {
  const text = clean((req.body || {}).text, 5000);
  if (!text) return res.status(400).json({ error: 'Please write your answer first.' });
  const st = await myStudent(req);
  if (!st) return res.status(404).json({ error: 'Student not found' });
  const asg = await col('assignments').findOne({ assignmentId: req.params.id, deletedDate: null });
  if (!asg) return res.status(404).json({ error: 'Assignment not found.' });
  const enr = await col('enrollment').findOne({ studentId: st.studentId, courseId: asg.courseId, status: 'enrolled', deletedDate: null });
  if (!enr) {
    return res.status(403).json({ error: 'You are not enrolled in this course.' });
  }
  const dueEnd = new Date(asg.dueDate).getTime() + 24 * 60 * 60 * 1000;
  if (Date.now() > dueEnd) {
    return res.status(400).json({ error: 'The deadline has passed.' });
  }
  const filter = { assignmentId: asg.assignmentId, studentId: st.studentId, deletedDate: null };
  const existing = await col('submissions').findOne(filter);
  if (existing) {
    await col('submissions').updateOne(
      { _id: existing._id },
      { $set: { text, submittedDate: new Date(), updatedBy: st.studentId, updatedDate: new Date() } }
    );
  } else {
    await col('submissions').insertOne({
      submissionId: await nextId('submissions', 'submissionId', 'SB'),
      assignmentId: asg.assignmentId,
      studentId: st.studentId,
      text,
      submittedDate: new Date(),
      createdId: st.studentId,
      createdDate: new Date(),
      updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
    });
  }
  res.json({ ok: true });
});

// ---------- SEMESTER REGISTRATION ----------
app.post('/register', auth, studentOnly, async (req, res) => {
  const sessionId = clean((req.body || {}).sessionId, 20);
  const semesterId = clean((req.body || {}).semesterId, 20);
  if (!sessionId || !semesterId) return res.status(400).json({ error: 'Please select a session and semester.' });
  const st = await myStudent(req);
  if (!st) return res.status(404).json({ error: 'Student not found' });
  const [ses, sem] = await Promise.all([
    col('session').findOne({ sessionId, deletedDate: null }),
    col('semester').findOne({ semesterId, deletedDate: null }),
  ]);
  if (!ses || !sem) return res.status(400).json({ error: 'Invalid session or semester.' });
  const dup = await col('registration').findOne({ studentId: st.studentId, sessionId, semesterId, deletedDate: null });
  if (dup) return res.status(400).json({ error: 'You are already registered for this session and semester.' });
  await col('registration').insertOne({
    registrationId: await nextId('registration', 'registrationId', 'RG'),
    studentId: st.studentId, sessionId, semesterId,
    registrationDate: new Date(), status: 'registered',
    createdId: st.studentId, createdDate: new Date(),
    updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
  });
  res.json({ ok: true });
});

// ---------- COURSE ADD / DROP ----------
app.post('/enroll', auth, studentOnly, async (req, res) => {
  const courseId = clean((req.body || {}).courseId, 20);
  if (!courseId) return res.status(400).json({ error: 'Please select a course.' });
  const st = await myStudent(req);
  if (!st) return res.status(404).json({ error: 'Student not found' });
  const course = await col('course').findOne({ courseId, deletedDate: null });
  if (!course || course.departmentId !== st.departmentId) {
    return res.status(403).json({ error: 'This course does not belong to your department.' });
  }
  const mine = await col('enrollment').find({ studentId: st.studentId, deletedDate: null }).toArray();
  const active = mine.filter(e => e.status === 'enrolled');
  if (active.some(e => e.courseId === courseId)) {
    return res.status(400).json({ error: 'You are already enrolled in this course.' });
  }
  const cs = await col('course').find({ courseId: { $in: active.map(e => e.courseId) }, deletedDate: null }).toArray();
  const credits = cs.reduce((s, c) => s + (Number(c.creditHours) || 0), 0);
  if (credits + (Number(course.creditHours) || 0) > MAX_CREDITS) {
    return res.status(400).json({ error: `This would exceed the credit hour limit (${MAX_CREDITS}).` });
  }
  const old = mine.find(e => e.courseId === courseId);
  if (old) {
    await col('enrollment').updateOne(
      { _id: old._id },
      { $set: { status: 'enrolled', enrollDate: new Date(), updatedBy: st.studentId, updatedDate: new Date() } }
    );
  } else {
    await col('enrollment').insertOne({
      enrollmentId: await nextId('enrollment', 'enrollmentId', 'EN'),
      studentId: st.studentId, courseId, status: 'enrolled', enrollDate: new Date(),
      createdId: st.studentId, createdDate: new Date(),
      updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
    });
  }
  res.json({ ok: true });
});

app.post('/drop', auth, studentOnly, async (req, res) => {
  const courseId = clean((req.body || {}).courseId, 20);
  if (!courseId) return res.status(400).json({ error: 'Please select a course.' });
  const st = await myStudent(req);
  if (!st) return res.status(404).json({ error: 'Student not found' });
  const e = await col('enrollment').findOne({ studentId: st.studentId, courseId, status: 'enrolled', deletedDate: null });
  if (!e) return res.status(404).json({ error: 'You are not enrolled in this course.' });
  await col('enrollment').updateOne(
    { _id: e._id },
    { $set: { status: 'dropped', updatedBy: st.studentId, updatedDate: new Date() } }
  );
  res.json({ ok: true });
});

// ---------- ID CARD REQUEST ----------
app.post('/idcard/request', auth, studentOnly, async (req, res) => {
  const st = await myStudent(req);
  if (!st) return res.status(404).json({ error: 'Student not found' });
  const ex = await col('stu_Idcard').findOne({ studentId: st.studentId, deletedDate: null, status: { $in: ['active', 'pending'] } });
  if (ex) {
    return res.status(400).json({ error: ex.status === 'pending' ? 'Your request is already pending.' : 'Your ID card is already active.' });
  }
  const now = new Date();
  const exp = new Date(now);
  exp.setFullYear(exp.getFullYear() + 4);
  await col('stu_Idcard').insertOne({
    idCardId: await nextId('stu_Idcard', 'idCardId', 'IDC'),
    studentId: st.studentId,
    cardNo: `NUML-${st.rollNo}-${now.getFullYear()}`,
    issueDate: now, expiryDate: exp, photo: '', status: 'pending',
    createdId: st.studentId, createdDate: now,
    updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
  });
  res.json({ ok: true });
});

// ---------- STAFF (teacher / admin): bulk attendance & marks ----------
async function rosterOf(courseId) {
  const en = await col('enrollment').find({ courseId, status: 'enrolled', deletedDate: null }).toArray();
  const ids = en.map(e => e.studentId);
  return col('Students').find({ studentId: { $in: ids }, deletedDate: null }).sort({ rollNo: 1 }).toArray();
}

app.get('/staff/courses', auth, staffOnly, async (req, res) => {
  const mine = req.role === 'admin' ? {} : { teacherId: req.admin.studentId };
  const l = await col('course').find({ deletedDate: null, ...mine }).sort({ code: 1 }).toArray();
  res.json(l.map(c => ({ id: c.courseId, label: `${c.code} - ${c.name}` })));
});

app.get('/staff/roster/:courseId', auth, staffOnly, async (req, res) => {
  if (!(await canTeach(req, req.params.courseId))) return res.status(403).json({ error: 'This course is not assigned to you.' });
  const r = await rosterOf(req.params.courseId);
  res.json(r.map(s => ({ studentId: s.studentId, name: s.name, rollNo: s.rollNo })));
});

app.post('/staff/attendance', auth, staffOnly, async (req, res) => {
  const b = req.body || {};
  const courseId = clean(b.courseId, 20);
  const d = new Date(String(b.date || ''));
  if (!courseId || isNaN(d.getTime())) return res.status(400).json({ error: 'Select a course and a valid date.' });
  if (!Array.isArray(b.records) || !b.records.length) return res.status(400).json({ error: 'There are no students in this course.' });
  if (!(await col('course').findOne({ courseId, deletedDate: null }))) return res.status(404).json({ error: 'Course not found.' });
  if (!(await canTeach(req, courseId))) return res.status(403).json({ error: 'This course is not assigned to you.' });
  const ok = new Set((await rosterOf(courseId)).map(s => s.studentId));
  let saved = 0;
  for (const r of b.records) {
    if (!r || !ok.has(r.studentId) || !['present', 'absent'].includes(r.status)) continue;
    const f = { studentId: r.studentId, courseId, date: d, deletedDate: null };
    const ex = await col('attendance').findOne(f);
    if (ex) {
      await col('attendance').updateOne({ _id: ex._id },
        { $set: { status: r.status, updatedBy: req.admin.studentId, updatedDate: new Date() } });
    } else {
      await col('attendance').insertOne({
        attendanceId: await nextId('attendance', 'attendanceId', 'AT'),
        studentId: r.studentId, courseId, date: d, status: r.status,
        createdId: req.admin.studentId, createdDate: new Date(),
        updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
      });
    }
    saved++;
  }
  res.json({ ok: true, saved });
});

app.post('/staff/marks', auth, staffOnly, async (req, res) => {
  const b = req.body || {};
  const courseId = clean(b.courseId, 20);
  const examType = clean(b.examType, 30);
  const total = Number(b.totalMarks);
  if (!courseId || !EXAMS.includes(examType) || !Number.isFinite(total) || total <= 0) {
    return res.status(400).json({ error: 'Enter a valid course, exam type and total marks.' });
  }
  const course = await col('course').findOne({ courseId, deletedDate: null });
  if (!course) return res.status(404).json({ error: 'Course not found.' });
  if (!(await canTeach(req, courseId))) return res.status(403).json({ error: 'This course is not assigned to you.' });
  if (!Array.isArray(b.records) || !b.records.length) return res.status(400).json({ error: 'No marks were sent.' });
  const ok = new Set((await rosterOf(courseId)).map(s => s.studentId));
  let saved = 0;
  for (const r of b.records) {
    if (!r || !ok.has(r.studentId)) continue;
    if (r.obtained === undefined || r.obtained === null || String(r.obtained).trim() === '') continue;
    const ob = Number(r.obtained);
    if (!Number.isFinite(ob) || ob < 0 || ob > total) {
      return res.status(400).json({ error: `Marks must be between 0 and ${total}.` });
    }
    const f = { studentId: r.studentId, courseId, examType, deletedDate: null };
    const ex = await col('marks').findOne(f);
    if (ex) {
      await col('marks').updateOne({ _id: ex._id },
        { $set: { totalMarks: total, obtainedMarks: ob, updatedBy: req.admin.studentId, updatedDate: new Date() } });
    } else {
      await col('marks').insertOne({
        marksId: await nextId('marks', 'marksId', 'M'),
        studentId: r.studentId, courseId, semesterId: course.semesterId, examType,
        totalMarks: total, obtainedMarks: ob,
        createdId: req.admin.studentId, createdDate: new Date(),
        updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
      });
    }
    saved++;
  }
  res.json({ ok: true, saved });
});

// =====================================================================
// ADMIN: har collection ke liye generic add / edit / delete (soft delete)
// Naya field chahiye? Bas neeche SCHEMA mein ek line add karo.
// =====================================================================
const T = (key, label, o = {}) => ({ key, label, type: 'text', ...o });
const NUM = (key, label, o = {}) => ({ key, label, type: 'number', ...o });
const DT = (key, label, o = {}) => ({ key, label, type: 'date', ...o });
const REF = (key, label, ref, o = {}) => ({ key, label, type: 'ref', ref, ...o });
const SEL = (key, label, options, o = {}) => ({ key, label, type: 'select', options, ...o });
const EXAMS = ['Midterm', 'Final', 'Quiz', 'Assignment'];
const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const SCHEMA = {
  uni_info: { title: 'University', id: ['uniId', 'UN'],
    fields: [T('name', 'Name'), T('address', 'Address'), T('phone', 'Phone'), T('email', 'Email')] },
  department: { title: 'Department', id: ['departmentId', 'D'],
    fields: [REF('uniId', 'University', 'uni_info'), T('name', 'Name')] },
  country: { title: 'Country', id: ['countryId', 'CN'],
    fields: [T('name', 'Name'), T('code', 'Code'), T('phoneCode', 'Phone Code')] },
  province: { title: 'Province', id: ['provinceId', 'PR'],
    fields: [REF('countryId', 'Country', 'country'), T('name', 'Name'), T('code', 'Code')] },
  city: { title: 'City', id: ['cityId', 'CT'],
    fields: [REF('provinceId', 'Province', 'province'), T('name', 'Name')] },
  area: { title: 'Area', id: ['areaId', 'AR'],
    fields: [REF('cityId', 'City', 'city'), T('name', 'Name')] },
  gender: { title: 'Gender', id: ['genderId', 'G'], fields: [T('name', 'Name')] },
  semester: { title: 'Semester', id: ['semesterId', 'SM'],
    fields: [T('name', 'Name'), NUM('number', 'Number')] },
  session: { title: 'Session', id: ['sessionId', 'SE'],
    fields: [T('name', 'Name'), DT('startDate', 'Start Date'), DT('endDate', 'End Date')] },
  shift: { title: 'Shift', id: ['shiftId', 'SH'],
    fields: [T('name', 'Name'), T('startTime', 'Start Time (HH:MM)'), T('endTime', 'End Time (HH:MM)')] },
  course: { title: 'Course', id: ['courseId', 'C'],
    fields: [REF('departmentId', 'Department', 'department'), REF('semesterId', 'Semester', 'semester'),
      T('code', 'Code'), T('name', 'Name'), NUM('creditHours', 'Credit Hours'),
      REF('teacherId', 'Teacher', 'Students', { optional: true })] },
  Students: { title: 'Students', id: ['studentId', 'S'], unique: ['email', 'rollNo'],
    fields: [T('name', 'Name'), T('fName', 'Father Name'), T('caste', 'Caste', { optional: true }),
      REF('genderId', 'Gender', 'gender'), REF('departmentId', 'Department', 'department'),
      T('rollNo', 'Roll No'), T('registrationNo', 'Registration No'), DT('DateOfBirth', 'Date of Birth'),
      T('email', 'Email'), T('phone', 'Phone', { optional: true }), T('address', 'Address', { optional: true }),
      REF('areaId', 'Area', 'area'), REF('cityId', 'City', 'city'),
      SEL('role', 'Role', ['student', 'teacher', 'admin'], { optional: true }),
      { key: 'password', label: 'Password', type: 'password' }] },
  announcements: { title: 'Announcements', id: ['announcementId', 'AN'],
    fields: [T('title', 'Title'), T('message', 'Message', { multiline: true }),
      REF('departmentId', 'Department', 'department', { optional: true }), DT('announcementDate', 'Announcement Date'),
      DT('expiryDate', 'Expiry Date'), SEL('status', 'Status', ['active', 'inactive'])] },
  assignments: { title: 'Assignments', id: ['assignmentId', 'AS'],
    fields: [T('title', 'Title'), REF('courseId', 'Course', 'course'), DT('dueDate', 'Due Date'),
      T('description', 'Description', { optional: true, multiline: true }),
      NUM('totalMarks', 'Total Marks', { optional: true })] },
  attendance: { title: 'Attendance', id: ['attendanceId', 'AT'],
    fields: [REF('studentId', 'Student', 'Students'), REF('courseId', 'Course', 'course'),
      DT('date', 'Date'), SEL('status', 'Status', ['present', 'absent'])] },
  marks: { title: 'Marks', id: ['marksId', 'M'],
    fields: [REF('studentId', 'Student', 'Students'), REF('courseId', 'Course', 'course'),
      REF('semesterId', 'Semester', 'semester'), SEL('examType', 'Exam Type', EXAMS),
      NUM('totalMarks', 'Total Marks'), NUM('obtainedMarks', 'Obtained Marks')] },
  timetable: { title: 'Timetable', id: ['timetableId', 'TT'],
    fields: [REF('courseId', 'Course', 'course'), REF('departmentId', 'Department', 'department'),
      REF('shiftId', 'Shift', 'shift'), SEL('day', 'Day', DAYS),
      T('startTime', 'Start Time (HH:MM)'), T('endTime', 'End Time (HH:MM)'), T('room', 'Room')] },
  registration: { title: 'Registration', id: ['registrationId', 'RG'],
    fields: [REF('studentId', 'Student', 'Students'), REF('sessionId', 'Session', 'session'),
      REF('semesterId', 'Semester', 'semester'), DT('registrationDate', 'Registration Date'),
      SEL('status', 'Status', ['registered', 'pending', 'dropped'])] },
  enrollment: { title: 'Enrollment', id: ['enrollmentId', 'EN'],
    fields: [REF('studentId', 'Student', 'Students'), REF('courseId', 'Course', 'course'),
      DT('enrollDate', 'Enroll Date'), SEL('status', 'Status', ['enrolled', 'dropped'])] },
  examslip: { title: 'Exam Slip', id: ['examslipId', 'ES'],
    fields: [REF('studentId', 'Student', 'Students'), REF('semesterId', 'Semester', 'semester'),
      SEL('examType', 'Exam Type', ['Midterm', 'Final']), DT('issueDate', 'Issue Date')] },
  feeChallan: { title: 'Fee Challan', id: ['challanId', 'FC'],
    fields: [REF('studentId', 'Student', 'Students'), REF('semesterId', 'Semester', 'semester'),
      NUM('amount', 'Amount'), DT('dueDate', 'Due Date'), SEL('status', 'Status', ['unpaid', 'paid']),
      DT('paidDate', 'Paid Date', { optional: true })] },
  stu_Idcard: { title: 'ID Card', id: ['idCardId', 'IDC'],
    fields: [REF('studentId', 'Student', 'Students'), T('cardNo', 'Card No'), DT('issueDate', 'Issue Date'),
      DT('expiryDate', 'Expiry Date'), T('photo', 'Photo URL', { optional: true }),
      SEL('status', 'Status', ['pending', 'active', 'expired', 'blocked'])] },
  submissions: { title: 'Submissions', id: ['submissionId', 'SB'],
    fields: [REF('assignmentId', 'Assignment', 'assignments'), REF('studentId', 'Student', 'Students'),
      T('text', 'Answer', { multiline: true }), DT('submittedDate', 'Submitted Date'),
      NUM('grade', 'Marks Obtained (teacher)', { optional: true }),
      T('feedback', 'Feedback (teacher)', { optional: true, multiline: true })] },
};

const hasSchema = c => Object.prototype.hasOwnProperty.call(SCHEMA, c);
const idKey = c => SCHEMA[c].id[0];

function labelOf(c, d) {
  if (c === 'course') return `${d.code} - ${d.name}`;
  if (c === 'Students') return `${d.name} (${d.rollNo})`;
  return d.name || d.title || d[idKey(c)];
}

// teacher aur admin dono ke liye (collection ki ijazat har route mein allowed() se check hoti hai)
async function staffOnly(req, res, next) {
  const st = await myStudent(req);
  const r = roleOf(st);
  if (!st || r === 'student') {
    return res.status(403).json({ error: 'Only a teacher or admin can do this.' });
  }
  req.admin = st;
  req.role = r;
  next();
}

// body ko schema ke mutabiq check karke saaf document banata hai
async function buildDoc(cname, body, existing) {
  const sc = SCHEMA[cname];
  const doc = {};
  for (const f of sc.fields) {
    const v = body[f.key];
    const blank = v === undefined || v === null || (typeof v === 'string' && v.trim() === '');
    if (f.type === 'password') {
      if (blank) {
        if (existing) continue; // edit mein khali = purana password rahega
        return { error: `${f.label} is required.` };
      }
      if (typeof v !== 'string' || v.length < 6) return { error: 'Password must be at least 6 characters.' };
      doc[f.key] = await bcrypt.hash(v, 10);
      continue;
    }
    if (blank) {
      if (f.optional) { doc[f.key] = f.type === 'text' ? '' : null; continue; }
      return { error: `${f.label} is required.` };
    }
    if (f.type === 'text') {
      if (typeof v !== 'string') return { error: `${f.label} must be text.` };
      doc[f.key] = v.trim().slice(0, f.multiline ? 5000 : 300);
    } else if (f.type === 'number') {
      const n = Number(v);
      if (!Number.isFinite(n)) return { error: `${f.label} must be a number.` };
      doc[f.key] = n;
    } else if (f.type === 'date') {
      const d = new Date(String(v));
      if (isNaN(d.getTime())) return { error: `${f.label} is not a valid date.` };
      doc[f.key] = d;
    } else if (f.type === 'select') {
      if (!f.options.includes(v)) return { error: `${f.label} is invalid.` };
      doc[f.key] = v;
    } else if (f.type === 'ref') {
      if (typeof v !== 'string') return { error: `${f.label} is invalid.` };
      const ok = await col(f.ref).findOne({ [idKey(f.ref)]: v, deletedDate: null });
      if (!ok) return { error: `${f.label} was not found in the database.` };
      doc[f.key] = v;
    }
  }
  if (cname === 'course' && doc.teacherId) {
    const t = await col('Students').findOne({ studentId: doc.teacherId, deletedDate: null });
    if (!t || roleOf(t) === 'student') return { error: 'Only a user with the teacher or admin role can be assigned as a teacher.' };
  }
  if (cname === 'marks' && doc.obtainedMarks > doc.totalMarks) {
    return { error: 'Obtained marks cannot exceed total marks.' };
  }
  for (const u of sc.unique || []) {
    const q = { [u]: doc[u], deletedDate: null };
    if (existing) q._id = { $ne: existing._id };
    if (await col(cname).findOne(q)) return { error: `${u} already exists.` };
  }
  return { doc };
}

// ---------- TEACHER SCOPE: teacher sirf apne assign kiye hue courses dekh/badal sakta hai ----------
async function ownCourseIds(req) {
  const l = await col('course').find({ teacherId: req.admin.studentId, deletedDate: null }).toArray();
  return l.map(c => c.courseId);
}

async function canTeach(req, courseId) {
  if (req.role === 'admin') return true;
  return !!(await col('course').findOne({ courseId, teacherId: req.admin.studentId, deletedDate: null }));
}

// list/edit/delete ke liye mongo filter (admin ke liye khali)
async function scopeFilter(req, c) {
  if (req.role === 'admin') return {};
  if (['assignments', 'attendance', 'marks', 'timetable'].includes(c)) {
    return { courseId: { $in: await ownCourseIds(req) } };
  }
  if (c === 'submissions') {
    const own = await ownCourseIds(req);
    const as = await col('assignments').find({ courseId: { $in: own }, deletedDate: null }).toArray();
    return { assignmentId: { $in: as.map(a => a.assignmentId) } };
  }
  if (c === 'announcements') return { createdId: req.admin.studentId };
  return {};
}

// form ke dropdowns (refs) ke liye filter
async function refScope(req, c, f) {
  if (c === 'course' && f.key === 'teacherId') return { role: { $in: ['teacher', 'admin'] } };
  if (req.role === 'admin') return {};
  const own = await ownCourseIds(req);
  if (f.ref === 'course') return { courseId: { $in: own } };
  if (f.ref === 'assignments') return scopeFilter(req, 'assignments');
  if (f.ref === 'Students') {
    const en = await col('enrollment').find({ courseId: { $in: own }, status: 'enrolled', deletedDate: null }).toArray();
    return { studentId: { $in: en.map(e => e.studentId) } };
  }
  return {};
}

// save se pehle: kya teacher ye record likh sakta hai? (error text ya null)
async function writeScopeError(req, c, doc) {
  if (req.role === 'admin') return null;
  const own = await ownCourseIds(req);
  if (['assignments', 'attendance', 'marks', 'timetable'].includes(c) && !own.includes(doc.courseId)) {
    return 'This course is not assigned to you.';
  }
  if (c === 'submissions') {
    const a = await col('assignments').findOne({ assignmentId: doc.assignmentId, deletedDate: null });
    if (!a || !own.includes(a.courseId)) return 'This assignment does not belong to your course.';
  }
  if (c === 'attendance' || c === 'marks') {
    const en = await col('enrollment').findOne({ studentId: doc.studentId, courseId: doc.courseId, status: 'enrolled', deletedDate: null });
    if (!en) return 'This student is not enrolled in this course.';
  }
  return null;
}

app.get('/admin/schema', auth, staffOnly, (req, res) => {
  res.json(Object.entries(SCHEMA).filter(([name]) => allowed(req.role, name)).map(([name, s]) => ({
    name, title: s.title, idField: idKey(name), fields: s.fields,
  })));
});

app.get('/admin/:collection', auth, staffOnly, async (req, res) => {
  const c = req.params.collection;
  if (!hasSchema(c) || !allowed(req.role, c)) return res.status(404).json({ error: 'Collection not found.' });
  const rows = await col(c).find({ deletedDate: null, ...(await scopeFilter(req, c)) }).sort({ [idKey(c)]: 1 }).limit(2000).toArray();
  rows.forEach(r => { delete r._id; delete r.password; });
  const refs = {};
  for (const f of SCHEMA[c].fields.filter(x => x.type === 'ref')) {
    const list = await col(f.ref).find({ deletedDate: null, ...(await refScope(req, c, f)) }).toArray();
    refs[f.key] = list.map(d => ({ id: d[idKey(f.ref)], label: labelOf(f.ref, d) }));
  }
  res.json({ rows, refs });
});

app.post('/admin/:collection', auth, staffOnly, async (req, res) => {
  const c = req.params.collection;
  if (!hasSchema(c) || !allowed(req.role, c)) return res.status(404).json({ error: 'Collection not found.' });
  const { doc, error } = await buildDoc(c, req.body || {}, null);
  if (error) return res.status(400).json({ error });
  const se = await writeScopeError(req, c, doc);
  if (se) return res.status(403).json({ error: se });
  const id = await nextId(c, idKey(c), SCHEMA[c].id[1]);
  await col(c).insertOne({
    [idKey(c)]: id, ...doc,
    createdId: req.admin.studentId, createdDate: new Date(),
    updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
  });
  res.json({ ok: true, id });
});

app.put('/admin/:collection/:id', auth, staffOnly, async (req, res) => {
  const c = req.params.collection;
  if (!hasSchema(c) || !allowed(req.role, c)) return res.status(404).json({ error: 'Collection not found.' });
  const existing = await col(c).findOne({ [idKey(c)]: req.params.id, deletedDate: null, ...(await scopeFilter(req, c)) });
  if (!existing) return res.status(404).json({ error: 'Record not found.' });
  const { doc, error } = await buildDoc(c, req.body || {}, existing);
  if (error) return res.status(400).json({ error });
  const se = await writeScopeError(req, c, doc);
  if (se) return res.status(403).json({ error: se });
  await col(c).updateOne({ _id: existing._id }, { $set: { ...doc, updatedBy: req.admin.studentId, updatedDate: new Date() } });
  res.json({ ok: true });
});

app.delete('/admin/:collection/:id', auth, staffOnly, async (req, res) => {
  const c = req.params.collection;
  if (!hasSchema(c) || !allowed(req.role, c)) return res.status(404).json({ error: 'Collection not found.' });
  if (c === 'Students' && req.params.id === req.admin.studentId) {
    return res.status(400).json({ error: 'You cannot delete your own account.' });
  }
  const existing = await col(c).findOne({ [idKey(c)]: req.params.id, deletedDate: null, ...(await scopeFilter(req, c)) });
  if (!existing) return res.status(404).json({ error: 'Record not found.' });
  await col(c).updateOne({ _id: existing._id }, { $set: { deletedBy: req.admin.studentId, deletedDate: new Date() } });
  res.json({ ok: true });
});

// ---------- ADMIN: ID card requests ----------
app.get('/admin-tools/idcards', auth, staffOnly, adminRole, async (req, res) => {
  const cards = await col('stu_Idcard').find({ deletedDate: null }).sort({ createdDate: -1 }).toArray();
  const ids = [...new Set(cards.map(c => c.studentId))];
  const sts = await col('Students').find({ studentId: { $in: ids } }).toArray();
  res.json(cards.map(c => {
    const s = sts.find(x => x.studentId === c.studentId) || {};
    return {
      idCardId: c.idCardId, studentId: c.studentId, name: s.name || '', rollNo: s.rollNo || '',
      cardNo: c.cardNo, status: c.status, issueDate: c.issueDate, expiryDate: c.expiryDate,
    };
  }));
});

app.post('/admin-tools/idcards/:id/decide', auth, staffOnly, adminRole, async (req, res) => {
  const status = clean((req.body || {}).status, 20);
  if (!['active', 'blocked'].includes(status)) return res.status(400).json({ error: 'Invalid status.' });
  const c = await col('stu_Idcard').findOne({ idCardId: req.params.id, deletedDate: null });
  if (!c) return res.status(404).json({ error: 'Card not found.' });
  const set = { status, updatedBy: req.admin.studentId, updatedDate: new Date() };
  if (status === 'active') {
    const now = new Date();
    const exp = new Date(now);
    exp.setFullYear(exp.getFullYear() + 4);
    set.issueDate = now;
    set.expiryDate = exp;
  }
  await col('stu_Idcard').updateOne({ _id: c._id }, { $set: set });
  res.json({ ok: true });
});

// ---------- PORTAL: ek student ka poora data (ids ki jagah naam) ----------
app.get('/portal/me', auth, async (req, res) => {
  try {
    const db = mongoose.connection.db;
    const sid = req.user.studentId;
    const get = (name, q = {}) =>
      db.collection(name).find({ ...q, deletedDate: null }).toArray();

    const st = await db.collection('Students').findOne({ studentId: sid, deletedDate: null });
    if (!st) return res.status(404).json({ error: 'Student not found' });

    const [genders, countries, provinces, cities, areas, departments, semesters,
      sessions, shifts, courses, unis, regs, att, assigns, marks, tt, slips,
      fees, cards, anns, subs, enrolls] = await Promise.all([
      get('gender'), get('country'), get('province'), get('city'), get('area'),
      get('department'), get('semester'), get('session'), get('shift'),
      get('course'), get('uni_info'),
      get('registration', { studentId: sid }),
      get('attendance', { studentId: sid }),
      get('assignments'),
      get('marks', { studentId: sid }),
      get('timetable'),
      get('examslip', { studentId: sid }),
      get('feeChallan', { studentId: sid }),
      get('stu_Idcard', { studentId: sid }),
      get('announcements'),
      get('submissions', { studentId: sid }),
      get('enrollment', { studentId: sid }),
    ]);

    const find = (list, key, id) => list.find(x => x[key] === id);
    const nm = (list, key, id) => (find(list, key, id) || {}).name || '';

    const dept = find(departments, 'departmentId', st.departmentId);
    const city = find(cities, 'cityId', st.cityId);
    const prov = city && find(provinces, 'provinceId', city.provinceId);
    const country = prov && find(countries, 'countryId', prov.countryId);
    const lastReg = regs[regs.length - 1];

    // ab courses wohi hain jin mein student enrolled hai (Add / Drop se)
    const deptCourses = courses.filter(c => c.departmentId === st.departmentId);
    const myIds = enrolls.filter(e => e.status === 'enrolled').map(e => e.courseId);
    const myCourses = courses.filter(c => myIds.includes(c.courseId));
    // course ke teacher ke naam
    const tIds = [...new Set([...deptCourses, ...myCourses].map(c => c.teacherId).filter(Boolean))];
    const tList = tIds.length ? await db.collection('Students').find({ studentId: { $in: tIds } }).toArray() : [];
    const tName = id => (tList.find(t => t.studentId === id) || {}).name || '';
    const cName = id => nm(courses, 'courseId', id);

    // attendance: course ke hisaab se
    const ag = {};
    att.forEach(a => {
      const g = (ag[a.courseId] = ag[a.courseId] || { course: cName(a.courseId), present: 0, total: 0 });
      g.total++;
      if (a.status === 'present') g.present++;
    });

    const uni = find(unis, 'uniId', dept && dept.uniId) || unis[0] || {};
    const card = cards[cards.length - 1];

    // teacher / admin ke liye extra data (dashboard)
    let teaching = [], overview = null;
    const role = roleOf(st);
    if (role !== 'student') {
      const tc = courses.filter(c => c.teacherId === sid);
      const tcIds = tc.map(c => c.courseId);
      const [en, as] = await Promise.all([
        db.collection('enrollment').find({ courseId: { $in: tcIds }, status: 'enrolled', deletedDate: null }).toArray(),
        db.collection('assignments').find({ courseId: { $in: tcIds }, deletedDate: null }).toArray(),
      ]);
      const sb = await db.collection('submissions')
        .find({ assignmentId: { $in: as.map(a => a.assignmentId) }, deletedDate: null }).toArray();
      teaching = tc.map(c => {
        const aIds = as.filter(a => a.courseId === c.courseId).map(a => a.assignmentId);
        return {
          courseId: c.courseId, code: c.code, name: c.name, creditHours: c.creditHours,
          semester: nm(semesters, 'semesterId', c.semesterId),
          students: en.filter(e => e.courseId === c.courseId).length,
          assignments: aIds.length,
          ungraded: sb.filter(x => aIds.includes(x.assignmentId) && x.grade == null).length,
        };
      });
    }
    if (role === 'admin') {
      const n = (c, q = {}) => db.collection(c).countDocuments({ ...q, deletedDate: null });
      const [users, teachers, courseN, enrollN, pendingCards, unpaidFees, assignN] = await Promise.all([
        n('Students'), n('Students', { role: 'teacher' }), n('course'), n('enrollment', { status: 'enrolled' }),
        n('stu_Idcard', { status: 'pending' }), n('feeChallan', { status: 'unpaid' }), n('assignments'),
      ]);
      overview = { users, teachers, courses: courseN, enrollments: enrollN, pendingCards, unpaidFees, assignments: assignN };
    }

    res.json({
      student: {
        studentId: st.studentId,
        name: st.name,
        isAdmin: roleOf(st) === 'admin',
        role: roleOf(st),
        fName: st.fName,
        rollNo: st.rollNo,
        registrationNo: st.registrationNo,
        email: st.email,
        phone: st.phone,
        address: st.address,
        dob: st.DateOfBirth,
        gender: nm(genders, 'genderId', st.genderId),
        department: dept ? dept.name : '',
        area: nm(areas, 'areaId', st.areaId),
        city: city ? city.name : '',
        province: prov ? prov.name : '',
        country: country ? country.name : '',
        session: lastReg ? nm(sessions, 'sessionId', lastReg.sessionId) : '',
        semester: lastReg ? nm(semesters, 'semesterId', lastReg.semesterId) : '',
      },
      courses: myCourses.map(c => ({
        teacher: tName(c.teacherId),
        courseId: c.courseId, code: c.code, name: c.name, creditHours: c.creditHours,
        semesterId: c.semesterId,
        semester: nm(semesters, 'semesterId', c.semesterId),
        department: dept ? dept.name : '',
      })),
      registration: regs.map(r => ({
        session: nm(sessions, 'sessionId', r.sessionId),
        semesterId: r.semesterId,
        semester: nm(semesters, 'semesterId', r.semesterId),
        date: r.registrationDate,
        status: r.status,
      })),
      catalog: deptCourses.map(c => ({
        teacher: tName(c.teacherId),
        courseId: c.courseId, code: c.code, name: c.name, creditHours: c.creditHours,
        semester: nm(semesters, 'semesterId', c.semesterId),
        enrolled: myIds.includes(c.courseId),
      })),
      maxCredits: MAX_CREDITS,
      teaching,
      overview,
      options: {
        sessions: sessions.map(x => ({ id: x.sessionId, name: x.name })),
        semesters: semesters.map(x => ({ id: x.semesterId, name: x.name })),
      },
      attendance: Object.values(ag),
      assignments: assigns.filter(a => myIds.includes(a.courseId)).map(a => {
        const sub = subs.find(x => x.assignmentId === a.assignmentId);
        return {
          assignmentId: a.assignmentId, title: a.title, course: cName(a.courseId), dueDate: a.dueDate,
          description: a.description || '', totalMarks: a.totalMarks == null ? null : a.totalMarks,
          submission: sub ? { text: sub.text, date: sub.submittedDate, grade: sub.grade == null ? null : sub.grade, feedback: sub.feedback || '' } : null,
        };
      }),
      marks: marks.map(m => ({
        course: cName(m.courseId), examType: m.examType,
        total: m.totalMarks, obtained: m.obtainedMarks,
      })),
      timetable: tt.filter(t => myIds.includes(t.courseId)).map(t => ({
        day: t.day, start: t.startTime, end: t.endTime, room: t.room,
        course: cName(t.courseId), shift: nm(shifts, 'shiftId', t.shiftId),
      })),
      examslips: slips.map(s => ({
        examType: s.examType, issueDate: s.issueDate,
        semester: nm(semesters, 'semesterId', s.semesterId),
      })),
      fees: fees.map(f => ({
        challanId: f.challanId, semester: nm(semesters, 'semesterId', f.semesterId),
        amount: f.amount, dueDate: f.dueDate, status: f.status, paidDate: f.paidDate,
      })),
      idCard: card ? {
        cardNo: card.cardNo, issueDate: card.issueDate,
        expiryDate: card.expiryDate, status: card.status,
      } : null,
      announcements: anns
        .filter(a => (!a.departmentId || a.departmentId === st.departmentId) && a.status === 'active')
        .sort((a, b) => new Date(b.announcementDate) - new Date(a.announcementDate))
        .map(a => ({
          title: a.title, message: a.message,
          date: a.announcementDate, expiry: a.expiryDate,
        })),
      uni: { name: uni.name, address: uni.address, phone: uni.phone, email: uni.email },
      lookups: {
        gender: genders.map(x => x.name),
        country: countries.map(x => x.name),
        province: provinces.map(x => x.name),
        city: cities.map(x => x.name),
        area: areas.map(x => x.name),
        department: departments.map(x => x.name),
        semester: semesters.map(x => x.name),
        session: sessions.map(x => x.name),
        shift: shifts.map(x => x.name),
      },
    });
  } catch (e) {
    console.log(e);
    res.status(500).json({ error: String(e) });
  }
});

app.listen(3000, () => console.log('API on http://localhost:3000'));