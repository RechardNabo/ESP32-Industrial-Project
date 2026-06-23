/// @file upload_state.dart
/// @brief State management for OTA upload workflow using Riverpod.
///
/// Defines the upload state sealed class, state notifier, and all Riverpod
/// providers used across the application.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info.dart';
import '../models/firmware_version.dart';
import '../services/mdns_discovery.dart';
import '../services/ota_http_service.dart';

// ============================================================================
// Upload State — sealed class with all possible states
// ============================================================================

/// Represents the current state of an OTA firmware upload workflow.
sealed class UploadState {
  const UploadState();
}

/// Initial idle state — no upload in progress.
class UploadIdle extends UploadState {
  const UploadIdle();
}

/// OTA session is being unlocked with the token.
class UploadUnlocking extends UploadState {
  const UploadUnlocking();
}

/// Firmware binary is being streamed to the device.
class UploadUploading extends UploadState {
  final double progress;
  final int bytesTransferred;
  final int totalBytes;
  final double speedBytesPerSecond;
  final Duration estimatedTimeRemaining;

  const UploadUploading({
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speedBytesPerSecond,
    required this.estimatedTimeRemaining,
  });

  /// Human-readable progress percentage.
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  /// Formatted transfer speed in KB/s.
  String get speedKBps =>
      '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s';

  /// Formatted bytes transferred / total.
  String get transferLabel =>
      '${_formatBytes(bytesTransferred)} / ${_formatBytes(totalBytes)}';

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Upload completed successfully — device is rebooting.
class UploadSuccess extends UploadState {
  final String oldVersion;
  final String newVersion;

  const UploadSuccess({required this.oldVersion, required this.newVersion});

  /// Version change label (e.g. "1.0.0 → 1.1.0").
  String get versionChangeLabel => '$oldVersion → $newVersion';
}

/// Upload failed with an error.
class UploadFailure extends UploadState {
  final String message;
  final String? technicalDetail;

  const UploadFailure({required this.message, this.technicalDetail});
}

// ============================================================================
// Upload State Notifier
// ============================================================================

class UploadStateNotifier extends StateNotifier<UploadState> {
  final OtaHttpService _httpService;

  UploadStateNotifier(this._httpService) : super(const UploadIdle());

  /// Execute the full OTA update workflow:
  ///   1. Unlock OTA session
  ///   2. Upload firmware binary
  ///   3. Report success or failure
  Future<void> startUpdate({
    required DeviceInfo device,
    required String token,
    required String binFilePath,
    List<int>? binFileBytes, // For web platform where file path is unavailable
    String? binFileName,     // For web platform
    required FirmwareVersion oldVersion,
    FirmwareVersion? newVersion,
  }) async {
    // Phase 1: Unlock OTA
    state = const UploadUnlocking();

    final unlockResult = await _httpService.unlockOta(token);
    if (!unlockResult.success) {
      state = UploadFailure(
        message: unlockResult.errorMessage ?? 'Unlock failed',
      );
      return;
    }

    // Phase 2: Upload firmware
    final startTime = DateTime.now();
    int lastBytesTransferred = 0;
    DateTime lastSpeedTime = startTime;

    try {
      final result = await _httpService.pushFirmware(
        filePath: binFilePath.isNotEmpty ? binFilePath : null,
        fileBytes: binFileBytes,
        fileName: binFileName,
        onProgress: (progress, bytesTransferred, totalBytes) {
          // Calculate rolling speed (1-second window)
          final now = DateTime.now();
          final elapsed = now.difference(lastSpeedTime).inMilliseconds;
          double speed = 0;
          Duration eta = Duration.zero;

          if (elapsed > 500) {
            final bytesDelta = bytesTransferred - lastBytesTransferred;
            speed = (bytesDelta / elapsed) * 1000; // bytes per second
            lastBytesTransferred = bytesTransferred;
            lastSpeedTime = now;

            if (speed > 0 && totalBytes > 0) {
              final remainingBytes = totalBytes - bytesTransferred;
              eta = Duration(milliseconds: (remainingBytes / speed * 1000).round());
            }
          }

          state = UploadUploading(
            progress: progress,
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
            speedBytesPerSecond: speed,
            estimatedTimeRemaining: eta,
          );
        },
      );

      if (result.success) {
        state = UploadSuccess(
          oldVersion: oldVersion.toString(),
          newVersion: newVersion?.toString() ?? 'unknown',
        );
      } else {
        state = UploadFailure(
          message: result.errorMessage ?? 'Upload failed',
          technicalDetail: result.technicalDetail,
        );
      }
    } catch (e) {
      state = UploadFailure(
        message: 'Upload error: $e',
        technicalDetail: e.toString(),
      );
    }
  }

  /// Reset the upload state to idle.
  void reset() {
    state = const UploadIdle();
  }
}

// ============================================================================
// Riverpod Providers
// ============================================================================

/// mDNS discovery service singleton — uses platform-appropriate implementation.
final mdnsDiscoveryProvider = Provider<MdnsDiscoveryService>((ref) {
  return MdnsDiscoveryService.create();
});

/// Discovered devices stream — emits a list whenever new devices are found.
/// Time-limited to 15s on web (subnet scan) and 10s on native (mDNS).
final discoveredDevicesProvider =
    StreamProvider<List<DeviceInfo>>((ref) async* {
  final discovery = ref.watch(mdnsDiscoveryProvider);
  final devices = <DeviceInfo>[];

  // Apply a time limit so scanning doesn't run indefinitely
  final scanTimeout = kIsWeb
      ? const Duration(seconds: 15) // web subnet scan takes longer
      : const Duration(seconds: 10);

  try {
    await for (final device in discovery.discoverDevices().timeout(scanTimeout, onTimeout: (sink) {
      // Gracefully end the stream on timeout — devices found so far are kept
      sink.close();
    })) {
      // De-duplicate: only add if not already in the list
      if (!devices.any((d) => d == device)) {
        devices.add(device);
      }
      yield List.of(devices);
    }
  } finally {
    discovery.stopScan();
  }
});

/// Currently selected device (null until user selects one).
final selectedDeviceProvider = StateProvider<DeviceInfo?>((ref) => null);

/// HTTP service for the selected device (recreated when device changes).
final deviceHttpServiceProvider = Provider<OtaHttpService?>((ref) {
  final device = ref.watch(selectedDeviceProvider);
  if (device == null) return null;
  return OtaHttpService(baseUrl: device.baseUrl);
});

/// Device status — fetched on demand for the selected device.
final deviceStatusProvider =
    FutureProvider.family<DeviceStatusResult, String>((ref, baseUrl) async {
  final service = OtaHttpService(baseUrl: baseUrl);
  try {
    return service.fetchStatus();
  } finally {
    service.dispose();
  }
});

/// Device version — fetched on demand for the selected device.
final deviceVersionProvider =
    FutureProvider.family<VersionCheckResult, String>((ref, baseUrl) async {
  final service = OtaHttpService(baseUrl: baseUrl);
  try {
    return service.fetchVersion();
  } finally {
    service.dispose();
  }
});

/// Upload state notifier — manages the full OTA workflow.
final uploadStateProvider =
    StateNotifierProvider<UploadStateNotifier, UploadState>((ref) {
  final device = ref.watch(selectedDeviceProvider);
  final httpService = ref.watch(deviceHttpServiceProvider);
  return UploadStateNotifier(httpService ?? OtaHttpService(baseUrl: 'http://0.0.0.0'));
});