/// @file mdns_discovery.dart
/// @brief Device discovery service for finding ESP32 OTA servers on the LAN.
///
/// Platform-specific implementations:
///   - Native: Uses mDNS + subnet HTTP probe scanning
///   - Web: Uses HTTP fetch-based subnet scanning (mDNS not available in browsers)
///
/// Provides both a Stream-based discovery API and a single-resolve method
/// for known hostnames.

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;

import '../models/device_info.dart';

// Conditional import: native implementation (web uses stub)
import 'mdns_discovery_stub.dart'
    if (dart.library.io) 'mdns_discovery_native.dart' as impl;

/// Abstract interface for device discovery.
abstract class MdnsDiscoveryService {
  /// Default scan timeout.
  final Duration defaultTimeout;

  MdnsDiscoveryService({this.defaultTimeout = const Duration(seconds: 10)});

  /// Create the appropriate implementation based on platform.
  factory MdnsDiscoveryService.create({Duration? timeout}) {
    if (kIsWeb) {
      return MdnsDiscoveryServiceWeb(
          timeout: timeout ?? const Duration(seconds: 10));
    }
    return impl.createNativeService(timeout: timeout);
  }

  /// Discover ESP32 OTA devices on the local network.
  Stream<DeviceInfo> discoverDevices({
    Duration? timeout,
    String? hostnameFilter,
  });

  /// Resolve a single known hostname to its current IP address.
  Future<String?> resolveHostname(String hostname);

  /// Cancel an in-progress scan.
  void stopScan();

  /// Whether a discovery scan is currently active.
  bool get isScanning;
}

// ============================================================================
// Web implementation — HTTP fetch-based subnet scanning
// ============================================================================
//
// On web, mDNS and raw sockets are not available. Instead, we use the
// http package (which uses browser fetch/XHR) to probe IPs on common LAN
// subnets. Each probe hits GET /version and checks if the JSON response
// contains "hostname" matching "esp32".
//
// Strategy: scan in priority order so devices appear quickly:
//   1. Known default IPs — all probed concurrently (instant if device is up)
//   2. Low IPs on common subnets (1-30) — batched concurrent probes
//   3. Full /24 scan — only if no devices found in phases 1-2
//
// The ESP32 firmware serves CORS headers (Access-Control-Allow-Origin: *)
// on all API endpoints, so cross-origin fetches from the web app succeed.

class MdnsDiscoveryServiceWeb extends MdnsDiscoveryService {
  bool _isScanning = false;

  /// Per-probe timeout — short since LAN devices respond in <100ms.
  /// Browser CORS preflight may add latency, so 800ms is safe.
  static const Duration _probeTimeout = Duration(milliseconds: 800);

  /// How many IPs to probe concurrently in each batch.
  static const int _batchSize = 30;

  MdnsDiscoveryServiceWeb({Duration? timeout})
      : super(defaultTimeout: timeout ?? const Duration(seconds: 10));

  @override
  Stream<DeviceInfo> discoverDevices({
    Duration? timeout,
    String? hostnameFilter,
  }) async* {
    final filter = hostnameFilter?.toLowerCase() ?? 'esp32';
    final seen = <String>{};

    debugPrint('[SCAN] discoverDevices: START (kIsWeb=$kIsWeb, filter=$filter)');
    _isScanning = true;

    // Shared HTTP client — reuse connections, reduce overhead
    final client = http.Client();

    try {
      // Phase 1: Quick probe — known default ESP32 IPs (concurrent)
      final quickIps = [
        '192.168.0.195', // default static IP
        '192.168.1.195',
        '192.168.4.1', // common AP mode
      ];

      final phase1Results = await _probeBatch(client, quickIps, 80, filter, seen);
      for (final device in phase1Results) {
        yield device;
      }

      // Phase 2: Low IP range on common subnets (1-30)
      final quickSubnets = ['192.168.0', '192.168.1'];
      for (final subnet in quickSubnets) {
        if (!_isScanning) return;
        final ips = List.generate(30, (i) => '$subnet.${i + 1}')
            .where((ip) => !seen.contains('$ip:80'))
            .toList();
        final results = await _probeBatch(client, ips, 80, filter, seen);
        for (final device in results) {
          yield device;
        }
      }

      // Phase 3: Full /24 scan of common subnets (only if nothing found yet)
      if (seen.isEmpty && _isScanning) {
        final fullSubnets = [
          '192.168.0',
          '192.168.1',
          '192.168.4',
          '10.0.0',
          '10.0.1'
        ];
        for (final subnet in fullSubnets) {
          if (!_isScanning) return;
          final ips = List.generate(224, (i) => '$subnet.${i + 31}')
              .where((ip) => !seen.contains('$ip:80'))
              .toList();
          final results = await _probeBatch(client, ips, 80, filter, seen);
          for (final device in results) {
            yield device;
          }
        }
      }
    } finally {
      client.close();
      _isScanning = false;
      debugPrint('[SCAN] discoverDevices: DONE (found ${seen.length} IPs scanned)');
    }
  }

  /// Probe a list of IPs concurrently in batches, returning found devices.
  Future<List<DeviceInfo>> _probeBatch(
    http.Client client,
    List<String> ips,
    int port,
    String filter,
    Set<String> seen,
  ) async {
    final found = <DeviceInfo>[];

    for (int i = 0; i < ips.length && _isScanning; i += _batchSize) {
      final batch = ips.skip(i).take(_batchSize).toList();
      final futures = <Future<DeviceInfo?>>[];

      for (final ip in batch) {
        seen.add('$ip:$port');
        futures.add(_probeIpWeb(client, ip, port, filter));
      }

      // Wait for the entire batch — individual probe failures are caught inside
      final results = await Future.wait(futures, eagerError: false);
      for (final device in results) {
        if (device != null) {
          seen.add('${device.ipAddress}:${device.port}');
          found.add(device);
        }
      }
    }

    return found;
  }

  /// Probe a single IP from the browser using the http package.
  /// Uses the shared [client] to reuse connections.
  Future<DeviceInfo?> _probeIpWeb(
    http.Client client,
    String ip,
    int port,
    String filter,
  ) async {
    if (!_isScanning) return null;
    try {
      final uri = Uri.parse('http://$ip:$port/version');
      final response = await client
          .get(uri)
          .timeout(_probeTimeout);

      if (response.statusCode != 200) return null;

      final body = response.body;
      final hostnameMatch =
          RegExp(r'"hostname"\s*:\s*"([^"]+)"').firstMatch(body);
      if (hostnameMatch == null) return null;

      final hostname = hostnameMatch.group(1)!;
      if (!hostname.toLowerCase().contains(filter)) return null;

      debugPrint('[SCAN] FOUND device: $hostname @ $ip:$port');
      return DeviceInfo(
        hostname: hostname,
        ipAddress: ip,
        port: port,
        lastSeen: DateTime.now(),
      );
    } on TimeoutException {
      // Silent — most IPs won't be ESP32 devices, this is expected
      return null;
    } catch (_) {
      // Silent — connection refused, CORS blocked, etc. are normal
      return null;
    }
  }

  @override
  Future<String?> resolveHostname(String hostname) async {
    return null;
  }

  @override
  void stopScan() {
    _isScanning = false;
  }

  @override
  bool get isScanning => _isScanning;
}