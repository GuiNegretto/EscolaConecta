import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/logging_http_client.dart';
import '../utils/constants.dart';
import '../services/auth_provider.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthExpiredException extends ApiException {
  const AuthExpiredException() : super('Sessão expirada', statusCode: 401);
}

// Parse JSON in a background isolate to avoid blocking the UI thread.
dynamic _parseJson(String text) {
  if (text.trim().isEmpty) return {};
  return jsonDecode(text);
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  bool _tokenLoaded = false;
  final http.Client _client = LoggingHttpClient();

  // ── Auth helpers ──────────────────────────────────────────────────────────

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _tokenLoaded = true;
  }

  Future<void> _ensureTokenLoaded() async {
    if (!_tokenLoaded) {
      await loadToken();
    }
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

  Map<String, String> get _authHeaders => {
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── Generic HTTP ──────────────────────────────────────────────────────────

  Future<dynamic> _get(String path) async {
    await _ensureTokenLoaded();
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final res = await _client.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    return await _handleResponse(res);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    await _ensureTokenLoaded();
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final res = await _client
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return await _handleResponse(res);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    await _ensureTokenLoaded();
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final res = await _client
        .put(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return await _handleResponse(res);
  }

  Future<dynamic> _delete(String path) async {
    await _ensureTokenLoaded();
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final res = await _client
        .delete(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    return await _handleResponse(res);
  }

  Future<dynamic> _handleResponse(http.Response res) async {
    final body = utf8.decode(res.bodyBytes);

    // Only attempt to process body for success codes
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body.isEmpty) return {};
      try {
        final parsed = await compute(_parseJson, body);
        if (parsed == null) return {};

        if (parsed is Map<String, dynamic> && parsed.containsKey('success') && parsed.containsKey('data')) {
          final data = parsed['data'];
          if (data == null) return {};
          return data;
        }

        // If parsed is a Map or List, return as-is. Otherwise, return parsed.
        return parsed;
      } catch (e) {
        throw ApiException('Erro ao processar resposta: ${e.toString()}', statusCode: res.statusCode);
      }
    }

    // Handle unauthorized separately
    if (res.statusCode == 401) {
      clearToken();
      AuthProvider.onSessionExpired?.call();
      throw AuthExpiredException();
    }

    // For error responses try to parse a message, but don't crash if parsing fails
    try {
      final parsed = await compute(_parseJson, body);
      if (parsed is Map && parsed['message'] != null) {
        throw ApiException(parsed['message'].toString(), statusCode: res.statusCode);
      }
    } catch (_) {
      // ignore parsing errors for error bodies
    }

    throw ApiException('Erro desconhecido', statusCode: res.statusCode);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<User> login(String email, String password, UserRole role, {bool remember = false}) async {
    final data = await _post(AppConstants.loginEndpoint, {
      'email': email,
      'password': password,
    });
    final user = User.fromJson(data);
    if (user.token != null) {
      if (remember) {
        await saveToken(user.token!);
      } else {
        _token = user.token;
      }
    }
    // Persist user data only if remember
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setString('user_data', jsonEncode(data));
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.setBool('remember_me', false);
    }
    return user;
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _post(AppConstants.changePasswordEndpoint, {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> logout() async => clearToken();

  Future<User?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    if (!remember) return null;
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

  Future<List<Message>> getMessages() async {
    final data = await _get(AppConstants.messagesEndpoint);
    final list = (data is List) ? data : <dynamic>[];
    return list.map((e) => Message.fromJson(e)).toList();
  }

  Future<List<Message>> getAdminMessages({String? type, String? className}) async {
    final queryParameters = <String, String>{};
    if (type != null && type.isNotEmpty) queryParameters['type'] = type;
    if (className != null && className.isNotEmpty) queryParameters['class'] = className;

    final path = queryParameters.isNotEmpty
        ? '${AppConstants.adminMessagesEndpoint}?${Uri(queryParameters: queryParameters).query}'
        : AppConstants.adminMessagesEndpoint;

    final data = await _get(path);
    final list = (data is List) ? data : <dynamic>[];
    return list.map((e) => Message.fromJson(e)).toList();
  }

  Future<Message> getMessage(String id) async {
    final data = await _get('${AppConstants.messagesEndpoint}/$id');
    return Message.fromJson(data);
  }

  Future<Message> getAdminMessage(String id) async {
    final data = await _get('${AppConstants.adminMessagesEndpoint}/$id');
    return Message.fromJson(data);
  }

  Future<void> sendMessage(SendMessageRequest req, {List<String>? filePaths}) async {
    await _ensureTokenLoaded();
    final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.sendMessageEndpoint}');
    final reqMultipart = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..fields['title'] = req.title
      ..fields['body'] = req.content
      ..fields['type'] = req.type
      ..fields['is_draft'] = req.isDraft ? '1' : '0';

    if (req.targetClass != null) {
      final parts = req.targetClass!.split(' - ');
      if (parts.length == 2) {
        reqMultipart.fields['grade'] = parts[0];
        reqMultipart.fields['class'] = parts[1];
      }
    }

    if (req.targetParentId != null) {
      reqMultipart.fields['guardian_ids[]'] = req.targetParentId!;
    }

    if (filePaths != null) {
      for (final path in filePaths) {
        reqMultipart.files.add(await http.MultipartFile.fromPath('files[]', path));
      }
    }

    final streamed = await _client.send(reqMultipart);
    final res = await http.Response.fromStream(streamed);
    await _handleResponse(res);
  }

  Future<Message> createMessage(SendMessageRequest req, {List<String>? filePaths}) async {
    await _ensureTokenLoaded();
    // If there are files, use multipart; otherwise send JSON
    if (filePaths != null && filePaths.isNotEmpty) {
      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.adminMessagesEndpoint}');
      final reqMultipart = http.MultipartRequest('POST', uri)
        ..headers.addAll(_authHeaders)
        ..headers.remove('Content-Type'); // Remova SEMPRE o Content-Type

        reqMultipart.fields['title'] = req.title;
        reqMultipart.fields['body'] = req.content ?? '';
        reqMultipart.fields['type'] = req.type;
        reqMultipart.fields['is_draft'] = req.isDraft ? '1' : '0';

      for (final path in filePaths) {
        reqMultipart.files.add(await http.MultipartFile.fromPath('files[]', path));
      }

      final streamed = await _client.send(reqMultipart);
      final res = await http.Response.fromStream(streamed);
      final data = await _handleResponse(res);
      return Message.fromJson(data as Map<String, dynamic>);
    }

    final data = await _post(AppConstants.adminMessagesEndpoint, req.toJson());
    return Message.fromJson(data as Map<String, dynamic>);
  }

  Future<Message> updateMessage(String id, SendMessageRequest req, {List<String>? filePaths}) async {
    await _ensureTokenLoaded();
    final path = '${AppConstants.adminMessagesEndpoint}/$id';
    if (filePaths != null && filePaths.isNotEmpty) {
      final uri = Uri.parse('${AppConstants.baseUrl}$path');
      final reqMultipart = http.MultipartRequest('PUT', uri)
        ..headers.addAll(_authHeaders)
        ..fields.addAll(req.toJson().map((k, v) => MapEntry(k, v is List ? jsonEncode(v) : v.toString())));

      for (final path in filePaths) {
        reqMultipart.files.add(await http.MultipartFile.fromPath('files[]', path));
      }

      final streamed = await _client.send(reqMultipart);
      final res = await http.Response.fromStream(streamed);
      final data = await _handleResponse(res);
      return Message.fromJson(data as Map<String, dynamic>);
    }

    final data = await _put(path, req.toJson());
    return Message.fromJson(data as Map<String, dynamic>);
  }

  Future<void> sendDraft(String id) async {
    await _ensureTokenLoaded();
    final path = '${AppConstants.adminMessagesEndpoint}/$id/send';
    await _put(path, {});
  }

  // ── Students ──────────────────────────────────────────────────────────────

  Future<List<Student>> getStudents({String? grade, String? className}) async {
    final queryParameters = <String, String>{};
    if (grade != null && grade.isNotEmpty) queryParameters['grade'] = grade;
    if (className != null && className.isNotEmpty) queryParameters['class'] = className;
    final path = queryParameters.isNotEmpty
        ? '${AppConstants.studentsEndpoint}?${Uri(queryParameters: queryParameters).query}'
        : AppConstants.studentsEndpoint;

    final data = await _get(path);
    final list = (data is List) ? data : <dynamic>[];
    return list.map((e) => Student.fromJson(e)).toList();
  }

  Future<Student> createStudent(Student student) async {
    final data = await _post(AppConstants.studentsEndpoint, student.toJson());
    return Student.fromJson(data);
  }

  Future<Student> updateStudent(String id, Student student) async {
    final data = await _put('${AppConstants.studentsEndpoint}/$id', student.toJson());
    return Student.fromJson(data);
  }

  Future<void> deleteStudent(String id) async {
    await _delete('${AppConstants.studentsEndpoint}/$id');
  }

  // ── Parents ───────────────────────────────────────────────────────────────

  Future<List<Parent>> listParents() async {
    final data = await _get(AppConstants.parentsEndpoint);
    final list = (data is List) ? data : <dynamic>[];
    return list.map((e) => Parent.fromJson(e)).toList();
  }

  Future<Parent> createParent(Parent parent) async {
    final data = await _post(AppConstants.parentsEndpoint, parent.toJson());
    return Parent.fromJson(data);
  }

  Future<Parent> updateParent(String id, Map<String, dynamic> updates) async {
    final data = await _put('${AppConstants.parentsEndpoint}/$id', updates);
    return Parent.fromJson(data);
  }

  Future<void> deleteParent(String id) async {
    await _delete('${AppConstants.parentsEndpoint}/$id');
  }

  // ── Dashboard stats (admin) ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final data = await _get('/dashboard/stats');
    return (data is Map<String, dynamic>) ? data : <String, dynamic>{};
  }

  // ── Student-Parent Links (Vínculos) ─────────────────────────────────────────

  Future<List<StudentParentLink>> getStudentParentLinks({String? search}) async {
    // Buscar todos os alunos
    final students = await getStudents();

    // Buscar todos os responsáveis
    final parents = await listParents();

    // Criar mapa de responsáveis por ID para busca rápida
    final parentsMap = {for (final p in parents) p.id: p};

    // Combinar alunos com seus responsáveis
    final links = students.map((student) {
      final studentParents = parents
          .where((parent) => parent.studentIds.contains(student.id))
          .toList();

      return StudentParentLink(
        student: student,
        parents: studentParents,
      );
    }).toList();

    // Aplicar filtro de busca se fornecido
    if (search != null && search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      return links.where((link) {
        return link.student.name.toLowerCase().contains(searchLower) ||
               link.student.fullClass.toLowerCase().contains(searchLower) ||
               link.parents.any((p) => p.name.toLowerCase().contains(searchLower));
      }).toList();
    }

    return links;
  }

  Future<void> linkStudentParent(String studentId, String parentId) async {
    // Buscar o responsável atual
    final parent = await _get('${AppConstants.parentsEndpoint}/$parentId');
    final parentObj = Parent.fromJson(parent);

    // Adicionar o studentId se não estiver presente
    if (!parentObj.studentIds.contains(studentId)) {
      final updatedStudentIds = [...parentObj.studentIds.map((id) => int.parse(id)), (int.parse(studentId))];

      // Atualizar o responsável com o novo vínculo
      await updateParent(parentId, {
        'name': parentObj.name,
        'phone': parentObj.phone,
        'phone_secondary': parentObj.phoneSecondary,
        'email_secondary': parentObj.emailSecondary,
        'student_ids': updatedStudentIds,
      });
    }
  }

  Future<void> unlinkStudentParent(String studentId, String parentId) async {
    // Buscar o responsável atual
    final parent = await _get('${AppConstants.parentsEndpoint}/$parentId');
    final parentObj = Parent.fromJson(parent);

    // Remover o studentId se estiver presente
    final updatedStudentIds = parentObj.studentIds.where((id) => id != studentId).toList();

    // Atualizar o responsável removendo o vínculo
    await updateParent(parentId, {
      'name': parentObj.name,
      'phone': parentObj.phone,
      'phone_secondary': parentObj.phoneSecondary,
      'email_secondary': parentObj.emailSecondary,
      'student_ids': updatedStudentIds,
    });
  }
}