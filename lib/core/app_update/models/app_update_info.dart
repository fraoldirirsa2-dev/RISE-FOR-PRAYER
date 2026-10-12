/// Semantic version representation supporting standard versions and build numbers
/// (e.g., 1.0.0, 1.2.0+3, v2.1.0).
class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber = 0,
    this.rawString = '',
  });

  final int major;
  final int minor;
  final int patch;
  final int buildNumber;
  final String rawString;

  /// Parses a version string like "v1.2.3+4", "1.2.3", "v1.2", or "1.0.0.1".
  factory AppVersion.parse(String input) {
    final clean = input.trim().replaceFirst(RegExp(r'^[vV]'), '');
    if (clean.isEmpty) {
      return const AppVersion(major: 0, minor: 0, patch: 0, rawString: '');
    }

    // Split build number if present (+4 or _4)
    final plusParts = clean.split('+');
    final versionCore = plusParts.first;
    int build = 0;
    if (plusParts.length > 1) {
      build = int.tryParse(plusParts[1]) ?? 0;
    }

    // Split major.minor.patch
    final segments = versionCore.split('.');
    final major = segments.isNotEmpty ? int.tryParse(segments[0]) ?? 0 : 0;
    final minor = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
    final patch = segments.length > 2 ? int.tryParse(segments[2]) ?? 0 : 0;

    // In case there's a 4th segment without +, check if it's a build
    if (segments.length > 3 && build == 0) {
      build = int.tryParse(segments[3]) ?? 0;
    }

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: build,
      rawString: input.trim(),
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (buildNumber != other.buildNumber && buildNumber > 0 && other.buildNumber > 0) {
      return buildNumber.compareTo(other.buildNumber);
    }
    return 0;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          (buildNumber == other.buildNumber || buildNumber == 0 || other.buildNumber == 0);

  @override
  int get hashCode => major.hashCode ^ minor.hashCode ^ patch.hashCode;

  String get displayVersion {
    final base = '$major.$minor.$patch';
    return buildNumber > 0 ? '$base+$buildNumber' : base;
  }

  @override
  String toString() => displayVersion;
}

/// Information about an installable release asset (APK).
class ReleaseAssetInfo {
  const ReleaseAssetInfo({
    required this.name,
    required this.downloadUrl,
    required this.sizeInBytes,
    this.sha256Digest,
  });

  final String name;
  final String downloadUrl;
  final int sizeInBytes;
  final String? sha256Digest;

  String get formattedSize {
    if (sizeInBytes <= 0) return '';
    final mb = sizeInBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Complete update descriptor parsed from a verified GitHub release.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.installedVersion,
    required this.latestVersion,
    required this.releaseTag,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.publishedAt,
    required this.apkAsset,
    required this.isUpdateAvailable,
    this.isMandatory = false,
  });

  final AppVersion installedVersion;
  final AppVersion latestVersion;
  final String releaseTag;
  final String releaseTitle;
  final String releaseNotes;
  final DateTime? publishedAt;
  final ReleaseAssetInfo? apkAsset;
  final bool isUpdateAvailable;
  final bool isMandatory;

  /// Whether this update is ready for user-initiated download and install.
  bool get canInstall => isUpdateAvailable && apkAsset != null;
}
