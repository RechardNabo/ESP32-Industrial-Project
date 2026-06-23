/// @file firmware_version_test.dart
/// @brief Unit tests for the FirmwareVersion SemVer model.

import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_ota_updater/models/firmware_version.dart';

void main() {
  group('FirmwareVersion.parse', () {
    test('parses valid version strings', () {
      final v = FirmwareVersion.parse('1.2.3');
      expect(v.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
    });

    test('parses version with zeros', () {
      final v = FirmwareVersion.parse('0.0.0');
      expect(v.major, 0);
      expect(v.minor, 0);
      expect(v.patch, 0);
    });

    test('parses large version numbers', () {
      final v = FirmwareVersion.parse('99.99.99');
      expect(v.major, 99);
      expect(v.minor, 99);
      expect(v.patch, 99);
    });

    test('returns 0.0.0 for empty string', () {
      final v = FirmwareVersion.parse('');
      expect(v, const FirmwareVersion(0, 0, 0));
    });

    test('returns 0.0.0 for version with only two parts', () {
      final v = FirmwareVersion.parse('1.2');
      expect(v, const FirmwareVersion(0, 0, 0));
    });

    test('returns 0.0.0 for version with four parts', () {
      final v = FirmwareVersion.parse('1.2.3.4');
      expect(v, const FirmwareVersion(0, 0, 0));
    });

    test('returns 0.0.0 for non-numeric components', () {
      final v = FirmwareVersion.parse('a.b.c');
      expect(v, const FirmwareVersion(0, 0, 0));
    });

    test('returns 0.0.0 for partial non-numeric', () {
      final v = FirmwareVersion.parse('1.two.3');
      expect(v, const FirmwareVersion(0, 0, 0));
    });

    test('handles version with pre-release tag gracefully', () {
      final v = FirmwareVersion.parse('1.2.3-beta');
      expect(v, const FirmwareVersion(0, 0, 0));
    });
  });

  group('FirmwareVersion.isNewerThan', () {
    test('major version takes precedence', () {
      const v1 = FirmwareVersion(2, 0, 0);
      const v2 = FirmwareVersion(1, 9, 9);
      expect(v1.isNewerThan(v2), true);
      expect(v2.isNewerThan(v1), false);
    });

    test('minor version compared when major equal', () {
      const v1 = FirmwareVersion(1, 2, 0);
      const v2 = FirmwareVersion(1, 1, 9);
      expect(v1.isNewerThan(v2), true);
      expect(v2.isNewerThan(v1), false);
    });

    test('patch version compared when major and minor equal', () {
      const v1 = FirmwareVersion(1, 2, 3);
      const v2 = FirmwareVersion(1, 2, 2);
      expect(v1.isNewerThan(v2), true);
      expect(v2.isNewerThan(v1), false);
    });

    test('equal versions are not newer', () {
      const v1 = FirmwareVersion(1, 2, 3);
      const v2 = FirmwareVersion(1, 2, 3);
      expect(v1.isNewerThan(v2), false);
    });

    test('0.0.0 is not newer than anything', () {
      const v1 = FirmwareVersion(0, 0, 0);
      const v2 = FirmwareVersion(0, 0, 1);
      expect(v1.isNewerThan(v2), false);
    });
  });

  group('FirmwareVersion.isEqualTo', () {
    test('equal versions', () {
      const v1 = FirmwareVersion(1, 2, 3);
      const v2 = FirmwareVersion(1, 2, 3);
      expect(v1.isEqualTo(v2), true);
    });

    test('different versions', () {
      const v1 = FirmwareVersion(1, 2, 3);
      const v2 = FirmwareVersion(1, 2, 4);
      expect(v1.isEqualTo(v2), false);
    });
  });

  group('FirmwareVersion.compareTo', () {
    test('ordering is correct', () {
      const versions = [
        FirmwareVersion(2, 0, 0),
        FirmwareVersion(1, 5, 0),
        FirmwareVersion(1, 2, 5),
        FirmwareVersion(1, 2, 3),
        FirmwareVersion(0, 9, 0),
      ];

      final sorted = List.of(versions)..sort();
      for (int i = 0; i < sorted.length - 1; i++) {
        expect(sorted[i].compareTo(sorted[i + 1]) <= 0, true);
      }
    });
  });

  group('FirmwareVersion.toString', () {
    test('formats as MAJOR.MINOR.PATCH', () {
      const v = FirmwareVersion(1, 2, 3);
      expect(v.toString(), '1.2.3');
    });
  });

  group('FirmwareVersion equality', () {
    test('equal versions are equal', () {
      const v1 = FirmwareVersion(1, 2, 3);
      const v2 = FirmwareVersion(1, 2, 3);
      expect(v1 == v2, true);
    });

    test('different versions are not equal', () {
      const v1 = FirmwareVersion(1, 2, 3);
      const v2 = FirmwareVersion(1, 2, 4);
      expect(v1 == v2, false);
    });

    test('hash code matches for equal versions', () {
      const v1 = FirmwareVersion(1, 2, 3);
      const v2 = FirmwareVersion(1, 2, 3);
      expect(v1.hashCode, v2.hashCode);
    });
  });
}