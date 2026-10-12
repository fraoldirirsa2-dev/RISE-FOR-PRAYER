import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rise_for_prayer/core/app_update/models/app_update_info.dart';

/// Service that checks the latest published GitHub Release for installable APK assets.
class GitHubUpdateService {
  GitHubUpdateService({
    this.owner = 'fraoldirirsa2-dev',
    this.repo = 'RISE-FOR-PRAYER',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String owner;
  final String repo;
  final http.Client _client;

  String get latestReleaseApiUrl =>
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  /// Fetches installed version metadata using package_info_plus.
  Future<AppVersion> getInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final buildNum = int.tryParse(info.buildNumber) ?? 0;
      final parsed = AppVersion.parse(info.version);
      return AppVersion(
        major: parsed.major,
        minor: parsed.minor,
        patch: parsed.patch,
        buildNumber: buildNum > 0 ? buildNum : parsed.buildNumber,
        rawString: '${info.version}+${info.buildNumber}',
      );
    } catch (_) {
      // Fallback default in non-standard test environments
      return const AppVersion(major: 1, minor: 0, patch: 0, buildNumber: 1, rawString: '1.0.0+1');
    }
  }

  /// Checks GitHub latest release and returns update status.
  /// Throws descriptive exceptions on network or format errors.
  Future<AppUpdateInfo> checkForUpdate({AppVersion? currentVersion}) async {
    final installed = currentVersion ?? await getInstalledVersion();

    final response = await _client.get(
      Uri.parse(latestReleaseApiUrl),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'RiseForPrayer-AppUpdate/1.0',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 404) {
      throw const GitHubReleaseException('No published releases found for this repository.');
    }
    if (response.statusCode == 403) {
      throw const GitHubReleaseException('GitHub API rate limit exceeded. Please try again later.');
    }
    if (response.statusCode != 200) {
      throw GitHubReleaseException(
        'GitHub API returned HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Error"}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const GitHubReleaseException('Invalid release data format received from GitHub.');
    }

    final isDraft = decoded['draft'] == true;
    final isPrerelease = decoded['prerelease'] == true;
    if (isDraft || isPrerelease) {
      throw const GitHubReleaseException('Latest release is a draft or prerelease; skipping update.');
    }

    final tagName = (decoded['tag_name'] as String?)?.trim() ?? '';
    final releaseTitle = (decoded['name'] as String?)?.trim() ?? tagName;
    final releaseNotes = (decoded['body'] as String?)?.trim() ?? '';
    final publishedAtStr = decoded['published_at'] as String?;
    final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

    final latestVersion = AppVersion.parse(tagName);

    // Look for valid Android APK assets in the release
    final assets = decoded['assets'];
    ReleaseAssetInfo? selectedApk;
    String? sha256Checksum;

    if (assets is List) {
      // 1. Look for a checksum file (e.g. SHA256SUMS.txt or .sha256)
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final assetName = (asset['name'] as String? ?? '').toLowerCase();
          if (assetName.endsWith('.sha256') || assetName.contains('checksum')) {
            // Attempt to fetch sha256 checksum string if available
            final url = asset['browser_download_url'] as String?;
            if (url != null) {
              sha256Checksum = await _fetchChecksum(url);
            }
          }
        }
      }

      // 2. Look for APK asset
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final assetName = (asset['name'] as String? ?? '').trim();
          final downloadUrl = asset['browser_download_url'] as String? ?? '';
          final size = (asset['size'] as num?)?.toInt() ?? 0;

          if (assetName.toLowerCase().endsWith('.apk') && downloadUrl.isNotEmpty) {
            // Found a valid APK asset
            selectedApk = ReleaseAssetInfo(
              name: assetName,
              downloadUrl: downloadUrl,
              sizeInBytes: size,
              sha256Digest: sha256Checksum,
            );
            break;
          }
        }
      }
    }

    // Check mandatory update flag in release notes: [MANDATORY] or [REQUIRED]
    final isMandatory = releaseNotes.toUpperCase().contains('[MANDATORY]') ||
        releaseNotes.toUpperCase().contains('[REQUIRED]');

    final isNewer = latestVersion > installed;

    return AppUpdateInfo(
      installedVersion: installed,
      latestVersion: latestVersion,
      releaseTag: tagName,
      releaseTitle: releaseTitle,
      releaseNotes: releaseNotes,
      publishedAt: publishedAt,
      apkAsset: selectedApk,
      isUpdateAvailable: isNewer && selectedApk != null,
      isMandatory: isMandatory,
    );
  }

  Future<String?> _fetchChecksum(String url) async {
    try {
      final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        // e.g. "a1b2c3...  app-release.apk"
        final body = res.body.trim();
        final match = RegExp(r'^[a-fA-F0-9]{64}').firstMatch(body);
        return match?.group(0);
      }
    } catch (_) {}
    return null;
  }
}

class GitHubReleaseException implements Exception {
  const GitHubReleaseException(this.message);
  final String message;

  @override
  String toString() => message;
}
