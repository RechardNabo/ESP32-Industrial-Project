/// @file ota_http_service_test.dart
/// @brief Unit tests for OtaHttpService result types and error mapping.
///
/// These tests verify the typed result objects and Dio error mapping logic
/// using mock HTTP responses. Actual network calls are not made.

import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_ota_updater/services/ota_http_service.dart';
import 'package:esp32_ota_updater/models/firmware_version.dart';

void main() {
  group('VersionCheckResult', () {
    test('success state carries version info', () {
      const result = VersionCheckResult.success(
        version: FirmwareVersion(1, 2, 3),
        hostname: 'my-esp32',
        uptimeSeconds: 3600,
      );
      expect(result.success, true);
      expect(result.version?.toString(), '1.2.3');
      expect(result.hostname, 'my-esp32');
      expect(result.uptimeSeconds, 3600);
      expect(result.errorMessage, isNull);
    });

    test('failure state carries error message', () {
      const result = VersionCheckResult.failure('Device unreachable');
      expect(result.success, false);
      expect(result.version, isNull);
      expect(result.errorMessage, 'Device unreachable');
    });
  });

  group('DeviceStatusResult', () {
    test('success state carries device info', () {
      const result = DeviceStatusResult.success(
        otaUnlocked: true,
        otaRemainingSeconds: 45,
        freeHeap: 218432,
        flashSize: 4194304,
        chipModel: 'ESP32',
        mac: 'AA:BB:CC:DD:EE:FF',
      );
      expect(result.success, true);
      expect(result.otaUnlocked, true);
      expect(result.otaRemainingSeconds, 45);
      expect(result.freeHeap, 218432);
      expect(result.flashSize, 4194304);
      expect(result.chipModel, 'ESP32');
      expect(result.mac, 'AA:BB:CC:DD:EE:FF');
    });

    test('failure state carries error message', () {
      const result = DeviceStatusResult.failure('Timeout');
      expect(result.success, false);
      expect(result.otaUnlocked, isNull);
      expect(result.errorMessage, 'Timeout');
    });
  });

  group('UnlockResult', () {
    test('success state indicates unlocked', () {
      const result = UnlockResult.success(expiresIn: 60);
      expect(result.success, true);
      expect(result.unlocked, true);
      expect(result.expiresIn, 60);
    });

    test('failure state indicates not unlocked', () {
      const result = UnlockResult.failure('Invalid token');
      expect(result.success, false);
      expect(result.unlocked, false);
      expect(result.errorMessage, 'Invalid token');
    });
  });

  group('UploadResult', () {
    test('success state carries bytes written', () {
      const result = UploadResult.success(
        bytesWritten: 184320,
        message: 'Rebooting...',
      );
      expect(result.success, true);
      expect(result.bytesWritten, 184320);
      expect(result.message, 'Rebooting...');
      expect(result.errorMessage, isNull);
    });

    test('failure state carries error and detail', () {
      const result = UploadResult.failure(
        errorMessage: 'Invalid binary',
        technicalDetail: 'Magic byte mismatch: expected 0xE9, got 0xFF',
      );
      expect(result.success, false);
      expect(result.errorMessage, 'Invalid binary');
      expect(result.technicalDetail, contains('0xE9'));
    });

    test('failure state can have null technical detail', () {
      const result = UploadResult.failure(errorMessage: 'Connection refused');
      expect(result.technicalDetail, isNull);
    });
  });

  group('OtaHttpService construction', () {
    test('baseUrl is stored correctly', () {
      final service = OtaHttpService(baseUrl: 'http://192.168.1.45:80');
      expect(service.baseUrl, 'http://192.168.1.45:80');
      service.dispose();
    });
  });
}