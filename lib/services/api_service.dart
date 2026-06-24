import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/logging_http_client.dart';
import '../utils/constants.dart';
import '../utils/api_routes.dart';
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
    await prefs.remove('remember_me');
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
      // Clear stored session data when remember is unchecked
      await prefs.remove('user_data');
      await prefs.remove('remember_me');
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

  Future<List<Message>> getAdminMessages({String? type, String? className, bool? isDraft}) async {
    final queryParameters = <String, String>{};
    if (type != null && type.isNotEmpty) queryParameters['type'] = type;
    if (className != null && className.isNotEmpty) queryParameters['class'] = className;
    if (isDraft != null) queryParameters['is_draft'] = isDraft ? '1' : '0';

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

  Future<void> markMessageAsRead(String messageId) async {
    await _put('${AppConstants.messagesEndpoint}/$messageId/read', {});
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
    final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.adminMessagesEndpoint}');
    final reqMultipart = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..headers.remove('Content-Type'); // Remova SEMPRE o Content-Type

    // Add required fields
    reqMultipart.fields['title'] = req.title;
    reqMultipart.fields['body'] = req.content;
    reqMultipart.fields['type'] = req.type;
    reqMultipart.fields['is_draft'] = req.isDraft ? '1' : '0';

    // Handle targetClass: split "3º Ano - A" into grade and class
    if (req.targetClass != null && req.targetClass!.isNotEmpty) {
      final parts = req.targetClass!.split(' - ');
      if (parts.length == 2) {
        reqMultipart.fields['grade'] = parts[0];
        reqMultipart.fields['class'] = parts[1];
      } else {
        // Fallback: treat entire string as class
        reqMultipart.fields['class'] = req.targetClass!;
      }
    }

    // Handle targetParentId for individual messages
    if (req.targetParentId != null && req.targetParentId!.isNotEmpty) {
      reqMultipart.fields['guardian_ids[]'] = req.targetParentId!;
    }

    // Add scheduled_at if present
    if (req.scheduledAt != null) {
      reqMultipart.fields['scheduled_at'] = req.scheduledAt!.toUtc().toIso8601String();
    }

    // Add files if provided
    if (filePaths != null && filePaths.isNotEmpty) {
      for (final path in filePaths) {
        reqMultipart.files.add(await http.MultipartFile.fromPath('files[]', path));
      }
    }

    final streamed = await _client.send(reqMultipart);
    final res = await http.Response.fromStream(streamed);
    final data = await _handleResponse(res);
    return Message.fromJson(data as Map<String, dynamic>);
  }

  Future<Message> updateMessage(String id, SendMessageRequest req, {List<String>? filePaths}) async {
    await _ensureTokenLoaded();
    final path = '${AppConstants.adminMessagesEndpoint}/$id';
    
    // Always use multipart for consistency with createMessage
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final reqMultipart = http.MultipartRequest('PUT', uri)
      ..headers.addAll(_authHeaders)
      ..headers.remove('Content-Type');

    // Add required fields
    reqMultipart.fields['title'] = req.title;
    reqMultipart.fields['body'] = req.content;
    reqMultipart.fields['type'] = req.type;
    reqMultipart.fields['is_draft'] = req.isDraft ? '1' : '0';

    // Handle targetClass: split "3º Ano - A" into grade and class
    if (req.targetClass != null && req.targetClass!.isNotEmpty) {
      final parts = req.targetClass!.split(' - ');
      if (parts.length == 2) {
        reqMultipart.fields['grade'] = parts[0];
        reqMultipart.fields['class'] = parts[1];
      } else {
        // Fallback: treat entire string as class
        reqMultipart.fields['class'] = req.targetClass!;
      }
    }

    // Handle targetParentId for individual messages
    if (req.targetParentId != null && req.targetParentId!.isNotEmpty) {
      reqMultipart.fields['guardian_ids[]'] = req.targetParentId!;
    }

    // Add scheduled_at if present
    if (req.scheduledAt != null) {
      reqMultipart.fields['scheduled_at'] = req.scheduledAt!.toUtc().toIso8601String();
    }

    // Add files if provided
    if (filePaths != null && filePaths.isNotEmpty) {
      for (final path in filePaths) {
        reqMultipart.files.add(await http.MultipartFile.fromPath('files[]', path));
      }
    }

    final streamed = await _client.send(reqMultipart);
    final res = await http.Response.fromStream(streamed);
    final data = await _handleResponse(res);
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
    await _post('${AppConstants.parentsEndpoint}/$parentId/links', {
      'student_id': int.parse(studentId),
    });
  }

  Future<void> unlinkStudentParent(String studentId, String parentId) async {
    await _delete('${AppConstants.parentsEndpoint}/$parentId/links/$studentId');
  }

  // ── CSV Import ────────────────────────────────────────────────────────────

  /// Upload CSV file for bulk import of students and guardians
  ///
  /// Expected endpoint: POST /admin/import/students
  /// Returns ImportResult with statistics and errors
  Future<ImportResult> importStudentsFromCsv(String filePath) async {
    await _ensureTokenLoaded();
    final uri = Uri.parse('${AppConstants.baseUrl}${ApiRoutes.adminImportStudents}');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders)
      ..headers.remove('Content-Type'); // Let http.MultipartRequest set it

    // Add CSV file
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      debugPrint('[API] Upload CSV via path');
      debugPrint('[API] Endpoint: POST ${AppConstants.baseUrl}/admin/import/students');
      debugPrint('[API] Headers: $_authHeaders');
      
      final streamed = await _client.send(request).timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamed);
      
      debugPrint('[API] Response status: ${response.statusCode}');
      debugPrint('[API] Response body: ${response.body}');
      
      final data = await _handleResponse(response);

      if (data is Map<String, dynamic>) {
        return ImportResult.fromJson(data);
      }

      // Fallback if response structure is different
      return ImportResult(
        totalProcessed: data is Map ? data['total'] ?? 0 : 0,
        totalImported: data is Map ? data['imported'] ?? 0 : 0,
        totalIgnored: data is Map ? data['ignored'] ?? 0 : 0,
        totalErrors: data is Map ? data['errors'] ?? 0 : 0,
        errors: [],
        importedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[API] Erro ao fazer upload do CSV: $e');
      throw ApiException('Erro ao fazer upload do CSV: ${e.toString()}');
    }
  }

  /// Upload CSV file from bytes (for Flutter Web compatibility)
  ///
  /// Expected endpoint: POST /admin/import/students
  /// Returns ImportResult with statistics and errors
  Future<ImportResult> importStudentsFromCsvBytes(Uint8List fileBytes) async {
    await _ensureTokenLoaded();
    final uri = Uri.parse('${AppConstants.baseUrl}${ApiRoutes.adminImportStudents}');

    debugPrint('════════════════════════════════════════════════════════════════════════');
    debugPrint('[API-CSV] =============================================================');
    debugPrint('[API-CSV] INICIANDO UPLOAD DE CSV VIA BYTES');
    debugPrint('[API-CSV] =============================================================');
    debugPrint('[API-CSV] Endpoint: POST ${AppConstants.baseUrl}/admin/import/students');
    debugPrint('[API-CSV] Token loaded: ${_token != null ? "✓ (${_token!.substring(0, 8)}...)" : "✗"}');
    debugPrint('[API-CSV] Auth Headers: $_authHeaders');
    debugPrint('[API-CSV] File size: ${fileBytes.length} bytes');

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders);

    // CRITICAL: Remove Content-Type to let multipart set it automatically
    request.headers.remove('Content-Type');
    request.headers.remove('content-type');

    debugPrint('[API-CSV] Request headers after cleanup: ${request.headers}');

    // Add CSV file from bytes
    final multipartFile = http.MultipartFile.fromBytes(
      'file',  // This MUST match the backend field name
      fileBytes,
      filename: 'import.csv',
    );

    request.files.add(multipartFile);

    debugPrint('[API-CSV] Multipart file added');
    debugPrint('[API-CSV]   Field name: file');
    debugPrint('[API-CSV]   Filename: import.csv');
    debugPrint('[API-CSV]   Size: ${fileBytes.length} bytes');
    debugPrint('[API-CSV]   Content-Type will be: ${multipartFile.contentType}');

    try {
      debugPrint('[API-CSV] Enviando requisição...');

      final streamed = await _client.send(request).timeout(const Duration(minutes: 5));
      final response = await http.Response.fromStream(streamed);

      debugPrint('[API-CSV] =============================================================');
      debugPrint('[API-CSV] RESPOSTA RECEBIDA');
      debugPrint('[API-CSV] =============================================================');
      debugPrint('[API-CSV] Status Code: ${response.statusCode}');
      debugPrint('[API-CSV] Status Text: ${response.reasonPhrase}');
      debugPrint('[API-CSV] Response Headers: ${response.headers}');
      debugPrint('[API-CSV] Response Body: ${response.body}');

      final data = await _handleResponse(response);

      if (data is Map<String, dynamic>) {
        debugPrint('[API-CSV] ✓ Parse JSON bem-sucedido');
        return ImportResult.fromJson(data);
      }

      // Fallback if response structure is different
      debugPrint('[API-CSV] ⚠ Resposta com formato diferente, usando fallback');
      return ImportResult(
        totalProcessed: data is Map ? data['total'] ?? 0 : 0,
        totalImported: data is Map ? data['imported'] ?? 0 : 0,
        totalIgnored: data is Map ? data['ignored'] ?? 0 : 0,
        totalErrors: data is Map ? data['errors'] ?? 0 : 0,
        errors: [],
        importedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      debugPrint('[API-CSV] =============================================================');
      debugPrint('[API-CSV] ✗ ERRO DURANTE UPLOAD');
      debugPrint('[API-CSV] =============================================================');
      debugPrint('[API-CSV] Error: $e');
      debugPrint('[API-CSV] StackTrace: $stackTrace');
      throw ApiException('Erro ao fazer upload do CSV: ${e.toString()}');
    }
  }
}