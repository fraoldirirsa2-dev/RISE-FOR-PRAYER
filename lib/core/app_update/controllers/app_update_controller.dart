import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rise_for_prayer/core/app_update/models/app_update_info.dart';
import 'package:rise_for_prayer/core/app_update/services/apk_download_service.dart';
import 'package:rise_for_prayer/core/app_update/services/github_update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  updateAvailable,
  noUpdateAvailable,
  downloading,
  readyToInstall,
  error,
}

/// Controller managing GitHub update checks, persistent recheck intervals,
/// dismissed versions, and APK installation flow.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    GitHubUpdateService? updateService,
    ApkDownloadService? downloadService,
  })  : _updateService = updateService ?? GitHubUpdateService(),
        _downloadService = downloadService ?? ApkDownloadService();

  final GitHubUpdateService _updateService;
  final ApkDownloadService _downloadService;

  static const String _lastCheckTimeKey = 'app_update_last_check_ms';
  static const String _dismissedTagKey = 'app_update_dismissed_tag';

  UpdateStatus _status = UpdateStatus.idle;
  AppUpdateInfo? _updateInfo;
  String? _errorMessage;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  File? _downloadedApk;

  UpdateStatus get status => _status;
  AppUpdateInfo? get updateInfo => _updateInfo;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  String get statusMessage => _statusMessage;
  File? get downloadedApk => _downloadedApk;

  /// Checks for update with a throttling interval (e.g. 24 hours) for startup checks.
  /// If [force] is true, checks immediately (e.g. from Settings "Check for Updates").
  Future<AppUpdateInfo?> checkForUpdate({
    bool force = false,
    Duration checkInterval = const Duration(hours: 24),
  }) async {
    if (_status == UpdateStatus.checking || _status == UpdateStatus.downloading) {
      return _updateInfo;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastCheckMs = prefs.getInt(_lastCheckTimeKey) ?? 0;
    final now = DateTime.now();

    if (!force && lastCheckMs > 0) {
      final elapsed = now.difference(DateTime.fromMillisecondsSinceEpoch(lastCheckMs));
      if (elapsed < checkInterval) {
        // Throttled: do not spam GitHub API
        return _updateInfo;
      }
    }

    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final info = await _updateService.checkForUpdate();
      await prefs.setInt(_lastCheckTimeKey, now.millisecondsSinceEpoch);

      final dismissedTag = prefs.getString(_dismissedTagKey);
      final isDismissed = dismissedTag == info.releaseTag && !info.isMandatory;

      _updateInfo = info;
      if (info.isUpdateAvailable && !isDismissed) {
        _status = UpdateStatus.updateAvailable;
      } else {
        _status = UpdateStatus.noUpdateAvailable;
      }
      notifyListeners();
      return info;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = UpdateStatus.error;
      notifyListeners();
      return null;
    }
  }

  /// User dismisses optional update; remembers tag so user isn't annoyed repeatedly.
  Future<void> dismissUpdate() async {
    if (_updateInfo != null && !_updateInfo!.isMandatory) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedTagKey, _updateInfo!.releaseTag);
    }
    _status = UpdateStatus.idle;
    notifyListeners();
  }

  /// Downloads the APK and triggers package installation.
  Future<void> downloadAndInstall() async {
    final asset = _updateInfo?.apkAsset;
    if (asset == null) {
      _errorMessage = 'No valid APK available for download.';
      _status = UpdateStatus.error;
      notifyListeners();
      return;
    }

    _status = UpdateStatus.downloading;
    _downloadProgress = 0.0;
    _errorMessage = null;
    _statusMessage = 'Starting download...';
    notifyListeners();

    try {
      final file = await _downloadService.downloadApk(
        asset: asset,
        onProgress: (progress, received, total) {
          _downloadProgress = progress;
          final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
          _statusMessage = 'Downloading: $mbReceived MB / $mbTotal MB (${(progress * 100).toInt()}%)';
          notifyListeners();
        },
        onStatus: (msg) {
          _statusMessage = msg;
          notifyListeners();
        },
      );

      _downloadedApk = file;
      _status = UpdateStatus.readyToInstall;
      _statusMessage = 'Download complete. Opening installer...';
      notifyListeners();

      // Launch package installer
      await _downloadService.installApk(file);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _status = UpdateStatus.error;
      notifyListeners();
    }
  }

  /// Checks if Android allows installing unknown apps and guides the user.
  Future<bool> canRequestPackageInstalls() =>
      _downloadService.canRequestPackageInstalls();

  Future<void> openInstallPermissionSettings() =>
      _downloadService.openInstallPermissionSettings();

  void reset() {
    _status = UpdateStatus.idle;
    _errorMessage = null;
    _downloadProgress = 0.0;
    notifyListeners();
  }
}
