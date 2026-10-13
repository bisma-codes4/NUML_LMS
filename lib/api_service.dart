import 'dart:convert';
import 'package:http/http.dart' as http;

const baseUrl = 'http://localhost:3000';

// Login ke baad server jo token deta hai wo yahan rakha jata hai
String? _token;

Map<String, String> get _authHeaders => {'Authorization': 'Bearer $_token'};

void logoutApi() => _token = null;

// Login: token save karta hai, student ki basic info wapis deta hai
Future<Map<String, dynamic>?> loginApi(String email, String password) async {
  final res = await http.post(
    Uri.parse('$baseUrl/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  if (res.statusCode == 200) {
    final body = jsonDecode(res.body) as Map;
    _token = body['token'] as String?;
    return Map<String, dynamic>.from(body['student'] as Map);
  }
  return null;
}

// Login hue student ka poora data (token se pata chalta hai kaun hai)
Future<Map<String, dynamic>?> portalApi() async {
  final res = await http.get(Uri.parse('$baseUrl/portal/me'), headers: _authHeaders);
  if (res.statusCode == 200) {
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }
  return null;
}

// ---------- write actions: null = success, warna error message ----------
Future<String?> _send(String method, String path, Map<String, dynamic> body) async {
  try {
    final uri = Uri.parse('$baseUrl$path');
    final h = {..._authHeaders, 'Content-Type': 'application/json'};
    final res = method == 'PUT'
        ? await http.put(uri, headers: h, body: jsonEncode(body))
        : method == 'DELETE'
            ? await http.delete(uri, headers: h)
            : await http.post(uri, headers: h, body: jsonEncode(body));
    if (res.statusCode == 200) return null;
    try {
      return (jsonDecode(res.body) as Map)['error']?.toString() ?? 'Error ${res.statusCode}';
    } catch (_) {
      return 'Error ${res.statusCode}';
    }
  } catch (_) {
    return 'Cannot connect to the server.';
  }
}

Future<String?> changePasswordApi(String oldPassword, String newPassword) =>
    _send('POST', '/change-password', {'oldPassword': oldPassword, 'newPassword': newPassword});

Future<String?> updateProfileApi(String phone, String address) =>
    _send('PUT', '/profile', {'phone': phone, 'address': address});

Future<String?> submitAssignmentApi(String assignmentId, String text) =>
    _send('POST', '/assignments/$assignmentId/submit', {'text': text});

Future<String?> registerApi(String sessionId, String semesterId) =>
    _send('POST', '/register', {'sessionId': sessionId, 'semesterId': semesterId});

// ---------- SIGNUP (login ke baghair) ----------
Future<Map<String, dynamic>?> publicOptionsApi() async {
  try {
    final res = await http.get(Uri.parse('$baseUrl/public/options'));
    if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  } catch (_) {}
  return null;
}

Future<String?> signupApi(Map<String, dynamic> body) => _send('POST', '/signup', body);

// ---------- ADMIN: har collection ka add / edit / delete ----------
Future<List<Map<String, dynamic>>?> adminSchemaApi() async {
  try {
    final res = await http.get(Uri.parse('$baseUrl/admin/schema'), headers: _authHeaders);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {}
  return null;
}

Future<Map<String, dynamic>?> adminListApi(String name) async {
  try {
    final res = await http.get(Uri.parse('$baseUrl/admin/$name'), headers: _authHeaders);
    if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  } catch (_) {}
  return null;
}

Future<String?> adminSaveApi(String name, Map<String, dynamic> body, {String? id}) =>
    id == null ? _send('POST', '/admin/$name', body) : _send('PUT', '/admin/$name/$id', body);

Future<String?> adminDeleteApi(String name, String id) => _send('DELETE', '/admin/$name/$id', {});

// ---------- COURSE ADD / DROP, ID CARD ----------
Future<String?> enrollApi(String courseId) => _send('POST', '/enroll', {'courseId': courseId});

Future<String?> dropApi(String courseId) => _send('POST', '/drop', {'courseId': courseId});

Future<String?> requestIdCardApi() => _send('POST', '/idcard/request', {});

// ---------- TEACHER / ADMIN: class tools ----------
Future<dynamic> _getJson(String path) async {
  try {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders);
    if (res.statusCode == 200) return jsonDecode(res.body);
  } catch (_) {}
  return null;
}

Future<List<Map<String, dynamic>>?> staffCoursesApi() async {
  final r = await _getJson('/staff/courses');
  if (r is List) return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  return null;
}

Future<List<Map<String, dynamic>>?> staffRosterApi(String courseId) async {
  final r = await _getJson('/staff/roster/$courseId');
  if (r is List) return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  return null;
}

Future<String?> staffAttendanceApi(Map<String, dynamic> body) => _send('POST', '/staff/attendance', body);

Future<String?> staffMarksApi(Map<String, dynamic> body) => _send('POST', '/staff/marks', body);

// ---------- ADMIN: ID card requests ----------
Future<List<Map<String, dynamic>>?> adminIdCardsApi() async {
  final r = await _getJson('/admin-tools/idcards');
  if (r is List) return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  return null;
}

Future<String?> adminIdCardDecideApi(String id, String status) =>
    _send('POST', '/admin-tools/idcards/$id/decide', {'status': status});