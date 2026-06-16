import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Represents the remote version information from version.json
class RemoteVersionInfo {
  final String version;
  final int versionCode;
  final String downloadUrl;
  final String changelog;
  final bool forceUpdate;

  RemoteVersionInfo({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  factory RemoteVersionInfo.fromJson(Map<String, dynamic> json) {
    return RemoteVersionInfo(
      version: json['version'] as String? ?? '0.0.0',
      versionCode: json['versionCode'] as int? ?? 0,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }
}

/// Handles version checking, APK downloads with progress, and installation
class UpdateService {
  UpdateService({
    required this.versionCheckUrl,
  }) : _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  final String versionCheckUrl;
  final Dio _dio;

  /// Compares two semantic versions (e.g., "1.0.0" > "0.9.5")
  /// Returns: > 0 if v1 > v2, < 0 if v1 < v2, 0 if equal
  static int compareVersions(String v1, String v2) {
    try {
      final parts1 = v1.split('.').map(int.parse).toList();
      final parts2 = v2.split('.').map(int.parse).toList();

      // Pad with zeros
      while (parts1.length < 3) parts1.add(0);
      while (parts2.length < 3) parts2.add(0);

      for (int i = 0; i < 3; i++) {
        if (parts1[i] > parts2[i]) return 1;
        if (parts1[i] < parts2[i]) return -1;
      }
      return 0;
    } catch (e) {
      debugPrint('Version comparison error: $e');
      return 0;
    }
  }

  /// Checks if remoteVersion is newer than currentVersion
  static bool isUpdateAvailable(String currentVersion, String remoteVersion) {
    return compareVersions(remoteVersion, currentVersion) > 0;
  }

  /// Fetches version.json from the remote server
  Future<RemoteVersionInfo> checkForUpdates() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(versionCheckUrl);
      if (response.statusCode == 200 && response.data != null) {
        return RemoteVersionInfo.fromJson(response.data!);
      }
      throw Exception('Failed to fetch version info: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Network error checking updates: ${e.message}');
    } catch (e) {
      throw Exception('Error checking updates: $e');
    }
  }

  /// Downloads APK with progress tracking
  /// [onProgress] callback receives progress as decimal (0.0 to 1.0)
  /// Returns path to downloaded APK file
  Future<String> downloadAPK({
    required String downloadUrl,
    required ValueChanged<double> onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'escola_conecta_update.apk';
      final savePath = '${tempDir.path}/$fileName';

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );

      debugPrint('APK downloaded to: $savePath');
      return savePath;
    } on DioException catch (e) {
      throw Exception('Download failed: ${e.message}');
    } catch (e) {
      throw Exception('Error downloading APK: $e');
    }
  }

  /// Installs APK using open_filex
  /// This requires REQUEST_INSTALL_PACKAGES permission and FileProvider setup
  Future<void> installAPK(String apkPath) async {
    try {
      if (!File(apkPath).existsSync()) {
        throw Exception('APK file not found: $apkPath');
      }

      // Use open_filex to trigger the Android installer
      final result = await OpenFilex.open(apkPath, type: 'application/vnd.android.package-archive');
      debugPrint('Open file result: ${result.type}');

      if (result.type != ResultType.done) {
        throw Exception('Failed to open APK installer');
      }
    } catch (e) {
      throw Exception('Error installing APK: $e');
    }
  }

  /// Cleans up old APK files from temp directory
  Future<void> cleanupOldAPKs() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final apkPattern = RegExp(r'escola_conecta_update.*\.apk');

      final files = tempDir.listSync();
      for (var file in files) {
        if (file is File && apkPattern.hasMatch(file.path)) {
          try {
            file.deleteSync();
            debugPrint('Deleted old APK: ${file.path}');
          } catch (e) {
            debugPrint('Failed to delete old APK: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up APKs: $e');
    }
  }
}
