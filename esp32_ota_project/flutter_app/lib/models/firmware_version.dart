/// @file firmware_version.dart
/// @brief Semantic versioning model with comparison logic for OTA version gating.
///
/// Implements full SemVer (MAJOR.MINOR.PATCH) parsing, comparison, and formatting.
/// Gracefully handles malformed strings by returning FirmwareVersion(0, 0, 0).

class FirmwareVersion implements Comparable<FirmwareVersion> {
  final int major;
  final int minor;
  final int patch;

  const FirmwareVersion(this.major, this.minor, this.patch);

  /// Parses a version string like "1.2.3" into a FirmwareVersion.
  ///
  /// Returns FirmwareVersion(0, 0, 0) with a logged warning for:
  ///   - Null or empty strings
  ///   - Strings that don't match the "X.Y.Z" pattern
  ///   - Components that are not valid integers
  static FirmwareVersion parse(String versionString) {
    if (versionString.isEmpty) {
      _logWarning('Empty version string — defaulting to 0.0.0');
      return const FirmwareVersion(0, 0, 0);
    }

    final parts = versionString.split('.');
    if (parts.length != 3) {
      _logWarning(
        'Invalid version format "$versionString" — expected X.Y.Z, '
        'defaulting to 0.0.0',
      );
      return const FirmwareVersion(0, 0, 0);
    }

    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);

    if (major == null || minor == null || patch == null) {
      _logWarning(
        'Non-numeric version components in "$versionString" — '
        'defaulting to 0.0.0',
      );
      return const FirmwareVersion(0, 0, 0);
    }

    return FirmwareVersion(major, minor, patch);
  }

  /// Returns true if this version is strictly newer than [other].
  bool isNewerThan(FirmwareVersion other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    return patch > other.patch;
  }

  /// Returns true if this version is identical to [other].
  bool isEqualTo(FirmwareVersion other) {
    return major == other.major && minor == other.minor && patch == other.patch;
  }

  @override
  int compareTo(FirmwareVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is FirmwareVersion && isEqualTo(other);

  @override
  int get hashCode => Object.hash(major, minor, patch);

  static void _logWarning(String message) {
    // In production, replace with a proper logging framework
    print('[FirmwareVersion] WARNING: $message');
  }
}