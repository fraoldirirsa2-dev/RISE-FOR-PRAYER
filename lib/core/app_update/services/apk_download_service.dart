import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rise_for_prayer/core/app_update/models/app_update_info.dart';

typedef DownloadProgressCallback = void Function(double progress, int bytesReceived, int totalBytes);

/// Service responsible for downloading APK release assets securely,
/// validating file integrity and checksums, and launching Android package installation.
class ApkDownloadService {
  ApkDownloadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const MethodChannel _installerChannel =
      MethodChannel('com.example.thelot_2/package_installer');

  /// Downloads the APK with progress reporting to an app-specific cache directory.
  Future<File> downloadApk({
    required ReleaseAssetInfo asset,
    DownloadProgressCallback? onProgress,
    void Function(String message)? onStatus,
  }) async {
    onStatus?.call('Preparing download...');
    final tempDir = await getTemporaryDirectory();
    final apkDir = Directory('${tempDir.path}/app_updates');
    if (!await apkDir.exists()) {
      await apkDir.create(recursive: true);
    }

    // Clean previous updates to save device storage
    try {
      final oldFiles = apkDir.listSync();
      for (final file in oldFiles) {
        if (file is File && file.path.endsWith('.apk')) {
          file.deleteSync();
        }
      }
    } catch (_) {}

    final safeName = asset.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
    final targetFile = File('${apkDir.path}/$safeName');
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final request = http.Request('GET', Uri.parse(asset.downloadUrl));
    request.headers['Accept'] = 'application/octet-stream';
    request.headers['User-Agent'] = 'RiseForPrayer-AppUpdate/1.0';

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw ApkDownloadException('Failed to download APK: HTTP ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? asset.sizeInBytes;
    int receivedBytes = 0;

    final sink = targetFile.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          final progress = (receivedBytes / contentLength).clamp(0.0, 1.0);
          onProgress(progress, receivedBytes, contentLength);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    // Verify file is valid and non-empty
    if (!await targetFile.exists() || await targetFile.length() == 0) {
      throw const ApkDownloadException('Downloaded APK file is empty or corrupted.');
    }

    // Verify SHA-256 digest if available
    if (asset.sha256Digest != null && asset.sha256Digest!.isNotEmpty) {
      onStatus?.call('Verifying package integrity...');
      final bytes = await targetFile.readAsBytes();
      final calculatedHash = sha256.convert(bytes).toString().toLowerCase();
      final expectedHash = asset.sha256Digest!.trim().toLowerCase();

      if (calculatedHash != expectedHash) {
        await targetFile.delete();
        throw ApkDownloadException(
          'Checksum mismatch! Downloaded package may be tampered with or corrupted.\n'
          'Expected: $expectedHash\nGot: $calculatedHash',
        );
      }
    }

    return targetFile;
  }

  /// Checks if the app currently has permission to install unknown apps on Android 8.0+.
  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? true;
    } on PlatformException {
      return true;
    }
  }

  /// Opens the system Settings page where the user can enable unknown sources permission.
  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _installerChannel.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// Launches the native Android package installer with the downloaded APK FileProvider URI.
  Future<bool> installApk(File apkFile) async {
    if (!Platform.isAndroid) {
      throw const ApkDownloadException('APK installation is only supported on Android devices.');
    }
    if (!await apkFile.exists()) {
      throw ApkDownloadException('File does not exist: ${apkFile.path}');
    }

    try {
      final res = await _installerChannel.invokeMethod<bool>('installApk', {
        'filePath': apkFile.path,
      });
      return res ?? false;
    } on PlatformException catch (e) {
      throw ApkDownloadException('Android package installer error: ${e.message}');
    }
  }
}

class ApkDownloadException implements Exception {
  const ApkDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}
