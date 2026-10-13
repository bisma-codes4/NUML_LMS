const mongoose = require('mongoose');

(async () => {
  await mongoose.connect('mongodb://localhost:27017/NUML_LMS');
  const db = mongoose.connection.db;
  const all = await db.collection('enrollment').find({}, { projection: { enrollmentId: 1 } }).toArray();
  let max = 0;
  for (const d of all) {
    const n = parseInt(String(d.enrollmentId || '').replace(/\D/g, ''), 10);
    if (n > max) max = n;
  }
  const students = await db.collection('Students').find({ deletedDate: null }).toArray();
  let added = 0;
  for (const s of students) {
    const courses = await db.collection('course').find({ departmentId: s.departmentId, deletedDate: null }).toArray();
    for (const c of courses) {
      const ex = await db.collection('enrollment').findOne({ studentId: s.studentId, courseId: c.courseId, deletedDate: null });
      if (ex) continue;
      max++;
      added++;
      await db.collection('enrollment').insertOne({
        enrollmentId: 'EN' + String(max).padStart(3, '0'),
        studentId: s.studentId, courseId: c.courseId, status: 'enrolled', enrollDate: new Date(),
        createdId: 'system', createdDate: new Date(),
        updatedBy: null, updatedDate: null, deletedBy: null, deletedDate: null,
      });
    }
  }
  console.log('Enrollments added:', added);
  process.exit(0);
})();