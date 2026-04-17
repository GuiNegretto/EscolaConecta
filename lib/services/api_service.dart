import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  // ── Auth helpers ──────────────────────────────────────────────────────────

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── Generic HTTP ──────────────────────────────────────────────────────────

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(res);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _handleResponse(res);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final res = await http
        .put(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _handleResponse(res);
  }

  Future<dynamic> _delete(String path) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final res = await http
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(res);
  }

  dynamic _handleResponse(http.Response res) {
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body.isEmpty) return {};
      return jsonDecode(body);
    }
    final json = jsonDecode(body);
    throw ApiException(
      json['message'] ?? 'Erro desconhecido',
      statusCode: res.statusCode,
    );
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<User> login(String email, String password, UserRole role) async {
    final data = await _post(AppConstants.loginEndpoint, {
      'email': email,
      'password': password,
      'role': role == UserRole.admin ? 'admin' : 'parent',
    });
    final user = User.fromJson(data);
    if (user.token != null) await saveToken(user.token!);
    // Persist user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(data));
    return user;
  }

  Future<void> logout() async => clearToken();

  Future<User?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_data');
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<User> getProfile() async {
    final data = await _get(AppConstants.profileEndpoint);
    return User.fromJson(data);
  }

  Future<User> updateProfile(Map<String, dynamic> updates) async {
    final data = await _put(AppConstants.profileEndpoint, updates);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(data));
    return User.fromJson(data);
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<Message>> getMessages({String? filter}) async {
    final query = filter != null ? '?type=$filter' : '';
    final data = await _get('${AppConstants.messagesEndpoint}$query');
    return (data as List).map((e) => Message.fromJson(e)).toList();
  }

  Future<Message> getMessage(String id) async {
    final data = await _get('${AppConstants.messagesEndpoint}/$id');
    return Message.fromJson(data);
  }

  Future<void> sendMessage(SendMessageRequest req) async {
    await _post(AppConstants.sendMessageEndpoint, req.toJson());
  }

  Future<void> markMessageRead(String id) async {
    await _put('${AppConstants.messagesEndpoint}/$id/read', {});
  }

  // ── Students ──────────────────────────────────────────────────────────────

  Future<List<Student>> getStudents() async {
    final data = await _get(AppConstants.studentsEndpoint);
    return (data as List).map((e) => Student.fromJson(e)).toList();
  }

  Future<Student> createStudent(Student student) async {
    final data = await _post(AppConstants.studentsEndpoint, student.toJson());
    return Student.fromJson(data);
  }

  Future<void> deleteStudent(String id) async {
    await _delete('${AppConstants.studentsEndpoint}/$id');
  }

  // ── Parents ───────────────────────────────────────────────────────────────

  Future<List<Parent>> getParents() async {
    final data = await _get(AppConstants.parentsEndpoint);
    return (data as List).map((e) => Parent.fromJson(e)).toList();
  }

  Future<Parent> createParent(Parent parent) async {
    final data = await _post(AppConstants.parentsEndpoint, parent.toJson());
    return Parent.fromJson(data);
  }

  Future<void> deleteParent(String id) async {
    await _delete('${AppConstants.parentsEndpoint}/$id');
  }

  // ── Dashboard stats (admin) ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    return await _get('/dashboard/stats');
  }

  // ── Import spreadsheet ────────────────────────────────────────────────────

  Future<void> importSpreadsheet(String filePath) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/import');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll({if (_token != null) 'Authorization': 'Bearer $_token'})
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException('Falha ao importar planilha', statusCode: streamed.statusCode);
    }
  }
}