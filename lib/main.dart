import 'package:flutter/material.dart';
import 'api_service.dart';

/* ===================== THEME COLORS ===================== */
const kNavy = Color(0xFF0A2540);
const kBlue = Color(0xFF0B5C8A);
const kGold = Color(0xFFF5B841);
const kBg = Color(0xFFF1F5F9);
const kLine = Color(0xFFE2E6ED);
const kInk = Color(0xFF1F2937);
const kMuted = Color(0xFF6B7280);
const kGreen = Color(0xFF2A7F62);
const kRed = Color(0xFFB83232);
const kAmber = Color(0xFFB7791F);
const kDeep = Color(0xFF0A2540);
const kTeal = Color(0xFF0F766E);
const kSun = Color(0xFFF5B841);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NUML_LMS',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: kNavy, primary: kNavy),
          scaffoldBackgroundColor: kBg,
        ),
        home: const LoginPage(),
      );
}

/* ===================== DATA (MongoDB se aata hai) ===================== */
// Login ke baad /portal/:studentId ka poora data yahan aa jata hai
Map<String, dynamic> _p = {};

List<Map<String, dynamic>> _l(String k) =>
    ((_p[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

Map<String, dynamic> _m(String k) =>
    _p[k] is Map ? Map<String, dynamic>.from(_p[k] as Map) : <String, dynamic>{};

String _s(dynamic v, [String d = '-']) => (v == null || v.toString().trim().isEmpty) ? d : v.toString();

String _st(String k) => _s(_m('student')[k]);

int _n(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

String _initial() {
  final n = _st('name');
  return n == '-' ? '?' : n[0];
}

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _d(dynamic iso) {
  final t = DateTime.tryParse('${iso ?? ''}');
  if (t == null) return '-';
  final u = t.toUtc();
  return '${u.day.toString().padLeft(2, '0')} ${_mon[u.month - 1]} ${u.year}';
}

String _money(num n) =>
    n.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

const _courseColors = [kBlue, kGreen, kAmber, Color(0xFF6B46C1), kRed, Color(0xFF0E7490)];
const _courseIcons = [Icons.phone_android, Icons.account_tree, Icons.storage, Icons.language, Icons.engineering, Icons.gavel];

const _lookupIcons = {
  'gender': Icons.wc_outlined,
  'country': Icons.flag_outlined,
  'province': Icons.map_outlined,
  'city': Icons.location_city_outlined,
  'area': Icons.place_outlined,
  'department': Icons.apartment_outlined,
  'semester': Icons.layers_outlined,
  'session': Icons.date_range_outlined,
  'shift': Icons.wb_sunny_outlined,
};

const _menu = [
  ['Dashboard', Icons.dashboard_outlined],
  ['My Profile', Icons.person_outline],
  ['Student ID Card', Icons.badge_outlined],
  ['Registration', Icons.how_to_reg_outlined],
  ['My Courses', Icons.menu_book_outlined],
  ['Add / Drop Courses', Icons.library_add_outlined],
  ['Attendance', Icons.fact_check_outlined],
  ['Assignments', Icons.assignment_outlined],
  ['Marks', Icons.grade_outlined],
  ['Timetable', Icons.calendar_month_outlined],
  ['Exam Slip', Icons.event_note_outlined],
  ['Fee Challan', Icons.receipt_long_outlined],
  ['Announcements', Icons.campaign_outlined],
  ['University Info', Icons.account_balance_outlined],
  ['Master Data', Icons.dataset_outlined],
  ['Settings', Icons.settings_outlined],
];

String _role() => _s(_m('student')['role'], 'student');

bool _isStaff() {
  final r = _m('student')['role'];
  return r == 'admin' || r == 'teacher';
}

// Har role ka apna menu: student, teacher aur admin ko alag cheezein dikhti hain
List<List<Object>> _menuItems() {
  List<List<Object>> pick(List<String> names) => [for (final n in names) _menu.firstWhere((m) => m[0] == n)];
  final r = _role();
  if (r == 'admin') {
    return [
      ...pick(['Dashboard', 'My Profile']),
      ['ID Card Requests', Icons.badge_outlined],
      ['Manage Data', Icons.admin_panel_settings_outlined],
      ...pick(['Master Data', 'University Info', 'Settings']),
    ];
  }
  if (r == 'teacher') {
    return [
      ...pick(['Dashboard', 'My Profile']),
      ['Class Tools', Icons.cast_for_education_outlined],
      ['Manage Data', Icons.admin_panel_settings_outlined],
      ...pick(['University Info', 'Settings']),
    ];
  }
  return [..._menu];
}

/* ================================= LOGIN ================================= */
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _key = GlobalKey<FormState>();
  final _e = TextEditingController(), _p2 = TextEditingController();
  bool _hide = true, _remember = true;
  bool _loading = false;

  @override
  void dispose() {
    _e.dispose();
    _p2.dispose();
    super.dispose();
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ));

  Future<void> _login() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = await loginApi(_e.text.trim(), _p2.text);
      if (!mounted) return;
      if (data == null) {
        _err('Invalid email or password.');
        return;
      }
      final portal = await portalApi();
      if (!mounted) return;
      if (portal == null) {
        _err('Could not load your data.');
        return;
      }
      _p = portal;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Shell()));
    } catch (e) {
      if (!mounted) return;
      _err('Cannot connect to the server. Make sure it is running (node server.js).');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- CREATE ACCOUNT (signup) ----
  Future<void> _signup() async {
    final o = await publicOptionsApi();
    if (!mounted) return;
    if (o == null) {
      _err('Cannot connect to the server. Make sure it is running (node server.js).');
      return;
    }
    Map<String, dynamic> f(String k, String l, String t, {bool opt = false}) =>
        {'key': k, 'label': l, 'type': t, 'optional': opt};
    final vals = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RecordDialog(
        title: 'Create Account',
        fields: [
          f('name', 'Full Name', 'text'),
          f('fName', 'Father Name', 'text'),
          f('email', 'Email', 'text'),
          f('password', 'Password (min 6)', 'password'),
          f('rollNo', 'Roll No', 'text'),
          f('registrationNo', 'Registration No', 'text'),
          f('DateOfBirth', 'Date of Birth', 'date'),
          f('genderId', 'Gender', 'ref'),
          f('departmentId', 'Department', 'ref'),
          f('cityId', 'City', 'ref'),
          f('areaId', 'Area', 'ref'),
          f('phone', 'Phone', 'text', opt: true),
          f('address', 'Address', 'text', opt: true),
        ],
        refs: {
          'genderId': o['genders'],
          'departmentId': o['departments'],
          'cityId': o['cities'],
          'areaId': o['areas'],
        },
      ),
    );
    if (vals == null) return;
    final err = await signupApi(vals);
    if (!mounted) return;
    if (err != null) {
      _err(err);
      return;
    }
    _e.text = '${vals['email']}'.trim().toLowerCase();
    _p2.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Account created. Please sign in.'),
      backgroundColor: kTeal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  InputDecoration _dec(String l, IconData i, [Widget? s]) => InputDecoration(
        labelText: l,
        prefixIcon: Icon(i, size: 20, color: kTeal),
        suffixIcon: s,
        filled: true,
        fillColor: const Color(0xFFEEF6F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kTeal, width: 1.5)),
      );

  Widget _form() => Form(
        key: _key,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Student Login', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kDeep)),
          const SizedBox(height: 6),
          const Text('Sign in to access your learning portal', style: TextStyle(color: kMuted)),
          const SizedBox(height: 26),
          TextFormField(
            controller: _e,
            keyboardType: TextInputType.emailAddress,
            decoration: _dec('Email Address', Icons.email_outlined),
            validator: (v) => v == null || v.trim().isEmpty ? 'Email is required' : (!v.contains('@') ? 'Enter a valid email' : null),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _p2,
            obscureText: _hide,
            decoration: _dec('Password', Icons.lock_outline,
                IconButton(icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), onPressed: () => setState(() => _hide = !_hide))),
            validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
            onFieldSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(value: _remember, activeColor: kTeal, onChanged: (v) => setState(() => _remember = v!)),
            const Text('Remember me', style: TextStyle(fontSize: 13)),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('Forgot password?', style: TextStyle(color: kTeal, fontSize: 13))),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : _login,
              style: FilledButton.styleFrom(backgroundColor: kTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loading ? null : _signup,
            child: const Text('New here? Create an account', style: TextStyle(color: kTeal)),
          ),
        ]),
      );

  Widget _brand() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kTeal, kDeep]),
        ),
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kSun.withValues(alpha: .2), borderRadius: BorderRadius.circular(14), border: Border.all(color: kSun.withValues(alpha: .6))),
            child: const Icon(Icons.account_balance, color: kSun, size: 36),
          ),
          const SizedBox(height: 26),
          const Text('NUML_LMS', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, height: 1.25)),
          const SizedBox(height: 14),
          Container(width: 56, height: 3, color: kSun),
          const SizedBox(height: 16),
          Text('Courses, assignments, quizzes, grades and announcements — all in one place.',
              style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 15, height: 1.5)),
          const SizedBox(height: 28),
          for (final f in ['Track your course progress', 'Submit assignments online', 'View grades & timetable'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const Icon(Icons.check_circle, color: kSun, size: 18),
                const SizedBox(width: 10),
                Text(f, style: const TextStyle(color: Colors.white)),
              ]),
            ),
        ]),
      );

  Widget _circle(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 850;

    final card = wide
        ? ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                color: Colors.white,
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(flex: 5, child: _brand()),
                    Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(40), child: Center(child: _form()))),
                  ]),
                ),
              ),
            ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 32, backgroundColor: kTeal, child: const Icon(Icons.account_balance, color: kSun, size: 32)),
                const SizedBox(height: 12),
                const Text('NUML_LMS', style: TextStyle(color: kDeep, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 22),
                _form(),
              ]),
            ),
          );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kDeep, Color(0xFF0B4F6C), kTeal]),
        ),
        child: Stack(children: [
          Positioned(top: -90, left: -90, child: _circle(280, Colors.white.withValues(alpha: .06))),
          Positioned(bottom: -120, right: -70, child: _circle(340, kSun.withValues(alpha: .10))),
          Positioned(top: 140, right: 60, child: _circle(90, Colors.white.withValues(alpha: .05))),
          Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: card)),
        ]),
      ),
    );
  }
}

/* ================================= SHELL ================================= */
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _sel = 0;

  Future<void> _reload() async {
    final d = await portalApi();
    if (!mounted) return;
    if (d != null) setState(() => _p = d);
  }

  void _logout() {
    logoutApi();
    _p = {};
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  Widget _page() {
    switch (_menuItems()[_sel][0] as String) {
      case 'Dashboard':
        if (_role() == 'admin') return const _AdminDashboard();
        if (_role() == 'teacher') return const _TeacherDashboard();
        return const _Dashboard();
      case 'ID Card Requests':
        return _IdRequestsPage(onReload: _reload);
      case 'My Profile':
        return _ProfilePage(onReload: _reload);
      case 'Student ID Card':
        return _IdCardPage(onReload: _reload);
      case 'Registration':
        return _RegistrationPage(onReload: _reload);
      case 'My Courses':
        return const _CoursesPage();
      case 'Add / Drop Courses':
        return _EnrollPage(onReload: _reload);
      case 'Attendance':
        return const _AttendancePage();
      case 'Assignments':
        return _AssignmentsPage(onReload: _reload);
      case 'Marks':
        return const _MarksPage();
      case 'Timetable':
        return const _TimetablePage();
      case 'Exam Slip':
        return const _ExamSlipPage();
      case 'Fee Challan':
        return const _FeePage();
      case 'Announcements':
        return const _AnnouncementsPage();
      case 'University Info':
        return const _UniPage();
      case 'Master Data':
        return const _MasterDataPage();
      case 'Class Tools':
        return const _ClassToolsPage();
      case 'Manage Data':
        return _ManagePage(onReload: _reload);
      default:
        return _SettingsPage(onLogout: _logout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final body = Column(children: [
      _TopBar(title: _menuItems()[_sel][0] as String, menu: !wide, onRefresh: _reload),
      Expanded(child: _page()),
    ]);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 255, child: _Side(sel: _sel, onSelect: (i) => setState(() => _sel = i), onLogout: _logout)),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      drawer: Drawer(
        backgroundColor: kNavy,
        child: _Side(sel: _sel, onSelect: (i) {
          Navigator.pop(context);
          setState(() => _sel = i);
        }, onLogout: _logout),
      ),
      body: SafeArea(child: body),
    );
  }
}

class _Side extends StatelessWidget {
  final int sel;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  const _Side({required this.sel, required this.onSelect, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kNavy,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kGold.withValues(alpha: .18), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance, color: kGold, size: 24),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('NUML_LMS', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                Text('${_role()[0].toUpperCase()}${_role().substring(1)} Portal', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems().length,
              itemBuilder: (_, i) {
                final on = i == sel;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: on ? Colors.white.withValues(alpha: .1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: on ? kGold : Colors.transparent, width: 3)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(_menuItems()[i][1] as IconData, color: on ? kGold : Colors.white70),
                    title: Text(_menuItems()[i][0] as String, style: TextStyle(color: on ? Colors.white : Colors.white70, fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
                    onTap: () => onSelect(i),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ListTile(leading: const Icon(Icons.logout, color: Colors.white70), title: const Text('Logout', style: TextStyle(color: Colors.white70)), onTap: onLogout),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final bool menu;
  final Future<void> Function() onRefresh;
  const _TopBar({required this.title, required this.menu, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: kLine))),
      child: Row(children: [
        if (menu) Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu, color: kNavy), onPressed: () => Scaffold.of(c).openDrawer())),
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: kNavy)),
        const Spacer(),
        if (w >= 700)
          Container(
            width: 280,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [Icon(Icons.search, color: kMuted, size: 20), SizedBox(width: 8), Text('Search...', style: TextStyle(color: kMuted))]),
          ),
        IconButton(icon: const Icon(Icons.refresh, color: kNavy), tooltip: 'Refresh data', onPressed: onRefresh),
        const SizedBox(width: 4),
        Stack(children: [
          IconButton(icon: const Icon(Icons.notifications_none, color: kNavy), onPressed: () {}),
          Positioned(right: 10, top: 10, child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle))),
        ]),
        CircleAvatar(radius: 18, backgroundColor: kNavy, child: Text(_initial(), style: const TextStyle(color: kGold, fontWeight: FontWeight.bold))),
        if (w >= 600) ...[
          const SizedBox(width: 10),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_st('name'), style: const TextStyle(fontWeight: FontWeight.bold, color: kInk)),
            Text(_isStaff() ? _role().toUpperCase() : '${_st('department')} • ${_st('semester')}', style: const TextStyle(color: kMuted, fontSize: 11)),
          ]),
        ],
      ]),
    );
  }
}

/* ============================= SHARED WIDGETS ============================= */
class _Box extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsets pad;
  const _Box({this.title, required this.child, this.pad = const EdgeInsets.all(18)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: pad,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kNavy)),
            const SizedBox(height: 14),
          ],
          child,
        ]),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  final Widget? trail;
  const _Row(this.icon, this.color, this.title, this.sub, [this.trail]);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(color: kMuted, fontSize: 12)),
            ]),
          ),
          if (trail != null) trail!,
        ]),
      );
}

class _Empty extends StatelessWidget {
  final String msg;
  const _Empty(this.msg);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(msg, style: const TextStyle(color: kMuted)));
}

class _Scaffold extends StatelessWidget {
  final String title, sub;
  final List<Widget> children;
  const _Scaffold(this.title, this.sub, this.children);
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kNavy)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: kMuted)),
          const SizedBox(height: 20),
          ...children,
        ]),
      );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value, note;
  final Color color;
  const _Stat(this.icon, this.label, this.value, this.color, [this.note = '']);
  @override
  Widget build(BuildContext context) => Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLine),
          boxShadow: [BoxShadow(color: kNavy.withValues(alpha: .05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    CircleAvatar(radius: 24, backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kInk)),
                        Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
                        if (note.isNotEmpty) Text(note, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: const TextStyle(color: kMuted, fontSize: 12)),
      const SizedBox(height: 2),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w600, color: kInk)),
    ]);

Widget _kvGrid(List<List<String>> items) => Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [for (final i in items) SizedBox(width: 220, child: _kv(i[0], i[1]))],
    );

Widget _hdr(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.bold));

Color _pctColor(double p) => p >= .75 ? (p >= .9 ? kGreen : kBlue) : (p >= .5 ? kAmber : kRed);

Color _statusColor(String s) {
  final x = s.toLowerCase();
  if (x == 'paid' || x == 'active' || x == 'registered' || x == 'present') return kGreen;
  if (x == 'unpaid' || x == 'absent' || x == 'expired') return kRed;
  return kAmber;
}

class _CourseCard extends StatelessWidget {
  final int idx;
  final Map<String, dynamic> c;
  const _CourseCard(this.idx, this.c);
  @override
  Widget build(BuildContext context) {
    final col = _courseColors[idx % _courseColors.length];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: col.withValues(alpha: .12), child: Icon(_courseIcons[idx % _courseIcons.length], color: col, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(_s(c['name']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: kInk))),
        ]),
        const SizedBox(height: 10),
        Text('${_s(c['code'])} • ${_s(c['creditHours'])} Cr. Hrs', style: const TextStyle(color: kMuted, fontSize: 12)),
        Text(_s(c['semester']), style: const TextStyle(color: kMuted, fontSize: 12)),
        Text(_s(c['department']), style: const TextStyle(color: kMuted, fontSize: 12)),
        if (_s(c['teacher'], '').isNotEmpty) Text('Teacher: ${_s(c['teacher'])}', style: const TextStyle(color: kMuted, fontSize: 12)),
      ]),
    );
  }
}

Widget _courseGrid() {
  final cs = _l('courses');
  if (cs.isEmpty) return const _Empty('No courses found.');
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: cs.length,
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 340, mainAxisExtent: 150, crossAxisSpacing: 14, mainAxisSpacing: 14),
    itemBuilder: (_, i) => _CourseCard(i, cs[i]),
  );
}

int _credits() => _l('courses').fold<int>(0, (s, c) => s + _n(c['creditHours']));

double _attPct() {
  final a = _l('attendance');
  final p = a.fold<int>(0, (s, x) => s + _n(x['present']));
  final t = a.fold<int>(0, (s, x) => s + _n(x['total']));
  return t == 0 ? 0 : p / t;
}

bool _attHas() => _l('attendance').isNotEmpty;

String _marksPct() {
  final m = _l('marks');
  final o = m.fold<num>(0, (s, x) => s + (x['obtained'] is num ? x['obtained'] as num : 0));
  final t = m.fold<num>(0, (s, x) => s + (x['total'] is num ? x['total'] as num : 0));
  return t == 0 ? '-' : '${(o / t * 100).round()}%';
}

List<Map<String, dynamic>> _pendingAssignments() {
  final today = DateTime.now().toUtc().subtract(const Duration(days: 1));
  return _l('assignments').where((a) => (DateTime.tryParse('${a['dueDate']}') ?? DateTime(2000)).isAfter(today)).toList();
}


void _toast(BuildContext c, String m, [bool err = false]) => ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: err ? kRed : kTeal));

Future<bool> _confirm(BuildContext c, String title, String msg) async =>
    (await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kRed), onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    )) ==
    true;

// fields: [key, label, (initial value)]
Future<Map<String, String>?> _form(BuildContext context, String title, List<List<String>> fields,
    {String ok = 'Save', Set<String> secret = const {}, Set<String> multi = const {}}) {
  final ctrls = {for (final f in fields) f[0]: TextEditingController(text: f.length > 2 ? f[2] : '')};
  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final f in fields)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: ctrls[f[0]],
                  obscureText: secret.contains(f[0]),
                  minLines: multi.contains(f[0]) ? 3 : 1,
                  maxLines: multi.contains(f[0]) ? 6 : 1,
                  decoration: InputDecoration(labelText: f[1], border: const OutlineInputBorder()),
                ),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kTeal),
          onPressed: () => Navigator.pop(ctx, {for (final e in ctrls.entries) e.key: e.value.text}),
          child: Text(ok),
        ),
      ],
    ),
  );
}

/* ================================== PAGES ================================== */
class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData i, String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, color: kGold, size: 15),
            const SizedBox(width: 6),
            Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        );

    final courses = _l('courses');
    final pending = _pendingAssignments();
    final att = _l('attendance');
    final present = att.fold<int>(0, (s, a) => s + _n(a['present']));
    final total = att.fold<int>(0, (s, a) => s + _n(a['total']));
    final pct = _attPct();
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final todayName = dayNames[DateTime.now().weekday - 1];
    final todayClasses = _l('timetable').where((t) => t['day'] == todayName).toList();

    return LayoutBuilder(builder: (context, cons) {
      final wide = cons.maxWidth >= 1000;

      final attendance = _Box(
        title: 'Attendance Overview',
        child: !_attHas()
            ? const _Empty('No attendance records yet.')
            : Row(children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(fit: StackFit.expand, children: [
                    CircularProgressIndicator(value: pct, strokeWidth: 9, color: kTeal, backgroundColor: kTeal.withValues(alpha: .12)),
                    Center(child: Text('${(pct * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kNavy))),
                  ]),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Present: $present classes', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Absent: ${total - present} classes', style: const TextStyle(color: kMuted)),
                    const SizedBox(height: 4),
                    const Text('Required: 75%', style: TextStyle(color: kMuted)),
                  ]),
                ),
              ]),
      );

      final today = _Box(
        title: "Today's Classes ($todayName)",
        child: todayClasses.isEmpty
            ? const _Empty('No classes today.')
            : Column(children: [
                for (final s in todayClasses) _Row(Icons.schedule, kTeal, _s(s['course']), '${_s(s['start'])} - ${_s(s['end'])} • ${_s(s['room'])}'),
              ]),
      );
      final dead = _Box(
        title: 'Upcoming Deadlines',
        child: pending.isEmpty
            ? const _Empty('No pending assignments.')
            : Column(children: [
                for (final a in pending.take(4)) _Row(Icons.assignment_outlined, kAmber, _s(a['title']), '${_s(a['course'])}\nDue: ${_d(a['dueDate'])}'),
              ]),
      );
      final anns = _l('announcements');
      final ann = _Box(
        title: 'Announcements',
        child: anns.isEmpty
            ? const _Empty('No announcements.')
            : Column(children: [
                for (final a in anns.take(3)) _Row(Icons.campaign_outlined, kNavy, _s(a['title']), '${_s(a['message'])}\n${_d(a['date'])}'),
              ]),
      );
      final side = Column(children: [attendance, const SizedBox(height: 16), today]);
      final main = Column(children: [
        _Box(title: 'My Courses', child: _courseGrid()),
        const SizedBox(height: 16),
        dead,
        const SizedBox(height: 16),
        ann,
      ]);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kNavy, Color(0xFF0B4F6C), kTeal]),
              boxShadow: [BoxShadow(color: kNavy.withValues(alpha: .25), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Welcome back, ${_st('name')}!', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Here is an overview of your academic progress.', style: TextStyle(color: Colors.white.withValues(alpha: .8))),
                  const SizedBox(height: 16),
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    chip(Icons.calendar_today, _st('session')),
                    chip(Icons.school_outlined, _st('department')),
                    chip(Icons.layers_outlined, _st('semester')),
                  ]),
                ]),
              ),
              if (cons.maxWidth > 650)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: kGold.withValues(alpha: .15), border: Border.all(color: kGold.withValues(alpha: .5))),
                  child: const Icon(Icons.account_balance, color: kGold, size: 46),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 16, runSpacing: 16, children: [
            _Stat(Icons.menu_book, 'Enrolled Courses', '${courses.length}', kBlue, '${_credits()} credit hours'),
            _Stat(Icons.assignment_late_outlined, 'Pending Assignments', '${pending.length}', kAmber),
            _Stat(Icons.emoji_events_outlined, 'Marks Obtained', _marksPct(), kGreen),
            _Stat(Icons.event_available_outlined, 'Attendance', _attHas() ? '${(pct * 100).round()}%' : '-', kTeal),
          ]),
          const SizedBox(height: 20),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: main),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: side),
            ])
          else ...[main, const SizedBox(height: 16), side],
          const SizedBox(height: 24),
          const Center(child: Text('© 2026 NUML_LMS. All rights reserved.', style: TextStyle(color: kMuted, fontSize: 12))),
        ]),
      );
    });
  }
}

// ---- Students
class _ProfilePage extends StatelessWidget {
  final Future<void> Function() onReload;
  const _ProfilePage({required this.onReload});

  Future<void> _edit(BuildContext context) async {
    final st = _m('student');
    final v = await _form(context, 'Edit Profile', [
      ['phone', 'Phone', _s(st['phone'], '')],
      ['address', 'Address', _s(st['address'], '')],
    ], multi: {'address'});
    if (v == null || !context.mounted) return;
    final err = await updateProfileApi(v['phone']!, v['address']!);
    if (!context.mounted) return;
    if (err != null) {
      _toast(context, err, true);
      return;
    }
    await onReload();
    if (context.mounted) _toast(context, 'Profile updated.');
  }

  @override
  Widget build(BuildContext context) {
    return _Scaffold('My Profile', 'Your personal and academic information', [
      _Box(
        child: Row(children: [
          CircleAvatar(radius: 38, backgroundColor: kNavy, child: Text(_initial(), style: const TextStyle(color: kGold, fontSize: 30, fontWeight: FontWeight.bold))),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_st('name'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Roll No: ${_st('rollNo')}', style: const TextStyle(color: kMuted)),
              Text(_st('email'), style: const TextStyle(color: kMuted)),
            ]),
          ),
          OutlinedButton.icon(onPressed: () => _edit(context), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
        ]),
      ),
      const SizedBox(height: 16),
      _Box(title: 'Academic Information', child: _kvGrid([
        ['Registration No', _st('registrationNo')],
        ['Department', _st('department')],
        ['Semester', _st('semester')],
        ['Session', _st('session')],
        ['Role', _st('role')],
      ])),
      const SizedBox(height: 16),
      _Box(title: 'Personal Information', child: _kvGrid([
        ['Father Name', _st('fName')],
        ['Gender', _st('gender')],
        ['Date of Birth', _d(_m('student')['dob'])],
        ['Phone', _st('phone')],
        ['Address', _st('address')],
        ['Area', _st('area')],
        ['City', _st('city')],
        ['Province', _st('province')],
        ['Country', _st('country')],
      ])),
    ]);
  }
}

// ---- stu_Idcard
class _IdCardPage extends StatelessWidget {
  final Future<void> Function() onReload;
  const _IdCardPage({required this.onReload});

  Future<void> _request(BuildContext context) async {
    final err = await requestIdCardApi();
    if (!context.mounted) return;
    if (err != null) {
      _toast(context, err, true);
      return;
    }
    await onReload();
    if (context.mounted) _toast(context, 'ID card request submitted.');
  }

  @override
  Widget build(BuildContext context) {
    final c = _m('idCard');
    if (c.isEmpty) {
      return _Scaffold('Student ID Card', 'Your university identity card', [
        _Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your ID card has not been issued yet.', style: TextStyle(color: kMuted)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _request(context),
              style: FilledButton.styleFrom(backgroundColor: kTeal),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Request ID Card'),
            ),
          ]),
        ),
      ]);
    }
    final status = _s(c['status'], '').toLowerCase();
    return _Scaffold('Student ID Card', 'Your university identity card', [
      if (status == 'pending')
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: _Box(
            child: Row(children: [
              Icon(Icons.hourglass_top, color: kAmber),
              SizedBox(width: 10),
              Expanded(child: Text('Your request is pending. The card becomes active once the admin approves it.')),
            ]),
          ),
        ),
      if (status == 'expired')
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _Box(
            child: Row(children: [
              const Icon(Icons.warning_amber_outlined, color: kRed),
              const SizedBox(width: 10),
              const Expanded(child: Text('Your card has expired.')),
              FilledButton(
                onPressed: () => _request(context),
                style: FilledButton.styleFrom(backgroundColor: kTeal),
                child: const Text('Request New Card'),
              ),
            ]),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kNavy, Color(0xFF0B4F6C), kTeal]),
              boxShadow: [BoxShadow(color: kNavy.withValues(alpha: .25), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.account_balance, color: kGold, size: 30),
                SizedBox(width: 10),
                Text('NUML', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Spacer(),
                Text('STUDENT CARD', style: TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                CircleAvatar(radius: 38, backgroundColor: Colors.white24, child: Text(_initial(), style: const TextStyle(color: kGold, fontSize: 30, fontWeight: FontWeight.bold))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_st('name'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Roll No: ${_st('rollNo')}', style: const TextStyle(color: Colors.white70)),
                    Text(_st('department'), style: const TextStyle(color: Colors.white70)),
                    Text(_st('semester'), style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Card No: ${_s(c['cardNo'])}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('Status: ${_s(c['status'])}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Issued: ${_d(c['issueDate'])}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('Valid Till: ${_d(c['expiryDate'])}', style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ---- registration
class _RegistrationPage extends StatefulWidget {
  final Future<void> Function() onReload;
  const _RegistrationPage({required this.onReload});
  @override
  State<_RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<_RegistrationPage> {
  String? _sess, _sem;
  bool _busy = false;

  List<Map<String, dynamic>> _opts(String k) =>
      ((_m('options')[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _register() async {
    if (_sess == null || _sem == null) {
      _toast(context, 'Please select both session and semester.', true);
      return;
    }
    setState(() => _busy = true);
    final err = await registerApi(_sess!, _sem!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      _toast(context, err, true);
      return;
    }
    await widget.onReload();
    if (!mounted) return;
    setState(() {
      _sess = null;
      _sem = null;
    });
    _toast(context, 'Registration successful.');
  }

  @override
  Widget build(BuildContext context) {
    final regs = _l('registration');
    final semIds = regs.map((r) => r['semesterId']).toSet();
    final regCourses = _l('courses').where((c) => semIds.contains(c['semesterId'])).toList();
    final cr = regCourses.fold<int>(0, (s, c) => s + _n(c['creditHours']));
    final sessions = _opts('sessions'), semesters = _opts('semesters');
    return _Scaffold('Registration', '${_st('session')} • ${_st('semester')} registration', [
      Wrap(spacing: 16, runSpacing: 16, children: [
        _Stat(Icons.how_to_reg_outlined, 'Registrations', '${regs.length}', kBlue),
        _Stat(Icons.menu_book_outlined, 'Registered Courses', '${regCourses.length}', kGreen),
        _Stat(Icons.library_books_outlined, 'Credit Hours', '$cr', kTeal),
      ]),
      const SizedBox(height: 20),
      _Box(
        title: 'New Registration',
        child: Wrap(spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _sess,
              decoration: const InputDecoration(labelText: 'Session', border: OutlineInputBorder()),
              items: [for (final s in sessions) DropdownMenuItem(value: '${s['id']}', child: Text(_s(s['name'])))],
              onChanged: (v) => setState(() => _sess = v),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _sem,
              decoration: const InputDecoration(labelText: 'Semester', border: OutlineInputBorder()),
              items: [for (final s in semesters) DropdownMenuItem(value: '${s['id']}', child: Text(_s(s['name'])))],
              onChanged: (v) => setState(() => _sem = v),
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _register,
            style: FilledButton.styleFrom(backgroundColor: kTeal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add),
            label: const Text('Register'),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      _Box(
        title: 'Registration Record',
        child: regs.isEmpty
            ? const _Empty('No registration records found.')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(kBg),
                  columnSpacing: 48,
                  columns: [
                    DataColumn(label: _hdr('Session')),
                    DataColumn(label: _hdr('Semester')),
                    DataColumn(label: _hdr('Date')),
                    DataColumn(label: _hdr('Status')),
                  ],
                  rows: [
                    for (final r in regs)
                      DataRow(cells: [
                        DataCell(Text(_s(r['session']))),
                        DataCell(Text(_s(r['semester']))),
                        DataCell(Text(_d(r['date']))),
                        DataCell(_Pill(_s(r['status']), _statusColor(_s(r['status'])))),
                      ]),
                  ],
                ),
              ),
      ),
      const SizedBox(height: 16),
      _Box(
        title: 'Registered Courses',
        child: regCourses.isEmpty
            ? const _Empty('No courses found for this semester.')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(kBg),
                  columnSpacing: 48,
                  columns: [
                    DataColumn(label: _hdr('Code')),
                    DataColumn(label: _hdr('Course')),
                    DataColumn(label: _hdr('Cr. Hrs')),
                  ],
                  rows: [
                    for (final c in regCourses) DataRow(cells: [DataCell(Text(_s(c['code']))), DataCell(Text(_s(c['name']))), DataCell(Text(_s(c['creditHours'])))]),
                  ],
                ),
              ),
      ),
    ]);
  }
}

// ---- course
class _CoursesPage extends StatelessWidget {
  const _CoursesPage();
  @override
  Widget build(BuildContext context) =>
      _Scaffold('My Courses', '${_st('department')} • ${_l('courses').length} courses • ${_credits()} credit hours', [_courseGrid()]);
}

// ---- attendance
class _AttRow extends StatelessWidget {
  final String name;
  final int p, t;
  const _AttRow(this.name, this.p, this.t);
  @override
  Widget build(BuildContext context) {
    final pct = t == 0 ? 0.0 : p / t;
    final c = _pctColor(pct);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('$p / $t classes', style: const TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(width: 10),
          _Pill('${(pct * 100).round()}%', c),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: pct, minHeight: 7, color: c, backgroundColor: c.withValues(alpha: .15)),
        ),
      ]),
    );
  }
}

class _AttendancePage extends StatelessWidget {
  const _AttendancePage();
  @override
  Widget build(BuildContext context) {
    final att = _l('attendance');
    final present = att.fold<int>(0, (s, a) => s + _n(a['present']));
    final total = att.fold<int>(0, (s, a) => s + _n(a['total']));
    return _Scaffold('Attendance', '${_st('session')} • Minimum required: 75%', [
      Wrap(spacing: 16, runSpacing: 16, children: [
        _Stat(Icons.event_available_outlined, 'Overall Attendance', total == 0 ? '-' : '${(present / total * 100).round()}%', kTeal),
        _Stat(Icons.check_circle_outline, 'Classes Attended', '$present', kGreen),
        _Stat(Icons.cancel_outlined, 'Classes Missed', '${total - present}', kRed),
      ]),
      const SizedBox(height: 20),
      _Box(
        title: 'Course-wise Attendance',
        child: att.isEmpty
            ? const _Empty('No attendance records found.')
            : Column(children: [for (final a in att) _AttRow(_s(a['course']), _n(a['present']), _n(a['total']))]),
      ),
    ]);
  }
}

// ---- assignments
class _AssignmentsPage extends StatelessWidget {
  final Future<void> Function() onReload;
  const _AssignmentsPage({required this.onReload});

  bool _isOver(Map<String, dynamic> a) {
    final due = DateTime.tryParse('${a['dueDate']}');
    return due != null && DateTime.now().toUtc().isAfter(due.add(const Duration(days: 1)));
  }

  Future<void> _submit(BuildContext context, Map<String, dynamic> a) async {
    final old = a['submission'] is Map ? Map<String, dynamic>.from(a['submission'] as Map) : null;
    final v = await _form(context, _s(a['title']), [
      ['text', 'Your answer', old == null ? '' : _s(old['text'], '')],
    ], multi: {'text'}, ok: old == null ? 'Submit' : 'Update');
    if (v == null || !context.mounted) return;
    final err = await submitAssignmentApi('${a['assignmentId']}', v['text']!);
    if (!context.mounted) return;
    if (err != null) {
      _toast(context, err, true);
      return;
    }
    await onReload();
    if (context.mounted) _toast(context, 'Assignment submitted.');
  }

  String _subText(Map<String, dynamic> a, Map<String, dynamic>? sub) {
    final b = StringBuffer('${_s(a['course'])} • Due: ${_d(a['dueDate'])}');
    if (a['totalMarks'] != null) b.write(' • ${_s(a['totalMarks'])} marks');
    final desc = _s(a['description'], '');
    if (desc.isNotEmpty) b.write('\n$desc');
    if (sub != null) {
      b.write('\nSubmitted: ${_d(sub['date'])}');
      if (sub['grade'] != null) {
        final tot = a['totalMarks'] != null ? ' / ${_s(a['totalMarks'])}' : '';
        b.write('\nGrade: ${_s(sub['grade'])}$tot');
      }
      final fb = _s(sub['feedback'], '');
      if (fb.isNotEmpty) b.write('\nFeedback: $fb');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final list = _l('assignments');
    final done = list.where((a) => a['submission'] != null).length;
    return _Scaffold('Assignments', 'Submit your work before the deadline', [
      Wrap(spacing: 16, runSpacing: 16, children: [
        _Stat(Icons.assignment_outlined, 'Total', '${list.length}', kBlue),
        _Stat(Icons.check_circle_outline, 'Submitted', '$done', kGreen),
        _Stat(Icons.pending_actions_outlined, 'Remaining', '${list.length - done}', kAmber),
      ]),
      const SizedBox(height: 20),
      _Box(
        pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: list.isEmpty
            ? const _Empty('No assignments found. (Add courses first from Add / Drop Courses.)')
            : Column(children: [
                for (final a in list)
                  Column(children: [
                    () {
                      final sub = a['submission'] is Map ? Map<String, dynamic>.from(a['submission'] as Map) : null;
                      final over = _isOver(a);
                      final label = sub != null ? 'Submitted' : (over ? 'Overdue' : 'Pending');
                      final col = sub != null ? kGreen : (over ? kRed : kAmber);
                      return _Row(
                        Icons.assignment_outlined,
                        col,
                        _s(a['title']),
                        _subText(a, sub),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _Pill(label, col),
                          if (!over) TextButton(onPressed: () => _submit(context, a), child: Text(sub == null ? 'Submit' : 'Edit')),
                        ]),
                      );
                    }(),
                    if (a != list.last) const Divider(height: 1, color: kLine),
                  ]),
              ]),
      ),
    ]);
  }
}

// ---- marks
class _MarksPage extends StatelessWidget {
  const _MarksPage();
  @override
  Widget build(BuildContext context) {
    final m = _l('marks');
    final o = m.fold<num>(0, (s, x) => s + (x['obtained'] is num ? x['obtained'] as num : 0));
    final t = m.fold<num>(0, (s, x) => s + (x['total'] is num ? x['total'] as num : 0));
    return _Scaffold('Marks', '${_st('session')} academic performance', [
      Wrap(spacing: 16, runSpacing: 16, children: [
        _Stat(Icons.workspace_premium_outlined, 'Overall', _marksPct(), kGreen),
        _Stat(Icons.edit_note_outlined, 'Marks Obtained', '$o', kBlue),
        _Stat(Icons.functions, 'Total Marks', '$t', kAmber),
      ]),
      const SizedBox(height: 20),
      _Box(
        title: 'Result Summary',
        child: m.isEmpty
            ? const _Empty('Marks have not been uploaded yet.')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(kBg),
                  columnSpacing: 36,
                  columns: [
                    DataColumn(label: _hdr('Course')),
                    DataColumn(label: _hdr('Exam')),
                    DataColumn(label: _hdr('Obtained')),
                    DataColumn(label: _hdr('Total')),
                    DataColumn(label: _hdr('%')),
                  ],
                  rows: [
                    for (final g in m)
                      DataRow(cells: [
                        DataCell(Text(_s(g['course']))),
                        DataCell(Text(_s(g['examType']))),
                        DataCell(Text(_s(g['obtained']), style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(_s(g['total']))),
                        DataCell(() {
                          final tt = g['total'] is num ? g['total'] as num : 0;
                          final oo = g['obtained'] is num ? g['obtained'] as num : 0;
                          final p = tt == 0 ? 0.0 : oo / tt;
                          return _Pill('${(p * 100).round()}%', _pctColor(p));
                        }()),
                      ]),
                  ],
                ),
              ),
      ),
    ]);
  }
}

// ---- timetable
class _TimetablePage extends StatelessWidget {
  const _TimetablePage();
  @override
  Widget build(BuildContext context) {
    final tt = _l('timetable');
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final d in days) {
      final l = tt.where((t) => t['day'] == d).toList()..sort((a, b) => '${a['start']}'.compareTo('${b['start']}'));
      if (l.isNotEmpty) byDay[d] = l;
    }
    return _Scaffold('Timetable', '${_st('department')} • Weekly class schedule', [
      if (byDay.isEmpty)
        const _Box(child: _Empty('Timetable is not available yet.'))
      else
        LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth >= 800 ? (c.maxWidth - 32) / 3 : c.maxWidth;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (final d in byDay.entries)
              SizedBox(
                width: w,
                child: _Box(
                  title: d.key,
                  child: Column(children: [
                    for (final s in d.value)
                      _Row(Icons.schedule, kBlue, _s(s['course']), '${_s(s['start'])} - ${_s(s['end'])} • ${_s(s['room'])}\n${_s(s['shift'])} shift'),
                  ]),
                ),
              ),
          ]);
        }),
    ]);
  }
}

// ---- examslip
class _ExamSlipPage extends StatelessWidget {
  const _ExamSlipPage();
  @override
  Widget build(BuildContext context) {
    final slips = _l('examslips');
    return _Scaffold('Exam Slip', 'Examination slips issued to you', [
      _Box(
        title: 'Candidate Details',
        child: _kvGrid([
          ['Name', _st('name')],
          ['Roll No', _st('rollNo')],
          ['Department', _st('department')],
          ['Semester', _st('semester')],
        ]),
      ),
      const SizedBox(height: 16),
      _Box(
        title: 'Issued Slips',
        child: slips.isEmpty
            ? const _Empty('No exam slips issued yet.')
            : Column(children: [
                for (final s in slips)
                  _Row(Icons.event_note_outlined, kBlue, '${_s(s['examType'])} Exam Slip', '${_s(s['semester'])} • Issued: ${_d(s['issueDate'])}', _Pill('Issued', kGreen)),
              ]),
      ),
    ]);
  }
}

// ---- feeChallan
class _FeePage extends StatelessWidget {
  const _FeePage();
  @override
  Widget build(BuildContext context) {
    final fees = _l('fees');
    num sum(bool paid) => fees.where((f) => (_s(f['status']).toLowerCase() == 'paid') == paid).fold<num>(0, (s, f) => s + (f['amount'] is num ? f['amount'] as num : 0));
    final paid = sum(true), due = sum(false);
    return _Scaffold('Fee Challan', 'Your fee vouchers', [
      Wrap(spacing: 16, runSpacing: 16, children: [
        _Stat(Icons.receipt_long_outlined, 'Total Fee', 'Rs. ${_money(paid + due)}', kBlue),
        _Stat(Icons.payments_outlined, 'Paid', 'Rs. ${_money(paid)}', kGreen),
        _Stat(Icons.warning_amber_outlined, 'Due Amount', 'Rs. ${_money(due)}', kRed),
      ]),
      const SizedBox(height: 20),
      if (fees.isEmpty) const _Box(child: _Empty('No fee challans found.')),
      for (final f in fees) ...[
        _Box(
          title: 'Challan ${_s(f['challanId'])}',
          child: Column(children: [
            Row(children: [
              Expanded(child: _kv('Semester', _s(f['semester']))),
              Expanded(child: _kv('Due Date', _d(f['dueDate']))),
              _Pill(_s(f['status']).toUpperCase(), _statusColor(_s(f['status']))),
            ]),
            const SizedBox(height: 14),
            const Divider(color: kLine),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Payable', style: TextStyle(fontWeight: FontWeight.bold, color: kNavy)),
                Text('Rs. ${_money(f['amount'] is num ? f['amount'] as num : 0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: kNavy, fontSize: 16)),
              ]),
            ),
            if (f['paidDate'] != null) Align(alignment: Alignment.centerLeft, child: Text('Paid on: ${_d(f['paidDate'])}', style: const TextStyle(color: kMuted, fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 14),
      ],
    ]);
  }
}

// ---- announcements
class _AnnouncementsPage extends StatelessWidget {
  const _AnnouncementsPage();
  @override
  Widget build(BuildContext context) {
    final list = _l('announcements');
    return _Scaffold('Announcements', 'Latest announcements from the university', [
      _Box(
        pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: list.isEmpty
            ? const _Empty('No announcements.')
            : Column(children: [
                for (final n in list)
                  Column(children: [
                    _Row(Icons.campaign_outlined, kNavy, _s(n['title']), '${_s(n['message'])}\nPosted: ${_d(n['date'])}', _Pill('Till ${_d(n['expiry'])}', kBlue)),
                    if (n != list.last) const Divider(height: 1, color: kLine),
                  ]),
              ]),
      ),
    ]);
  }
}

// ---- uni_info
class _UniPage extends StatelessWidget {
  const _UniPage();
  @override
  Widget build(BuildContext context) {
    final u = _m('uni');
    return _Scaffold('University Info', 'About your university', [
      _Box(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance, color: kGold, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(_s(u['name']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kNavy))),
        ]),
      ),
      const SizedBox(height: 16),
      _Box(title: 'Contact', child: Column(children: [
        _Row(Icons.location_on_outlined, kRed, 'Address', _s(u['address'])),
        _Row(Icons.phone_outlined, kGreen, 'Phone', _s(u['phone'])),
        _Row(Icons.email_outlined, kBlue, 'Email', _s(u['email'])),
      ])),
    ]);
  }
}


// ---- ADD / DROP COURSES (student)
class _EnrollPage extends StatefulWidget {
  final Future<void> Function() onReload;
  const _EnrollPage({required this.onReload});
  @override
  State<_EnrollPage> createState() => _EnrollPageState();
}

class _EnrollPageState extends State<_EnrollPage> {
  String? _busyId;

  Future<void> _act(Map<String, dynamic> c, bool enroll) async {
    if (!enroll) {
      final yes = await _confirm(context, 'Drop course?', '${_s(c['name'])} will be dropped.');
      if (!yes || !mounted) return;
    }
    final id = '${c['courseId']}';
    setState(() => _busyId = id);
    final err = enroll ? await enrollApi(id) : await dropApi(id);
    if (!mounted) return;
    setState(() => _busyId = null);
    if (err != null) {
      _toast(context, err, true);
      return;
    }
    await widget.onReload();
    if (mounted) _toast(context, enroll ? 'Course added.' : 'Course dropped.');
  }

  @override
  Widget build(BuildContext context) {
    final cat = _l('catalog');
    final enrolled = cat.where((c) => c['enrolled'] == true).toList();
    final cr = enrolled.fold<int>(0, (s, c) => s + _n(c['creditHours']));
    final max = _n(_p['maxCredits']);
    return _Scaffold('Add / Drop Courses', '${_st('department')} • Max $max credit hours', [
      Wrap(spacing: 16, runSpacing: 16, children: [
        _Stat(Icons.menu_book_outlined, 'Enrolled Courses', '${enrolled.length}', kBlue),
        _Stat(Icons.library_books_outlined, 'Credit Hours', '$cr / $max', cr > max ? kRed : kTeal),
        _Stat(Icons.library_add_outlined, 'Available', '${cat.length - enrolled.length}', kGreen),
      ]),
      const SizedBox(height: 20),
      _Box(
        title: 'Department Courses',
        child: cat.isEmpty
            ? const _Empty('There are no courses in this department.')
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(kBg),
                  columnSpacing: 32,
                  columns: [
                    DataColumn(label: _hdr('Code')),
                    DataColumn(label: _hdr('Course')),
                    DataColumn(label: _hdr('Semester')),
                    DataColumn(label: _hdr('Teacher')),
                    DataColumn(label: _hdr('Cr. Hrs')),
                    DataColumn(label: _hdr('Status')),
                    DataColumn(label: _hdr('Action')),
                  ],
                  rows: [
                    for (final c in cat)
                      DataRow(cells: [
                        DataCell(Text(_s(c['code']))),
                        DataCell(Text(_s(c['name']))),
                        DataCell(Text(_s(c['semester']))),
                        DataCell(Text(_s(c['teacher']))),
                        DataCell(Text(_s(c['creditHours']))),
                        DataCell(_Pill(c['enrolled'] == true ? 'Enrolled' : 'Not enrolled', c['enrolled'] == true ? kGreen : kMuted)),
                        DataCell(_busyId == '${c['courseId']}'
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : c['enrolled'] == true
                                ? OutlinedButton(
                                    onPressed: () => _act(c, false),
                                    style: OutlinedButton.styleFrom(foregroundColor: kRed),
                                    child: const Text('Drop'))
                                : FilledButton(
                                    onPressed: () => _act(c, true),
                                    style: FilledButton.styleFrom(backgroundColor: kTeal),
                                    child: const Text('Add'))),
                      ]),
                  ],
                ),
              ),
      ),
    ]);
  }
}

// ---- CLASS TOOLS (teacher / admin): bulk attendance + marks
String _today() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

class _ClassToolsPage extends StatefulWidget {
  const _ClassToolsPage();
  @override
  State<_ClassToolsPage> createState() => _ClassToolsPageState();
}

class _ClassToolsPageState extends State<_ClassToolsPage> {
  String _mode = 'Attendance';
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _roster = [];
  String? _course;
  bool _busy = false, _loadingRoster = false, _coursesLoaded = false;
  final _date = TextEditingController(text: _today());
  final _total = TextEditingController(text: '100');
  String _exam = 'Midterm';
  final Map<String, bool> _present = {};
  final Map<String, TextEditingController> _marks = {};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _date.dispose();
    _total.dispose();
    for (final c in _marks.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCourses() async {
    final c = await staffCoursesApi();
    if (!mounted) return;
    setState(() {
      _courses = c ?? [];
      _coursesLoaded = true;
    });
  }

  Future<void> _pickCourse(String? id) async {
    if (id == null) return;
    setState(() {
      _course = id;
      _loadingRoster = true;
      _roster = [];
    });
    final r = await staffRosterApi(id);
    if (!mounted) return;
    for (final c in _marks.values) {
      c.dispose();
    }
    _marks.clear();
    _present.clear();
    final list = r ?? <Map<String, dynamic>>[];
    for (final s in list) {
      final k = '${s['studentId']}';
      _present[k] = true;
      _marks[k] = TextEditingController();
    }
    setState(() {
      _roster = list;
      _loadingRoster = false;
    });
  }

  Future<void> _pickDate() async {
    final cur = DateTime.tryParse(_date.text) ?? DateTime.now();
    final d = await showDatePicker(context: context, initialDate: cur, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) {
      _date.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _saveAtt() async {
    if (_course == null || _roster.isEmpty) {
      _toast(context, 'Select a course that has enrolled students first.', true);
      return;
    }
    setState(() => _busy = true);
    final err = await staffAttendanceApi({
      'courseId': _course,
      'date': _date.text,
      'records': [
        for (final s in _roster) {'studentId': s['studentId'], 'status': _present['${s['studentId']}'] == false ? 'absent' : 'present'},
      ],
    });
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(context, err ?? 'Attendance saved.', err != null);
  }

  Future<void> _saveMarks() async {
    if (_course == null || _roster.isEmpty) {
      _toast(context, 'Select a course that has enrolled students first.', true);
      return;
    }
    setState(() => _busy = true);
    final err = await staffMarksApi({
      'courseId': _course,
      'examType': _exam,
      'totalMarks': _total.text,
      'records': [
        for (final s in _roster) {'studentId': s['studentId'], 'obtained': _marks['${s['studentId']}']!.text},
      ],
    });
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(context, err ?? 'Marks saved.', err != null);
  }

  @override
  Widget build(BuildContext context) {
    final att = _mode == 'Attendance';
    return _Scaffold('Class Tools', 'Mark attendance and enter marks', [
      Wrap(spacing: 8, children: [
        for (final m in ['Attendance', 'Marks'])
          ChoiceChip(
            label: Text(m),
            selected: _mode == m,
            selectedColor: kNavy,
            labelStyle: TextStyle(color: _mode == m ? Colors.white : kInk),
            showCheckmark: false,
            onSelected: (_) => setState(() => _mode = m),
          ),
      ]),
      const SizedBox(height: 16),
      _Box(
        title: att ? 'Mark Attendance' : 'Enter Marks',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_coursesLoaded && _courses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text('No course is assigned to you yet. Ask the admin to set you as Teacher in Manage Data > Course.',
                  style: TextStyle(color: kRed)),
            ),
          Wrap(spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                value: _course,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Course', border: OutlineInputBorder()),
                items: [for (final c in _courses) DropdownMenuItem(value: '${c['id']}', child: Text('${c['label']}', overflow: TextOverflow.ellipsis))],
                onChanged: _pickCourse,
              ),
            ),
            if (att)
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _date,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                ),
              )
            else ...[
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _exam,
                  decoration: const InputDecoration(labelText: 'Exam Type', border: OutlineInputBorder()),
                  items: [for (final e in ['Midterm', 'Final', 'Quiz', 'Assignment']) DropdownMenuItem(value: e, child: Text(e))],
                  onChanged: (v) => setState(() => _exam = v ?? 'Midterm'),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _total,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Marks', border: OutlineInputBorder()),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          if (_loadingRoster)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else if (_course == null)
            const _Empty('Select a course first.')
          else if (_roster.isEmpty)
            const _Empty('No students are enrolled in this course.')
          else ...[
            if (att)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    for (final k in _present.keys.toList()) {
                      _present[k] = true;
                    }
                  }),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Mark all present'),
                ),
              ),
            for (final s in _roster)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${_s(s['rollNo'])} — ${_s(s['name'])}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (att) ...[
                    _Pill(_present['${s['studentId']}'] == false ? 'Absent' : 'Present', _present['${s['studentId']}'] == false ? kRed : kGreen),
                    Switch(
                      value: _present['${s['studentId']}'] != false,
                      activeThumbColor: kTeal,
                      onChanged: (v) => setState(() => _present['${s['studentId']}'] = v),
                    ),
                  ] else
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _marks['${s['studentId']}'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, hintText: 'Obtained', border: OutlineInputBorder()),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : (att ? _saveAtt : _saveMarks),
              style: FilledButton.styleFrom(backgroundColor: kTeal, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(att ? 'Save Attendance' : 'Save Marks'),
            ),
          ],
        ]),
      ),
    ]);
  }
}


// ---- shared: hero banner + chip for staff dashboards
Widget _heroChip(IconData i, String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, color: kGold, size: 15),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );

Widget _hero(String title, String sub, List<Widget> chips) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kNavy, Color(0xFF0B4F6C), kTeal]),
        boxShadow: [BoxShadow(color: kNavy.withValues(alpha: .25), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: .8))),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 8, children: chips),
        ],
      ]),
    );

// ---- ADMIN DASHBOARD
class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard();
  @override
  Widget build(BuildContext context) {
    final o = _m('overview');
    String v(String k) => '${_n(o[k])}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hero('Welcome, ${_st('name')}!', 'Admin dashboard: overview of the whole system.', [
          _heroChip(Icons.admin_panel_settings_outlined, 'Admin'),
          _heroChip(Icons.apartment_outlined, 'NUML_LMS'),
        ]),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _Stat(Icons.people_outline, 'Total Users', v('users'), kBlue),
          _Stat(Icons.school_outlined, 'Teachers', v('teachers'), kTeal),
          _Stat(Icons.menu_book_outlined, 'Courses', v('courses'), kGreen),
          _Stat(Icons.how_to_reg_outlined, 'Active Enrollments', v('enrollments'), kAmber),
          _Stat(Icons.assignment_outlined, 'Assignments', v('assignments'), kBlue),
          _Stat(Icons.badge_outlined, 'Pending ID Cards', v('pendingCards'), kRed),
          _Stat(Icons.warning_amber_outlined, 'Unpaid Challans', v('unpaidFees'), kRed),
        ]),
        const SizedBox(height: 20),
        _Box(
          title: 'Quick Guide',
          child: Column(children: [
            _Row(Icons.admin_panel_settings_outlined, kNavy, 'Manage Data', 'Add, edit or delete records in any collection.'),
            _Row(Icons.badge_outlined, kRed, 'ID Card Requests', 'Approve or reject ID card requests from students.'),
            _Row(Icons.school_outlined, kTeal, 'Assigning teachers', 'Set the role to teacher in Manage Data > Students, then choose the Teacher in Manage Data > Course.'),
          ]),
        ),
      ]),
    );
  }
}

// ---- TEACHER DASHBOARD
class _TeacherDashboard extends StatelessWidget {
  const _TeacherDashboard();
  @override
  Widget build(BuildContext context) {
    final t = _l('teaching');
    final students = t.fold<int>(0, (s, c) => s + _n(c['students']));
    final asg = t.fold<int>(0, (s, c) => s + _n(c['assignments']));
    final toGrade = t.fold<int>(0, (s, c) => s + _n(c['ungraded']));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hero('Welcome, ${_st('name')}!', 'Teacher dashboard: your courses and students.', [
          _heroChip(Icons.school_outlined, 'Teacher'),
          _heroChip(Icons.menu_book_outlined, '${t.length} courses'),
        ]),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _Stat(Icons.menu_book_outlined, 'My Courses', '${t.length}', kBlue),
          _Stat(Icons.people_outline, 'Enrolled Students', '$students', kTeal),
          _Stat(Icons.assignment_outlined, 'Assignments', '$asg', kAmber),
          _Stat(Icons.rate_review_outlined, 'To Grade', '$toGrade', kRed),
        ]),
        const SizedBox(height: 20),
        _Box(
          title: 'My Courses',
          child: t.isEmpty
              ? const _Empty('No course is assigned to you yet. Ask the admin to set you as Teacher in Manage Data > Course.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(kBg),
                    columnSpacing: 36,
                    columns: [
                      DataColumn(label: _hdr('Code')),
                      DataColumn(label: _hdr('Course')),
                      DataColumn(label: _hdr('Semester')),
                      DataColumn(label: _hdr('Students')),
                      DataColumn(label: _hdr('Assignments')),
                      DataColumn(label: _hdr('To grade')),
                    ],
                    rows: [
                      for (final c in t)
                        DataRow(cells: [
                          DataCell(Text(_s(c['code']))),
                          DataCell(Text(_s(c['name']))),
                          DataCell(Text(_s(c['semester']))),
                          DataCell(Text('${_n(c['students'])}')),
                          DataCell(Text('${_n(c['assignments'])}')),
                          DataCell(_Pill('${_n(c['ungraded'])}', _n(c['ungraded']) > 0 ? kRed : kGreen)),
                        ]),
                    ],
                  ),
                ),
        ),
      ]),
    );
  }
}

// ---- ADMIN: ID card requests
class _IdRequestsPage extends StatefulWidget {
  final Future<void> Function() onReload;
  const _IdRequestsPage({required this.onReload});
  @override
  State<_IdRequestsPage> createState() => _IdRequestsPageState();
}

class _IdRequestsPageState extends State<_IdRequestsPage> {
  List<Map<String, dynamic>> _rows = [];
  String _f = 'pending';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await adminIdCardsApi();
    if (!mounted) return;
    setState(() {
      _rows = r ?? [];
      _loading = false;
    });
  }

  Future<void> _decide(Map<String, dynamic> c, String status) async {
    final err = await adminIdCardDecideApi('${c['idCardId']}', status);
    if (!mounted) return;
    if (err != null) {
      _toast(context, err, true);
      return;
    }
    _toast(context, status == 'active' ? 'Card approved.' : 'Card blocked.');
    await _load();
    await widget.onReload();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _f == 'all' ? _rows : _rows.where((r) => _s(r['status']).toLowerCase() == _f).toList();
    return _Scaffold('ID Card Requests', 'Approve or reject student ID card requests', [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final f in ['pending', 'active', 'blocked', 'expired', 'all'])
          ChoiceChip(
            label: Text(f),
            selected: _f == f,
            selectedColor: kNavy,
            labelStyle: TextStyle(color: _f == f ? Colors.white : kInk),
            showCheckmark: false,
            onSelected: (_) => setState(() => _f = f),
          ),
      ]),
      const SizedBox(height: 16),
      _Box(
        title: 'Cards (${shown.length})',
        child: _loading
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            : shown.isEmpty
                ? const _Empty('No cards match this filter.')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(kBg),
                      columnSpacing: 30,
                      columns: [
                        DataColumn(label: _hdr('Student')),
                        DataColumn(label: _hdr('Roll No')),
                        DataColumn(label: _hdr('Card No')),
                        DataColumn(label: _hdr('Status')),
                        DataColumn(label: _hdr('Action')),
                      ],
                      rows: [
                        for (final c in shown)
                          DataRow(cells: [
                            DataCell(Text(_s(c['name']))),
                            DataCell(Text(_s(c['rollNo']))),
                            DataCell(Text(_s(c['cardNo']))),
                            DataCell(_Pill(_s(c['status']), _statusColor(_s(c['status'])))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              if (_s(c['status']) == 'pending' || _s(c['status']) == 'blocked')
                                FilledButton(
                                  onPressed: () => _decide(c, 'active'),
                                  style: FilledButton.styleFrom(backgroundColor: kTeal),
                                  child: const Text('Approve'),
                                ),
                              if (_s(c['status']) == 'pending' || _s(c['status']) == 'active') ...[
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _decide(c, 'blocked'),
                                  style: OutlinedButton.styleFrom(foregroundColor: kRed),
                                  child: Text(_s(c['status']) == 'pending' ? 'Reject' : 'Block'),
                                ),
                              ],
                            ])),
                          ]),
                      ],
                    ),
                  ),
      ),
    ]);
  }
}

// ---- ADMIN: Manage Data (har collection ka add / edit / delete)
class _ManagePage extends StatefulWidget {
  final Future<void> Function() onReload;
  const _ManagePage({required this.onReload});
  @override
  State<_ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<_ManagePage> {
  List<Map<String, dynamic>> _schema = [];
  Map<String, dynamic>? _cur;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _refs = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  List<Map<String, dynamic>> get _fields =>
      ((_cur!['fields'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _init() async {
    final s = await adminSchemaApi();
    if (!mounted) return;
    if (s == null || s.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Could not load admin data. Restart the server and check that your account has the admin or teacher role.';
      });
      return;
    }
    _schema = s;
    _cur = s.first;
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await adminListApi('${_cur!['name']}');
    if (!mounted) return;
    if (r == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load data.';
      });
      return;
    }
    setState(() {
      _rows = ((r['rows'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _refs = Map<String, dynamic>.from((r['refs'] as Map?) ?? {});
      _loading = false;
      _error = null;
    });
  }

  String _cell(Map<String, dynamic> f, Map<String, dynamic> row) {
    final v = row[f['key']];
    if (v == null || '$v'.isEmpty) return '-';
    if (f['type'] == 'date') return _d(v);
    if (f['type'] == 'ref') {
      for (final e in ((_refs[f['key']] as List?) ?? [])) {
        if (e['id'] == v) return '${e['label']}';
      }
    }
    return '$v';
  }

  Future<void> _after(String? err, String okMsg) async {
    if (!mounted) return;
    if (err != null) {
      _toast(context, err, true);
      return;
    }
    _toast(context, okMsg);
    await _load();
    await widget.onReload();
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final name = '${_cur!['name']}';
    final idField = '${_cur!['idField']}';
    final vals = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RecordDialog(
        title: row == null ? 'Add ${_cur!['title']}' : 'Edit ${_cur!['title']} (${row[idField]})',
        fields: _fields,
        refs: _refs,
        initial: row,
      ),
    );
    if (vals == null) return;
    final err = await adminSaveApi(name, vals, id: row == null ? null : '${row[idField]}');
    await _after(err, row == null ? 'Record added.' : 'Record updated.');
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final idField = '${_cur!['idField']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('${row[idField]} will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kRed), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final err = await adminDeleteApi('${_cur!['name']}', '${row[idField]}');
    await _after(err, 'Record deleted.');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _cur == null) {
      return _Scaffold('Manage Data', 'Add, edit and delete — saved directly to MongoDB', [_Box(child: _Empty(_error!))]);
    }
    if (_cur == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final idField = '${_cur!['idField']}';
    final fields = _fields.where((f) => f['type'] != 'password').toList();
    return _Scaffold('Manage Data', 'Add, edit and delete — saved directly to MongoDB', [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in _schema)
          ChoiceChip(
            label: Text('${s['title']}'),
            selected: _cur!['name'] == s['name'],
            selectedColor: kNavy,
            labelStyle: TextStyle(color: _cur!['name'] == s['name'] ? Colors.white : kInk),
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _cur = s);
              _load();
            },
          ),
      ]),
      const SizedBox(height: 16),
      _Box(
        title: '${_cur!['title']}  (${_rows.length})',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _edit(),
              style: FilledButton.styleFrom(backgroundColor: kTeal),
              icon: const Icon(Icons.add),
              label: Text('Add ${_cur!['title']}'),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            _Empty(_error!)
          else if (_rows.isEmpty)
            const _Empty('This collection has no records yet.')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(kBg),
                columnSpacing: 28,
                columns: [
                  DataColumn(label: _hdr(idField)),
                  for (final f in fields) DataColumn(label: _hdr('${f['label']}')),
                  DataColumn(label: _hdr('Actions')),
                ],
                rows: [
                  for (final r in _rows)
                    DataRow(cells: [
                      DataCell(Text('${r[idField]}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      for (final f in fields)
                        DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 240), child: Text(_cell(f, r), maxLines: 2, overflow: TextOverflow.ellipsis))),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, color: kBlue), tooltip: 'Edit', onPressed: () => _edit(r)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: kRed), tooltip: 'Delete', onPressed: () => _delete(r)),
                      ])),
                    ]),
                ],
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _RecordDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> refs;
  final Map<String, dynamic>? initial;
  const _RecordDialog({required this.title, required this.fields, required this.refs, this.initial});
  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final Map<String, TextEditingController> _c = {};
  final Map<String, String?> _v = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final k = '${f['key']}';
      final raw = widget.initial?[k];
      var s = raw == null ? '' : '$raw';
      if (f['type'] == 'date' && s.length >= 10) s = s.substring(0, 10);
      if (f['type'] == 'password') s = '';
      if (f['type'] == 'ref' || f['type'] == 'select') {
        _v[k] = s.isEmpty ? null : s;
      } else {
        _c[k] = TextEditingController(text: s);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(String k) async {
    final cur = DateTime.tryParse(_c[k]!.text) ?? DateTime.now();
    final d = await showDatePicker(context: context, initialDate: cur, firstDate: DateTime(1950), lastDate: DateTime(2100));
    if (d != null) {
      _c[k]!.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _field(Map<String, dynamic> f) {
    final k = '${f['key']}';
    final label = '${f['label']}${f['optional'] == true ? ' (optional)' : ''}';
    final type = '${f['type']}';
    if (type == 'ref') {
      final items = ((widget.refs[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return DropdownButtonFormField<String>(
        value: items.any((e) => '${e['id']}' == _v[k]) ? _v[k] : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [for (final e in items) DropdownMenuItem(value: '${e['id']}', child: Text('${e['label']}', overflow: TextOverflow.ellipsis))],
        onChanged: (x) => setState(() => _v[k] = x),
      );
    }
    if (type == 'select') {
      final opts = ((f['options'] as List?) ?? []).map((e) => '$e').toList();
      return DropdownButtonFormField<String>(
        value: opts.contains(_v[k]) ? _v[k] : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
        onChanged: (x) => setState(() => _v[k] = x),
      );
    }
    if (type == 'date') {
      return TextField(
        controller: _c[k],
        readOnly: true,
        onTap: () => _pick(k),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (f['optional'] == true) IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _c[k]!.clear())),
            IconButton(icon: const Icon(Icons.calendar_today_outlined, size: 18), onPressed: () => _pick(k)),
          ]),
        ),
      );
    }
    final multi = f['multiline'] == true;
    return TextField(
      controller: _c[k],
      obscureText: type == 'password',
      keyboardType: type == 'number' ? const TextInputType.numberWithOptions(decimal: true) : null,
      minLines: multi ? 3 : 1,
      maxLines: multi ? 6 : 1,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: type == 'password' && widget.initial != null ? 'Leave blank to keep the current password' : null,
      ),
    );
  }

  Map<String, dynamic> _collect() {
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      final k = '${f['key']}';
      out[k] = _c.containsKey(k) ? _c[k]!.text : (_v[k] ?? '');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final f in widget.fields) Padding(padding: const EdgeInsets.only(top: 12), child: _field(f)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kTeal), onPressed: () => Navigator.pop(context, _collect()), child: const Text('Save')),
        ],
      );
}

// ---- settings
class _SettingsPage extends StatefulWidget {
  final VoidCallback onLogout;
  const _SettingsPage({required this.onLogout});
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool _n1 = true, _e1 = true, _d1 = false;

  Future<void> _changePw() async {
    final v = await _form(context, 'Change Password', [
      ['old', 'Current password'],
      ['new1', 'New password (at least 6 characters)'],
      ['new2', 'Confirm new password'],
    ], ok: 'Change', secret: {'old', 'new1', 'new2'});
    if (v == null || !mounted) return;
    if (v['new1'] != v['new2']) {
      _toast(context, 'The new passwords do not match.', true);
      return;
    }
    final err = await changePasswordApi(v['old']!, v['new1']!);
    if (!mounted) return;
    _toast(context, err ?? 'Password changed.', err != null);
  }

  @override
  Widget build(BuildContext context) => _Scaffold('Settings', 'Manage your profile and preferences', [
        _Box(
          title: 'Profile',
          child: Row(children: [
            CircleAvatar(radius: 34, backgroundColor: kNavy, child: Text(_initial(), style: const TextStyle(color: kGold, fontSize: 28, fontWeight: FontWeight.bold))),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_st('name'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Roll No: ${_st('rollNo')}', style: const TextStyle(color: kMuted)),
                Text('${_st('department')} • ${_st('semester')}', style: const TextStyle(color: kMuted)),
                Text(_st('email'), style: const TextStyle(color: kMuted)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _Box(
          title: 'Security',
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(onPressed: _changePw, icon: const Icon(Icons.lock_reset), label: const Text('Change Password')),
          ),
        ),
        const SizedBox(height: 16),
        _Box(
          title: 'Preferences',
          pad: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(children: [
            SwitchListTile(contentPadding: EdgeInsets.zero, activeThumbColor: kNavy, title: const Text('Push Notifications'), value: _n1, onChanged: (v) => setState(() => _n1 = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, activeThumbColor: kNavy, title: const Text('Email Alerts'), value: _e1, onChanged: (v) => setState(() => _e1 = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, activeThumbColor: kNavy, title: const Text('Dark Mode (static)'), value: _d1, onChanged: (v) => setState(() => _d1 = v)),
          ]),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: widget.onLogout,
            style: FilledButton.styleFrom(backgroundColor: kRed, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ),
      ]);
}

// ---- gender, country, province, city, area, department, semester, session, shift
class _MasterDataPage extends StatefulWidget {
  const _MasterDataPage();
  @override
  State<_MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterDataPageState extends State<_MasterDataPage> {
  String _sel = 'department';
  @override
  Widget build(BuildContext context) {
    final lookups = _m('lookups');
    final keys = lookups.keys.toList();
    final items = ((lookups[_sel] as List?) ?? []).map((e) => '$e').toList();
    return _Scaffold('Master Data', 'Reference collections from the database', [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in keys)
          ChoiceChip(
            label: Text(k),
            avatar: Icon(_lookupIcons[k] ?? Icons.list, size: 16, color: _sel == k ? Colors.white : kNavy),
            selected: _sel == k,
            selectedColor: kNavy,
            labelStyle: TextStyle(color: _sel == k ? Colors.white : kInk),
            showCheckmark: false,
            onSelected: (_) => setState(() => _sel = k),
          ),
      ]),
      const SizedBox(height: 16),
      _Box(
        title: '$_sel  (${items.length})',
        pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: items.isEmpty
            ? const _Empty('This collection has no data.')
            : Column(children: [
                for (final v in items)
                  Column(children: [
                    _Row(_lookupIcons[_sel] ?? Icons.list, kTeal, v, 'Collection: $_sel'),
                    if (v != items.last) const Divider(height: 1, color: kLine),
                  ]),
              ]),
      ),
    ]);
  }
}