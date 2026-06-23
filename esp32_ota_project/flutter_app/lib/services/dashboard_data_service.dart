/// @file dashboard_data_service.dart
/// @brief Real-time data polling service for the ESP32 industrial dashboard.
///
/// Polls /version, /status, /heartbeat at configurable intervals and
/// maintains rolling time-series windows for charting. Exposes a
/// ValueNotifier-based API that the dashboard widgets subscribe to.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../services/ota_http_service.dart';

// ============================================================================
// Data Point — single measurement snapshot
// ============================================================================

class DashboardSnapshot {
  final DateTime timestamp;
  final int? freeHeap;
  final int? flashSize;
  final int? uptimeSeconds;
  final int? tickCount;
  final int? heartbeatIntervalMs;
  final bool? heartbeatRunning;
  final String? chipModel;
  final String? mac;
  final String? firmwareVersion;
  final bool? otaUnlocked;
  final int? otaRemainingSeconds;

  const DashboardSnapshot({
    required this.timestamp,
    this.freeHeap,
    this.flashSize,
    this.uptimeSeconds,
    this.tickCount,
    this.heartbeatIntervalMs,
    this.heartbeatRunning,
    this.chipModel,
    this.mac,
    this.firmwareVersion,
    this.otaUnlocked,
    this.otaRemainingSeconds,
  });

  /// Heap as percentage of total flash (approximate health indicator).
  double get heapPercent {
    if (freeHeap == null || flashSize == null || flashSize! == 0) return 0;
    return (freeHeap! / flashSize!).clamp(0.0, 1.0);
  }

  /// Tick rate (ticks/second) from consecutive snapshots.
  static double? computeTickRate(DashboardSnapshot prev, DashboardSnapshot curr) {
    if (prev.tickCount == null || curr.tickCount == null) return null;
    final dt = curr.timestamp.difference(prev.timestamp).inMilliseconds;
    if (dt <= 0) return null;
    final ticks = curr.tickCount! - prev.tickCount!;
    if (ticks < 0) return null; // device rebooted
    return (ticks / dt) * 1000; // ticks per second
  }
}

// ============================================================================
// Dashboard Data Service — polling + time-series
// ============================================================================

class DashboardDataService extends ChangeNotifier {
  final String baseUrl;
  final Duration pollInterval;
  final int maxHistoryPoints;

  OtaHttpService? _httpService;
  Timer? _pollTimer;
  DashboardSnapshot? _latest;
  final List<DashboardSnapshot> _history = [];
  DashboardSnapshot? _previous;
  bool _isRunning = false;
  String? _lastError;

  DashboardDataService({
    required this.baseUrl,
    this.pollInterval = const Duration(seconds: 3),
    this.maxHistoryPoints = 60,
  });

  // --- Public API ---

  DashboardSnapshot? get latest => _latest;
  List<DashboardSnapshot> get history => List.unmodifiable(_history);
  bool get isRunning => _isRunning;
  String? get lastError => _lastError;

  /// Computed tick rate from last two snapshots.
  double? get tickRate {
    if (_history.length < 2) return null;
    return DashboardSnapshot.computeTickRate(
      _history[_history.length - 2],
      _history[_history.length - 1],
    );
  }

  /// Start polling. Safe to call multiple times — no-op if already running.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _httpService = OtaHttpService(baseUrl: baseUrl);
    _poll(); // immediate first poll
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll());
    debugPrint('[DASH] Started polling $baseUrl every ${pollInterval.inSeconds}s');
  }

  /// Stop polling and release resources.
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _httpService?.dispose();
    _httpService = null;
    debugPrint('[DASH] Stopped polling');
  }

  /// Clear history and reset state.
  void reset() {
    _history.clear();
    _latest = null;
    _previous = null;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  // --- Internal ---

  Future<void> _poll() async {
    if (_httpService == null) return;
    try {
      final results = await Future.wait([
        _httpService!.fetchVersion(),
        _httpService!.fetchStatus(),
        _httpService!.fetchHeartbeat(),
      ]);

      final version = results[0] as VersionCheckResult;
      final status = results[1] as DeviceStatusResult;
      final heartbeat = results[2] as HeartbeatResult;

      final snapshot = DashboardSnapshot(
        timestamp: DateTime.now(),
        freeHeap: status.freeHeap,
        flashSize: status.flashSize,
        uptimeSeconds: version.uptimeSeconds,
        tickCount: heartbeat.tickCount,
        heartbeatIntervalMs: heartbeat.intervalMs,
        heartbeatRunning: heartbeat.running,
        chipModel: status.chipModel,
        mac: status.mac,
        firmwareVersion: version.version?.toString(),
        otaUnlocked: status.otaUnlocked,
        otaRemainingSeconds: status.otaRemainingSeconds,
      );

      _previous = _latest;
      _latest = snapshot;
      _lastError = null;

      _history.add(snapshot);
      if (_history.length > maxHistoryPoints) {
        _history.removeAt(0);
      }

      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[DASH] Poll error: $e');
      notifyListeners();
    }
  }
}