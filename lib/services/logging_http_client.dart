import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LoggingHttpClient extends http.BaseClient {
  final http.Client _inner;
  static int _requestId = 0;

  static bool kDebugMode = true;

  LoggingHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!kDebugMode) {
      return _inner.send(request);
    }

    final id = ++_requestId;
    final stopwatch = Stopwatch()..start();

    _logRequest(id, request);

    try {
      final response = await _inner.send(request);
      final bodyBytes = await response.stream.toBytes();
      final copied = http.StreamedResponse(
        Stream.value(bodyBytes),
        response.statusCode,
        contentLength: bodyBytes.length,
        request: response.request,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
      );
      stopwatch.stop();
      _logResponse(id, request, copied, stopwatch.elapsed, bodyBytes);
      return copied;
    } catch (error, stackTrace) {
      stopwatch.stop();
      _logError(id, request, error, stackTrace, stopwatch.elapsed);
      rethrow;
    }
  }

  void _logRequest(int id, http.BaseRequest request) {
    final buffer = StringBuffer();
    buffer.writeln('════════════════════════════════════════════════════════════════════════');
    buffer.writeln('📤 [REQUEST] #$id');
    buffer.writeln('${request.method} ${request.url}');

    if (request.url.queryParameters.isNotEmpty) {
      buffer.writeln('Query: ${jsonEncode(request.url.queryParameters)}');
    }

    buffer.writeln('Headers: ${jsonEncode(_sanitizeHeaders(request.headers))}');

    final body = _extractRequestBody(request);
    if (body.isNotEmpty) {
      buffer.writeln('Body: $body');
    }

    buffer.writeln('════════════════════════════════════════════════════════════════════════');
    debugPrint(buffer.toString());
  }

  void _logResponse(int id, http.BaseRequest request, http.StreamedResponse response, Duration duration, List<int> bodyBytes) {
    final buffer = StringBuffer();
    buffer.writeln('════════════════════════════════════════════════════════════════════════');
    buffer.writeln('✅ [RESPONSE] #$id');
    buffer.writeln('${response.statusCode} ${request.method} ${request.url}');
    buffer.writeln('Duration: ${duration.inMilliseconds}ms');
    buffer.writeln('Headers: ${jsonEncode(_sanitizeHeaders(response.headers))}');

    final body = _extractResponseBody(bodyBytes, response.headers);
    if (body.isNotEmpty) {
      buffer.writeln('Response: $body');
    }

    buffer.writeln('════════════════════════════════════════════════════════════════════════');
    debugPrint(buffer.toString());
  }

  void _logError(int id, http.BaseRequest request, Object error, StackTrace stackTrace, Duration duration) {
    final buffer = StringBuffer();
    buffer.writeln('════════════════════════════════════════════════════════════════════════');
    buffer.writeln('❌ [ERROR] #$id');
    buffer.writeln('${request.method} ${request.url}');
    buffer.writeln('Duration: ${duration.inMilliseconds}ms');
    buffer.writeln('Error: $error');
    buffer.writeln('Stacktrace: $stackTrace');
    if (request is http.Request) {
      final body = _extractRequestBody(request);
      if (body.isNotEmpty) {
        buffer.writeln('Request Body: $body');
      }
    }
    buffer.writeln('════════════════════════════════════════════════════════════════════════');
    debugPrint(buffer.toString());
  }

  String _extractRequestBody(http.BaseRequest request) {
    if (request is http.Request) {
      if (request.body.isEmpty) return '';
      return _sanitizeBody(request.body);
    }

    if (request is http.MultipartRequest) {
      final parts = <String>[];
      if (request.fields.isNotEmpty) {
        parts.add('Fields: ${jsonEncode(_sanitizeBodyMap(request.fields))}');
      }
      if (request.files.isNotEmpty) {
        parts.add('Files: ${request.files.map((file) => file.filename).toList()}');
      }
      return parts.join(' | ');
    }

    return '';
  }

  String _extractResponseBody(List<int> bodyBytes, Map<String, String> headers) {
    if (bodyBytes.isEmpty) return '';

    try {
      final content = utf8.decode(bodyBytes);
      if (_looksLikeJson(headers)) {
        final jsonBody = jsonDecode(content);
        return _prettyPrintJson(_maskSensitiveJson(jsonBody));
      }
      return content;
    } catch (_) {
      return utf8.decode(bodyBytes, allowMalformed: true);
    }
  }

  bool _looksLikeJson(Map<String, String> headers) {
    final contentType = headers.entries
        .firstWhere((entry) => entry.key.toLowerCase() == 'content-type', orElse: () => const MapEntry('', ''))
        .value
        .toLowerCase();
    return contentType.contains('application/json') || contentType.contains('application/ld+json');
  }

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    return headers.map((key, value) => MapEntry(key, _sanitizeHeaderValue(key, value)));
  }

  String _sanitizeHeaderValue(String key, String value) {
    final lower = key.toLowerCase();
    if (lower.contains('authorization') || lower.contains('token') || lower.contains('secret')) {
      return _maskValue(value);
    }
    return value;
  }

  String _sanitizeBody(String body) {
    try {
      final jsonBody = jsonDecode(body);
      return _prettyPrintJson(_maskSensitiveJson(jsonBody));
    } catch (_) {
      return body;
    }
  }

  Map<String, dynamic> _sanitizeBodyMap(Map<String, String> body) {
    return body.map((key, value) => MapEntry(key, _isSensitiveKey(key) ? _maskValue(value) : value));
  }

  dynamic _maskSensitiveJson(dynamic value) {
    if (value is Map) {
      return value.map((key, innerValue) => MapEntry(
            key,
            _isSensitiveKey(key) ? _maskValue(innerValue.toString()) : _maskSensitiveJson(innerValue),
          ));
    }
    if (value is List) {
      return value.map(_maskSensitiveJson).toList();
    }
    return value;
  }

  bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('password') || lower.contains('token') || lower.contains('secret') || lower.contains('refresh');
  }

  String _maskValue(String value) {
    if (value.isEmpty) return value;
    final prefix = value.split(' ').first.toLowerCase() == 'bearer' ? 'Bearer ' : '';
    final token = prefix.isEmpty ? value : value.substring(prefix.length);
    if (token.length <= 10) {
      return '$prefix${token.replaceAll(RegExp('.'), '*')}';
    }
    final start = token.substring(0, 8);
    final end = token.substring(token.length - 4);
    return '$prefix$start...$end';
  }

  String _prettyPrintJson(dynamic jsonObject) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonObject);
    } catch (_) {
      return jsonEncode(jsonObject);
    }
  }
}
