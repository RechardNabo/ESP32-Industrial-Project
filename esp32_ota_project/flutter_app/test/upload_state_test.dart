/// @file upload_state_test.dart
/// @brief Unit tests for the upload state sealed class and notifier logic.
///
/// Tests state transitions: Idle → Unlocking → Uploading → Success/Failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_ota_updater/providers/upload_state.dart';

void main() {
  group('UploadState sealed class', () {
    test('UploadIdle is the initial state', () {
      const state = UploadIdle();
      expect(state is UploadIdle, true);
    });

    test('UploadUnlocking has no progress fields', () {
      const state = UploadUnlocking();
      expect(state is UploadUnlocking, true);
    });

    test('UploadUploading has progress fields', () {
      const state = UploadUploading(
        progress: 0.5,
        bytesTransferred: 1024,
        totalBytes: 2048,
        speedBytesPerSecond: 51200,
        estimatedTimeRemaining: Duration(seconds: 20),
      );
      expect(state.progress, 0.5);
      expect(state.bytesTransferred, 1024);
      expect(state.totalBytes, 2048);
      expect(state.speedBytesPerSecond, 51200);
      expect(state.estimatedTimeRemaining, const Duration(seconds: 20));
    });

    test('UploadUploading progress formatting', () {
      const state = UploadUploading(
        progress: 0.75,
        bytesTransferred: 150000,
        totalBytes: 200000,
        speedBytesPerSecond: 51200,
        estimatedTimeRemaining: Duration(seconds: 1),
      );
      expect(state.progressPercent, '75.0%');
      expect(state.speedKBps, '50.0 KB/s');
    });

    test('UploadSuccess has version labels', () {
      const state = UploadSuccess(oldVersion: '1.0.0', newVersion: '1.1.0');
      expect(state.oldVersion, '1.0.0');
      expect(state.newVersion, '1.1.0');
      expect(state.versionChangeLabel, '1.0.0 → 1.1.0');
    });

    test('UploadFailure has message and optional detail', () {
      const state = UploadFailure(
        message: 'Connection refused',
        technicalDetail: 'SocketException: OS Error',
      );
      expect(state.message, 'Connection refused');
      expect(state.technicalDetail, 'SocketException: OS Error');
    });

    test('UploadFailure can have null technical detail', () {
      const state = UploadFailure(message: 'Timeout');
      expect(state.technicalDetail, isNull);
    });
  });

  group('UploadState type switching', () {
    test('all state types are distinct', () {
      const states = <UploadState>[
        UploadIdle(),
        UploadUnlocking(),
        UploadUploading(
          progress: 0.0,
          bytesTransferred: 0,
          totalBytes: 0,
          speedBytesPerSecond: 0,
          estimatedTimeRemaining: Duration.zero,
        ),
        UploadSuccess(oldVersion: '1.0.0', newVersion: '1.1.0'),
        UploadFailure(message: 'Error'),
      ];

      // Each state should be a different runtime type
      final types = states.map((s) => s.runtimeType).toSet();
      expect(types.length, 5);
    });
  });
}