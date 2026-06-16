import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'update_service.dart';

class UpdateProvider extends ChangeNotifier {
  UpdateProvider({
    required this.versionCheckUrl,
  }) : _updateService = UpdateService(versionCheckUrl: versionCheckUrl);

  final String versionCheckUrl;
  final UpdateService _updateService;

  // State management
  String _currentVersion = '0.0.0';
  String _latestVersion = '0.0.0';
  String _downloadUrl = '';
  String _changelog = '';
  bool _updateAvailable = false;
  bool _downloading = false;
  double _downloadProgress = 0.0;
  bool _forceUpdate = false;
  String? _error;

  // Getters
  String get currentVersion => _currentVersion;
  String get latestVersion => _latestVersion;
  String get downloadUrl => _downloadUrl;
  String get changelog => _changelog;
  bool get updateAvailable => _updateAvailable;
  bool get downloading => _downloading;
  double get downloadProgress => _downloadProgress;
  bool get forceUpdate => _forceUpdate;
  String? get error => _error;

  /// Initialize provider by loading current version
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
      notifyListeners();
      debugPrint('Current app version: $_currentVersion');
    } catch (e) {
      debugPrint('Error getting package info: $e');
      _error = 'Could not retrieve app version';
      notifyListeners();
    }
  }

  /// Check for updates (can be called on startup or manually)
  /// [showDialog] - if true, returns whether update was found or error occurred
  Future<bool> checkForUpdates({bool silent = false}) async {
    try {
      _error = null;
      final remoteInfo = await _updateService.checkForUpdates();

      _latestVersion = remoteInfo.version;
      _downloadUrl = remoteInfo.downloadUrl;
      _changelog = remoteInfo.changelog;
      _forceUpdate = remoteInfo.forceUpdate;

      final isNewer = UpdateService.isUpdateAvailable(_currentVersion, _latestVersion);
      _updateAvailable = isNewer;

      if (!silent) {
        debugPrint(
          'Update check: current=$_currentVersion, latest=$_latestVersion, '
          'available=$_updateAvailable, force=$_forceUpdate',
        );
      }

      notifyListeners();
      return _updateAvailable;
    } catch (e) {
      _error = e.toString();
      if (!silent) {
        debugPrint('Error checking updates: $e');
      }
      notifyListeners();
      return false;
    }
  }

  /// Downloads and installs APK
  Future<bool> downloadAndInstall(String downloadUrl) async {
    if (_downloading) return false;

    try {
      _downloading = true;
      _downloadProgress = 0.0;
      _error = null;
      notifyListeners();

      // Download APK
      final apkPath = await _updateService.downloadAPK(
        downloadUrl: downloadUrl,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      // Install APK
      await _updateService.installAPK(apkPath);

      // Cleanup
      await _updateService.cleanupOldAPKs();

      _downloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _downloading = false;
      debugPrint('Error downloading/installing APK: $e');
      notifyListeners();
      return false;
    }
  }

  /// Resets download state (useful after canceling)
  void resetDownloadState() {
    _downloading = false;
    _downloadProgress = 0.0;
    _error = null;
    notifyListeners();
  }

  /// Resets all update state
  void resetUpdateState() {
    _updateAvailable = false;
    _latestVersion = _currentVersion;
    _downloadUrl = '';
    _changelog = '';
    _forceUpdate = false;
    _downloading = false;
    _downloadProgress = 0.0;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
