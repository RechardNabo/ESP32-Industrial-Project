/// @file binary_validator_test.dart
/// @brief Unit tests for the BinaryValidator pre-flight check logic.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_ota_updater/services/binary_validator.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ota_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Create a temp file with the given bytes and optional extension.
  Future<File> createTempFile(List<int> bytes, {String ext = '.bin'}) async {
    final path = '${tempDir.path}/test_firmware$ext';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  group('BinaryValidator.validate', () {
    test('accepts a valid .bin file with 0xE9 magic byte', () async {
      // First byte 0xE9 (ESP32 magic byte), plus some padding
      final file = await createTempFile([0xE9, 0x04, 0x02, 0x01, 0x00]);
      final result = await BinaryValidator.validate(file);

      expect(result.isValid, true);
      expect(result.fileSize, 5);
      expect(result.errorMessage, isNull);
    });

    test('rejects a .bin file with wrong magic byte', () async {
      final file = await createTempFile([0xFF, 0x04, 0x02, 0x01, 0x00]);
      final result = await BinaryValidator.validate(file);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('magic byte mismatch'));
      expect(result.errorMessage, contains('0xE9'));
      expect(result.errorMessage, contains('0xFF'));
    });

    test('rejects a .bin file with magic byte 0x00', () async {
      final file = await createTempFile([0x00]);
      final result = await BinaryValidator.validate(file);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('magic byte mismatch'));
    });

    test('rejects a non-.bin file extension', () async {
      final file = await createTempFile([0xE9], ext: '.hex');
      final result = await BinaryValidator.validate(file);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('.bin'));
    });

    test('rejects an empty file', () async {
      final file = await createTempFile([], ext: '.bin');
      final result = await BinaryValidator.validate(file);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('empty'));
    });

    test('rejects a file exceeding max size', () async {
      // Create a file with 100 bytes, max size 50
      final bytes = List.filled(100, 0xE9);
      final file = await createTempFile(bytes, ext: '.bin');
      final result = await BinaryValidator.validate(file, maxSizeBytes: 50);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('too large'));
    });

    test('accepts a file exactly at max size boundary', () async {
      final bytes = List.filled(100, 0x00);
      bytes[0] = 0xE9;
      final file = await createTempFile(bytes, ext: '.bin');
      final result = await BinaryValidator.validate(file, maxSizeBytes: 100);

      expect(result.isValid, true);
    });

    test('rejects a non-existent file', () async {
      final file = File('${tempDir.path}/nonexistent.bin');
      final result = await BinaryValidator.validate(file);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('does not exist'));
    });

    test('accepts a real-size ESP32 image header', () async {
      // Simulate a realistic ESP32 image: 0xE9 + 24 bytes of header
      final header = <int>[0xE9] + List.filled(24, 0x00);
      final file = await createTempFile(header, ext: '.bin');
      final result = await BinaryValidator.validate(file);

      expect(result.isValid, true);
      expect(result.fileSize, 25);
    });
  });
}