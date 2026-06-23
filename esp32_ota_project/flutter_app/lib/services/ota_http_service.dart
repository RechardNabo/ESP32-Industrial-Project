/// @file ota_http_service.dart
/// @brief HTTP client for all OTA operations against an ESP32 device.
///
/// Provides typed result objects for every operation — never returns raw
/// http.Response. Handles error mapping, timeout handling, and Dio-based
/// multipart upload with progress callbacks.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../models/firmware_version.dart';

// ============================================================================
// Result Types — one per operation, never raw HTTP responses
// ============================================================================

/// Result of a GET /version request.
class VersionCheckResult {
  final bool success;
  final FirmwareVersion? version;
  final String? hostname;
  final int? uptimeSeconds;
  final String? errorMessage;

  const VersionCheckResult.success({
    required this.version,
    required this.hostname,
    required this.uptimeSeconds,
  })  : success = true,
        errorMessage = null;

  const VersionCheckResult.failure(this.errorMessage)
      : success = false,
        version = null,
        hostname = null,
        uptimeSeconds = null;
}

/// Result of a GET /status request.
class DeviceStatusResult {
  final bool success;
  final bool? otaUnlocked;
  final int? otaRemainingSeconds;
  final int? freeHeap;
  final int? flashSize;
  final String? chipModel;
  final String? mac;
  final String? errorMessage;

  const DeviceStatusResult.success({
    required this.otaUnlocked,
    required this.otaRemainingSeconds,
    required this.freeHeap,
    required this.flashSize,
    required this.chipModel,
    required this.mac,
  })  : success = true,
        errorMessage = null;

  const DeviceStatusResult.failure(this.errorMessage)
      : success = false,
        otaUnlocked = null,
        otaRemainingSeconds = null,
        freeHeap = null,
        flashSize = null,
        chipModel = null,
        mac = null;
}

/// Result of a GET /unlock-ota request.
class UnlockResult {
  final bool success;
  final bool? unlocked;
  final int? expiresIn;
  final String? errorMessage;

  const UnlockResult.success({required this.expiresIn})
      : success = true,
          unlocked = true,
          errorMessage = null;

  const UnlockResult.alreadyUnlocked({required this.expiresIn})
      : success = true,
          unlocked = true,
          errorMessage = null;

  const UnlockResult.failure(this.errorMessage)
      : success = false,
          unlocked = false,
          expiresIn = null;
}

/// Result of a POST /push-firmware upload.
class UploadResult {
  final bool success;
  final int? bytesWritten;
  final String? message;
  final String? errorMessage;
  final String? technicalDetail;

  const UploadResult.success({
    required this.bytesWritten,
    required this.message,
  })  : success = true,
        errorMessage = null,
        technicalDetail = null;

  const UploadResult.failure({
    required this.errorMessage,
    this.technicalDetail,
  })  : success = false,
        bytesWritten = null,
        message = null;
}

/// Result of a GET /heartbeat or POST /heartbeat request.
class HeartbeatResult {
  final bool success;
  final int? intervalMs;
  final int? tickCount;
  final int? ledPin;
  final bool? running;
  final String? errorMessage;

  const HeartbeatResult.success({
    required this.intervalMs,
    required this.tickCount,
    required this.ledPin,
    required this.running,
  })  : success = true,
        errorMessage = null;

  const HeartbeatResult.failure(this.errorMessage)
      : success = false,
        intervalMs = null,
        tickCount = null,
        ledPin = null,
        running = null;
}

// ============================================================================
// OTA HTTP Service
// ============================================================================

class OtaHttpService {
  final String baseUrl;

  /// HTTP client for simple GET operations (version, status, unlock).
  final http.Client _httpClient = http.Client();

  /// Dio instance for multipart file uploads with progress tracking.
  final Dio _dio;

  /// Request timeout for standard HTTP operations.
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Upload timeout — longer to accommodate large binary files.
  static const Duration _uploadTimeout = Duration(minutes: 5);

  OtaHttpService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: _uploadTimeout,
          sendTimeout: _uploadTimeout,
          receiveTimeout: _uploadTimeout,
        ));

  /// Fetch the current firmware version from the device.
  Future<VersionCheckResult> fetchVersion() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/version'))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = _parseJson(response.body);
        if (json == null) {
          return const VersionCheckResult.failure('Invalid JSON response');
        }
        return VersionCheckResult.success(
          version: FirmwareVersion.parse(json['version'] as String? ?? ''),
          hostname: json['hostname'] as String?,
          uptimeSeconds: json['uptime_s'] as int?,
        );
      }
      return VersionCheckResult.failure(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      // SocketException (native) or generic network errors (web)
      if (_isConnectionError(e)) {
        return const VersionCheckResult.failure(
          'Device unreachable — check network connection',
        );
      }
      if (e is TimeoutException) {
        return const VersionCheckResult.failure(
          'Request timed out — device may be offline',
        );
      }
      return VersionCheckResult.failure('Unexpected error: $e');
    }
  }

  /// Fetch the device status (OTA state, heap, chip info).
  Future<DeviceStatusResult> fetchStatus() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/status'))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = _parseJson(response.body);
        if (json == null) {
          return const DeviceStatusResult.failure('Invalid JSON response');
        }
        return DeviceStatusResult.success(
          otaUnlocked: json['ota_unlocked'] as bool? ?? false,
          otaRemainingSeconds: json['ota_remaining_s'] as int? ?? 0,
          freeHeap: json['free_heap'] as int?,
          flashSize: json['flash_size'] as int?,
          chipModel: json['chip_model'] as String?,
          mac: json['mac'] as String?,
        );
      }
      return DeviceStatusResult.failure(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        return const DeviceStatusResult.failure(
          'Device unreachable — check network connection',
        );
      }
      if (e is TimeoutException) {
        return const DeviceStatusResult.failure(
          'Request timed out — device may be offline',
        );
      }
      return DeviceStatusResult.failure('Unexpected error: $e');
    }
  }

  /// Unlock the OTA session on the device with the given token.
  Future<UnlockResult> unlockOta(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/unlock-ota').replace(
        queryParameters: {'token': token},
      );
      debugPrint('[OTA] unlockOta: GET $uri');
      final response = await _httpClient.get(uri).timeout(_requestTimeout);
      debugPrint('[OTA] unlockOta: response ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = _parseJson(response.body);
        if (json == null) {
          return const UnlockResult.failure('Invalid JSON response');
        }
        final expiresIn = json['expires_in_s'] as int? ?? 0;
        if (json['unlocked'] == true) {
          return UnlockResult.success(expiresIn: expiresIn);
        }
        return UnlockResult.failure('Unlock failed — unexpected response');
      }

      if (response.statusCode == 401) {
        final json = _parseJson(response.body);
        return UnlockResult.failure(
          json?['error'] as String? ?? 'Invalid token',
        );
      }

      if (response.statusCode == 429) {
        final json = _parseJson(response.body);
        return UnlockResult.failure(
          json?['error'] as String? ?? 'Too many attempts — try again later',
        );
      }

      return UnlockResult.failure('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[OTA] unlockOta: EXCEPTION: $e');
      if (_isConnectionError(e)) {
        return const UnlockResult.failure(
          'Device unreachable — check network connection',
        );
      }
      if (e is TimeoutException) {
        return const UnlockResult.failure('Unlock request timed out');
      }
      return UnlockResult.failure('Unexpected error: $e');
    }
  }

  /// Upload firmware binary to the device.
  ///
  /// Uses Dio for multipart/form-data upload with progress reporting.
  /// The [onProgress] callback receives (progressFraction, bytesTransferred, totalBytes).
  ///
  /// On native platforms, pass [filePath]. On web, pass [fileBytes] and [fileName].
  Future<UploadResult> pushFirmware({
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
    required void Function(double progress, int bytesTransferred, int totalBytes) onProgress,
  }) async {
    try {
      MultipartFile multipartFile;

      if (fileBytes != null) {
        // Web path: upload from bytes (already in memory)
        multipartFile = MultipartFile.fromBytes(
          fileBytes,
          filename: fileName ?? 'firmware.bin',
        );
      } else if (filePath != null) {
        // Native path: upload from file
        multipartFile = await MultipartFile.fromFile(filePath);
      } else {
        return const UploadResult.failure(
          errorMessage: 'No firmware data provided',
          technicalDetail: 'Either filePath or fileBytes must be provided',
        );
      }

      final formData = FormData.fromMap({
        'firmware': multipartFile,
      });

      final response = await _dio.post<dynamic>(
        '/push-firmware',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            onProgress(sent / total, sent, total);
          }
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return UploadResult.success(
            bytesWritten: data['bytes_written'] as int? ?? 0,
            message: data['message'] as String? ?? 'Rebooting...',
          );
        }
        return const UploadResult.success(
          bytesWritten: 0,
          message: 'Upload complete — device rebooting',
        );
      }

      // Non-200 status
      String? errorMsg;
      String? techDetail;
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        errorMsg = data['error'] as String?;
        techDetail = data.toString();
      }
      return UploadResult.failure(
        errorMessage: errorMsg ?? 'HTTP ${response.statusCode}',
        technicalDetail: techDetail,
      );
    } on DioException catch (e) {
      return UploadResult.failure(
        errorMessage: _mapDioError(e),
        technicalDetail: e.toString(),
      );
    } catch (e) {
      return UploadResult.failure(
        errorMessage: 'Unexpected error: $e',
        technicalDetail: e.toString(),
      );
    }
  }

  /// Map DioException types to user-facing messages.
  String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Device unreachable — connection timed out';
      case DioExceptionType.sendTimeout:
        return 'Upload timed out — device may have rebooted successfully';
      case DioExceptionType.receiveTimeout:
        return 'Upload timed out — device may have rebooted successfully';
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          return data['error'] as String? ?? 'Server error';
        }
        return 'Server error: ${e.response?.statusCode}';
      case DioExceptionType.cancel:
        return 'Upload cancelled';
      case DioExceptionType.connectionError:
        return 'Device unreachable — check network connection';
      default:
        return 'Network error: ${e.message ?? 'unknown'}';
    }
  }

  /// Safely parse a JSON response body.
  Map<String, dynamic>? _parseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // Heartbeat / Device Config
  // ============================================================================

  /// Fetch the current heartbeat configuration from the device.
  Future<HeartbeatResult> fetchHeartbeat() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/heartbeat'))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = _parseJson(response.body);
        if (json == null) {
          return const HeartbeatResult.failure('Invalid JSON response');
        }
        return HeartbeatResult.success(
          intervalMs: json['interval_ms'] as int? ?? 500,
          tickCount: json['tick_count'] as int? ?? 0,
          ledPin: json['led_pin'] as int? ?? 2,
          running: json['running'] as bool? ?? false,
        );
      }
      return HeartbeatResult.failure(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        return const HeartbeatResult.failure(
          'Device unreachable — check network connection',
        );
      }
      if (e is TimeoutException) {
        return const HeartbeatResult.failure(
          'Request timed out — device may be offline',
        );
      }
      return HeartbeatResult.failure('Unexpected error: $e');
    }
  }

  /// Update the heartbeat interval (milliseconds) on the device.
  /// Persists to NVS — survives reboot and OTA updates.
  Future<HeartbeatResult> setHeartbeatInterval(int intervalMs) async {
    try {
      final uri = Uri.parse('$baseUrl/heartbeat').replace(
        queryParameters: {'interval': intervalMs.toString()},
      );
      final response = await _httpClient.post(uri).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = _parseJson(response.body);
        if (json == null) {
          return const HeartbeatResult.failure('Invalid JSON response');
        }
        return HeartbeatResult.success(
          intervalMs: json['interval_ms'] as int? ?? intervalMs,
          tickCount: json['tick_count'] as int? ?? 0,
          ledPin: json['led_pin'] as int? ?? 2,
          running: json['running'] as bool? ?? true,
        );
      }
      // 400 = invalid interval value
      if (response.statusCode == 400) {
        final json = _parseJson(response.body);
        return HeartbeatResult.failure(
          json?['error'] as String? ?? 'Invalid interval value (must be 10–60000 ms)',
        );
      }
      return HeartbeatResult.failure(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        return const HeartbeatResult.failure(
          'Device unreachable — check network connection',
        );
      }
      if (e is TimeoutException) {
        return const HeartbeatResult.failure('Request timed out');
      }
      return HeartbeatResult.failure('Unexpected error: $e');
    }
  }

  /// Trigger device restart (POST /restart).
  /// The device may not respond if it succeeds.
  Future<bool> restartDevice() async {
    try {
      final response = await _httpClient
          .post(Uri.parse('$baseUrl/restart'))
          .timeout(_requestTimeout);
      // Device may reboot before sending response — treat any response or error as success
      return response.statusCode == 200 || response.statusCode == 503;
    } catch (e) {
      // Connection reset or timeout likely means device is rebooting
      return true;
    }
  }

  /// Dispose of HTTP resources.
  void dispose() {
    _httpClient.close();
    _dio.close();
  }

  /// Check if an exception is a network connection error.
  /// Works on both native (SocketException) and web platforms.
  static bool _isConnectionError(Object e) {
    // On native platforms, SocketException is the standard connection error
    if (!kIsWeb) {
      return e.runtimeType.toString() == 'SocketException';
    }
    // On web, connection errors surface as DioException or generic strings
    if (e is DioException) {
      return e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
    }
    // Fallback: check error message patterns
    final msg = e.toString().toLowerCase();
    return msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('network is unreachable') ||
        msg.contains('xmlhttprequest error');
  }
}