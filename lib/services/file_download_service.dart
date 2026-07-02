import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileDownloadService {
  static final FileDownloadService _instance = FileDownloadService._internal();
  factory FileDownloadService() => _instance;
  FileDownloadService._internal();

  final Dio _dio = Dio();

  /// Faz download de um arquivo com autenticação JWT
  Future<String> downloadFile(
    String url,
    String fileName, {
    Function(int, int)? onProgress,
  }) async {
    try {
      // Obter token de autenticação
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Token de autenticação não encontrado');
      }

      // Determinar diretório de destino
      Directory directory;
      if (kIsWeb) {
        throw Exception('Download direto não suportado na web');
      } else if (Platform.isAndroid) {
        // Evita permissões legadas de storage em Android 11+ salvando no espaço do app.
        directory = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        // iOS: usar diretório de documentos do app
        directory = await getApplicationDocumentsDirectory();
      } else {
        // Desktop: usar diretório de downloads
        directory = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      // Garantir nome de arquivo único
      String filePath = '${directory.path}/$fileName';
      int counter = 1;
      while (File(filePath).existsSync()) {
        final ext = fileName.contains('.') ? fileName.split('.').last : '';
        final nameWithoutExt = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;
        filePath = '${directory.path}/${nameWithoutExt}_$counter.$ext';
        counter++;
      }

      // Fazer download com autenticação
      await _dio.download(
        url,
        filePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: onProgress,
      );

      return filePath;
    } catch (e) {
      debugPrint('Erro ao baixar arquivo: $e');
      rethrow;
    }
  }

  /// Faz download temporário de um arquivo (para visualização)
  Future<String> downloadTempFile(
    String url,
    String fileName, {
    Function(int, int)? onProgress,
  }) async {
    try {
      // Obter token de autenticação
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('Token de autenticação não encontrado');
      }

      // Usar diretório temporário
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';

      // Fazer download com autenticação
      await _dio.download(
        url,
        filePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: onProgress,
      );

      return filePath;
    } catch (e) {
      debugPrint('Erro ao baixar arquivo temporário: $e');
      rethrow;
    }
  }

  /// Cancela todos os downloads em andamento
  void cancelDownloads() {
    _dio.close();
  }
}
