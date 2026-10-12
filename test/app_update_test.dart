import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rise_for_prayer/core/app_update/controllers/app_update_controller.dart';
import 'package:rise_for_prayer/core/app_update/models/app_update_info.dart';
import 'package:rise_for_prayer/core/app_update/services/github_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersion Parsing & Comparison', () {
    test('parses basic semantic versions', () {
      final v1 = AppVersion.parse('1.0.0');
      expect(v1.major, 1);
      expect(v1.minor, 0);
      expect(v1.patch, 0);
      expect(v1.buildNumber, 0);
    });

    test('parses v-prefixed and build numbers correctly', () {
      final v1 = AppVersion.parse('v1.2.3+4');
      expect(v1.major, 1);
      expect(v1.minor, 2);
      expect(v1.patch, 3);
      expect(v1.buildNumber, 4);

      final v2 = AppVersion.parse('V2.0.1');
      expect(v2.major, 2);
      expect(v2.minor, 0);
      expect(v2.patch, 1);
    });

    test('correctly orders semantic versions numerically', () {
      // 1.9.0 vs 1.10.0 (numeric check: 1.10.0 > 1.9.0)
      expect(AppVersion.parse('1.10.0') > AppVersion.parse('1.9.0'), isTrue);
      expect(AppVersion.parse('1.9.0') < AppVersion.parse('1.10.0'), isTrue);

      // Minor updates
      expect(AppVersion.parse('v1.1.0') > AppVersion.parse('1.0.0'), isTrue);
      expect(AppVersion.parse('1.0.0') == AppVersion.parse('v1.0.0'), isTrue);

      // Downgrades
      expect(AppVersion.parse('1.0.0') > AppVersion.parse('1.1.0'), isFalse);
      expect(AppVersion.parse('1.2.0') > AppVersion.parse('1.1.0'), isTrue);

      // Build numbers comparison
      expect(AppVersion.parse('1.0.0+2') > AppVersion.parse('1.0.0+1'), isTrue);
    });
  });

  group('GitHubUpdateService', () {
    test('detects update available when release contains valid APK asset', () async {
      final mockJson = jsonEncode({
        'tag_name': 'v1.1.0',
        'name': 'Release 1.1.0',
        'body': 'Bug fixes and performance improvements.',
        'published_at': '2026-10-12T12:00:00Z',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/test/app-release.apk',
            'size': 25000000,
          },
          {
            'name': 'app-release.apk.sha256',
            'browser_download_url': 'https://github.com/test/app-release.apk.sha256',
            'size': 64,
          }
        ],
      });

      final client = MockClient((request) async {
        if (request.url.path.endsWith('.sha256')) {
          return http.Response('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  app-release.apk', 200);
        }
        return http.Response(mockJson, 200);
      });

      final service = GitHubUpdateService(client: client);
      final updateInfo = await service.checkForUpdate(
        currentVersion: const AppVersion(major: 1, minor: 0, patch: 0),
      );

      expect(updateInfo.isUpdateAvailable, isTrue);
      expect(updateInfo.latestVersion.major, 1);
      expect(updateInfo.latestVersion.minor, 1);
      expect(updateInfo.apkAsset, isNotNull);
      expect(updateInfo.apkAsset!.name, 'app-release.apk');
      expect(updateInfo.apkAsset!.sizeInBytes, 25000000);
      expect(updateInfo.apkAsset!.sha256Digest, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('reports no update when installed version is equal or newer', () async {
      final mockJson = jsonEncode({
        'tag_name': 'v1.1.0',
        'name': 'Release 1.1.0',
        'body': 'Notes',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/test/app-release.apk',
            'size': 25000000,
          }
        ],
      });

      final client = MockClient((request) async => http.Response(mockJson, 200));
      final service = GitHubUpdateService(client: client);

      // Same version
      final sameInfo = await service.checkForUpdate(
        currentVersion: const AppVersion(major: 1, minor: 1, patch: 0),
      );
      expect(sameInfo.isUpdateAvailable, isFalse);

      // Newer installed version
      final newerInfo = await service.checkForUpdate(
        currentVersion: const AppVersion(major: 1, minor: 2, patch: 0),
      );
      expect(newerInfo.isUpdateAvailable, isFalse);
    });

    test('detects mandatory update flag in release notes', () async {
      final mockJson = jsonEncode({
        'tag_name': 'v2.0.0',
        'name': 'Major Security Release',
        'body': '[MANDATORY] Please update immediately.',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/test/app-release.apk',
            'size': 100,
          }
        ],
      });

      final client = MockClient((request) async => http.Response(mockJson, 200));
      final service = GitHubUpdateService(client: client);

      final info = await service.checkForUpdate(
        currentVersion: const AppVersion(major: 1, minor: 0, patch: 0),
      );
      expect(info.isUpdateAvailable, isTrue);
      expect(info.isMandatory, isTrue);
    });

    test('ignores releases with no valid APK asset', () async {
      final mockJson = jsonEncode({
        'tag_name': 'v1.5.0',
        'name': 'Source Release Only',
        'body': 'No binaries',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'source_code.zip',
            'browser_download_url': 'https://github.com/test/source.zip',
            'size': 500,
          }
        ],
      });

      final client = MockClient((request) async => http.Response(mockJson, 200));
      final service = GitHubUpdateService(client: client);

      final info = await service.checkForUpdate(
        currentVersion: const AppVersion(major: 1, minor: 0, patch: 0),
      );
      expect(info.isUpdateAvailable, isFalse);
      expect(info.apkAsset, isNull);
    });

    test('handles 404, 403, and network errors gracefully', () async {
      final client404 = MockClient((req) async => http.Response('Not Found', 404));
      final service404 = GitHubUpdateService(client: client404);
      expect(
        () => service404.checkForUpdate(currentVersion: const AppVersion(major: 1, minor: 0, patch: 0)),
        throwsA(isA<GitHubReleaseException>()),
      );

      final client403 = MockClient((req) async => http.Response('Rate Limit', 403));
      final service403 = GitHubUpdateService(client: client403);
      expect(
        () => service403.checkForUpdate(currentVersion: const AppVersion(major: 1, minor: 0, patch: 0)),
        throwsA(isA<GitHubReleaseException>()),
      );
    });
  });

  group('AppUpdateController', () {
    test('enforces recheck interval throttling', () async {
      SharedPreferences.setMockInitialValues({});
      int requestCount = 0;

      final mockJson = jsonEncode({
        'tag_name': 'v1.1.0',
        'name': 'Release',
        'body': 'Notes',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/test/app.apk',
            'size': 1000,
          }
        ],
      });

      final client = MockClient((req) async {
        requestCount++;
        return http.Response(mockJson, 200);
      });

      final service = GitHubUpdateService(client: client);
      final controller = AppUpdateController(updateService: service);

      // First check (startup)
      await controller.checkForUpdate(force: false);
      expect(requestCount, 1);
      expect(controller.status, UpdateStatus.updateAvailable);

      // Immediate second check without force should be throttled
      await controller.checkForUpdate(force: false);
      expect(requestCount, 1); // Should not increase

      // Forced check ignores interval
      await controller.checkForUpdate(force: true);
      expect(requestCount, 2);
    });

    test('honors dismissed optional update', () async {
      SharedPreferences.setMockInitialValues({});

      final mockJson = jsonEncode({
        'tag_name': 'v1.2.0',
        'name': 'Optional update',
        'body': 'Optional notes',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/test/app.apk',
            'size': 1000,
          }
        ],
      });

      final client = MockClient((req) async => http.Response(mockJson, 200));
      final controller = AppUpdateController(updateService: GitHubUpdateService(client: client));

      await controller.checkForUpdate(force: true);
      expect(controller.status, UpdateStatus.updateAvailable);

      // User dismisses
      await controller.dismissUpdate();
      expect(controller.status, UpdateStatus.idle);

      // Subsequent check recognizes dismissed tag
      await controller.checkForUpdate(force: true);
      expect(controller.status, UpdateStatus.noUpdateAvailable);
    });
  });
}
