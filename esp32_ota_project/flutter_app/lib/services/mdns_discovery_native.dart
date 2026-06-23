/// @file mdns_discovery_native.dart
/// @brief Native (non-web) device discovery implementation.
///
/// Uses a subnet HTTP probe as the primary discovery method because
/// mDNS via the multicast_dns Dart package is unreliable on Android/iOS
/// (raw UDP sockets often blocked by OS or network).
///
/// Discovery strategy:
///   1. Determine local IP via NetworkInterface enumeration
///   2. Scan all 254 IPs on the /24 subnet (max 20 concurrent probes)
///   3. Each probe hits GET /version — if the response JSON contains
///      "hostname" matching "esp32", it's our device
///   4. mDNS fallback is also attempted but secondary

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

import '../models/device_info.dart';
import 'mdns_discovery.dart';

/// Hostname filter — only devices whose hostname contains this will be included.
const String _hostnameFilter = 'esp32';

/// HTTP port to probe.
const int _defaultPort = 80;

/// Timeout for each HTTP probe request.
const Duration _probeTimeout = Duration(milliseconds: 1500);

/// Maximum concurrent subnet probes to avoid socket exhaustion.
const int _maxConcurrentProbes = 20;

/// Native discovery — subnet HTTP probe + mDNS fallback.
class MdnsDiscoveryServiceNative extends MdnsDiscoveryService {
  bool _isScanning = false;

  MdnsDiscoveryServiceNative({Duration? timeout})
      : super(defaultTimeout: timeout ?? const Duration(seconds: 10));

  @override
  Stream<DeviceInfo> discoverDevices({
    Duration? timeout,
    String? hostnameFilter,
  }) async* {
    final filter = hostnameFilter?.toLowerCase() ?? _hostnameFilter;
    final seenDevices = <String>{};

    _isScanning = true;

    // Strategy 1: Quick mDNS scan (short timeout, best-effort)
    try {
      final mdnsResults = _discoverViaMdns(filter, seenDevices);
      await for (final device in mdnsResults) {
        if (!_isScanning) break;
        yield device;
      }
    } catch (e) {
      print('[Discovery] mDNS scan failed: $e');
    }

    // Strategy 2: Subnet HTTP probe (reliable fallback)
    if (_isScanning) {
      final probeResults = _discoverViaSubnetProbe(filter, seenDevices);
      await for (final device in probeResults) {
        if (!_isScanning) break;
        yield device;
      }
    }

    _isScanning = false;
  }

  /// mDNS discovery using multicast_dns package.
  Stream<DeviceInfo> _discoverViaMdns(
      String filter, Set<String> seenDevices) async* {
    final client = MDnsClient();
    try {
      await client.start();

      // Query for SRV records (service instances)
      await for (final record in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(
          '_http._tcp.local',
        ),
        timeout: const Duration(seconds: 3),
      )) {
        if (!_isScanning) break;

        final hostname = record.name.toLowerCase();
        if (!hostname.contains(filter)) continue;

        // Try to resolve the IP address from the SRV target
        final target = record.target;
        final port = record.port;

        // Resolve target hostname to IP via A record query
        String? ipAddress;
        await for (final addrRecord
            in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(target),
          timeout: const Duration(seconds: 2),
        )) {
          ipAddress = addrRecord.address.address;
          break; // Take first A record
        }

        if (ipAddress == null || ipAddress.isEmpty) continue;

        final deviceKey = '$ipAddress:$port';
        if (seenDevices.contains(deviceKey)) continue;
        seenDevices.add(deviceKey);

        final cleanHostname =
            hostname.replaceAll(RegExp(r'\.local\.?$'), '');

        yield DeviceInfo(
          hostname: cleanHostname,
          ipAddress: ipAddress,
          port: port,
          lastSeen: DateTime.now(),
        );
      }
    } catch (e) {
      // mDNS is unreliable — don't propagate errors, just log
      print('[Discovery] mDNS error: $e');
    } finally {
      client.stop();
    }
  }

  /// Subnet HTTP probe — finds the local IP, then hits GET /version
  /// on every IP in the /24 subnet to find ESP32 devices.
  Stream<DeviceInfo> _discoverViaSubnetProbe(
      String filter, Set<String> seenDevices) async* {
    final localIp = await _getLocalIp();
    if (localIp == null || !_isScanning) return;

    print('[Discovery] Local IP: $localIp — scanning /24 subnet');

    final parts = localIp.split('.');
    if (parts.length != 4) return;
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    // Use a semaphore pattern to limit concurrent probes
    var running = 0;
    final semaphore = <Completer<void>>[];
    final results = <DeviceInfo>[];

    for (int i = 1; i <= 254 && _isScanning; i++) {
      final ip = '$subnet.$i';
      final key = '$ip:$_defaultPort';
      if (seenDevices.contains(key)) continue;

      // Limit concurrency
      while (running >= _maxConcurrentProbes) {
        final completer = Completer<void>();
        semaphore.add(completer);
        await completer.future;
        if (!_isScanning) return;
      }
      running++;

      _probeIp(ip, _defaultPort, filter).then((device) {
        if (device != null && _isScanning) {
          final deviceKey = '${device.ipAddress}:${device.port}';
          if (!seenDevices.contains(deviceKey)) {
            seenDevices.add(deviceKey);
            results.add(device);
          }
        }
      }).whenComplete(() {
        running--;
        if (semaphore.isNotEmpty) {
          semaphore.removeAt(0).complete();
        }
      });
    }

    // Wait for remaining probes to finish (with overall timeout)
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (running > 0 && _isScanning && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
      // Yield any discovered devices
      while (results.isNotEmpty) {
        yield results.removeAt(0);
      }
    }

    // Final yield
    while (results.isNotEmpty) {
      yield results.removeAt(0);
    }
  }

  /// Probe a single IP: hit GET /version, check if response contains
  /// hostname matching our filter.
  Future<DeviceInfo?> _probeIp(String ip, int port, String filter) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = _probeTimeout;
      final request = await client.getUrl(
        Uri.parse('http://$ip:$port/version'),
      );
      final response = await request.close();
      final body = await response
          .transform(utf8.decoder)
          .timeout(_probeTimeout)
          .join();

      // Parse just the hostname field from JSON
      // Expected: {"version":"1.0.0","hostname":"my-esp32",...}
      final hostnameMatch =
          RegExp(r'"hostname"\s*:\s*"([^"]+)"').firstMatch(body);
      if (hostnameMatch == null) return null;

      final hostname = hostnameMatch.group(1)!;
      if (!hostname.toLowerCase().contains(filter)) return null;

      return DeviceInfo(
        hostname: hostname,
        ipAddress: ip,
        port: port,
        lastSeen: DateTime.now(),
      );
    } catch (_) {
      return null;
    } finally {
      client?.close();
    }
  }

  /// Get the device's local IP address.
  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          if (_isPrivateIp(addr.address)) return addr.address;
        }
      }
      // Fallback: any non-loopback IPv4
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      print('[Discovery] Error getting local IP: $e');
    }
    return null;
  }

  /// Check if IP is a private LAN address.
  bool _isPrivateIp(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final octet = int.tryParse(ip.substring(5, ip.indexOf('.', 5))) ?? 0;
      if (octet >= 16 && octet <= 31) return true;
    }
    return false;
  }

  @override
  Future<String?> resolveHostname(String hostname) async {
    // Try direct HTTP probe of common IPs on local subnet
    final localIp = await _getLocalIp();
    if (localIp != null) {
      final parts = localIp.split('.');
      if (parts.length == 4) {
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        // Quick scan of low-number IPs first (ESP32 often uses static low IPs)
        for (int i = 1; i <= 50; i++) {
          final ip = '$subnet.$i';
          try {
            final client = HttpClient();
            client.connectionTimeout = const Duration(milliseconds: 500);
            final request = await client.getUrl(
              Uri.parse('http://$ip:$_defaultPort/version'),
            );
            final response = await request.close();
            final body = await response
                .transform(utf8.decoder)
                .timeout(const Duration(milliseconds: 500))
                .join();
            client.close();
            final hostnameMatch =
                RegExp(r'"hostname"\s*:\s*"([^"]+)"').firstMatch(body);
            if (hostnameMatch != null &&
                hostnameMatch
                    .group(1)!
                    .toLowerCase()
                    .contains(hostname.toLowerCase())) {
              return ip;
            }
          } catch (_) {
            continue;
          }
        }
      }
    }

    // Fallback: mDNS resolution
    final client = MDnsClient();
    try {
      await client.start();
      final fqdn =
          hostname.endsWith('.local') ? hostname : '$hostname.local';
      await for (final record
          in client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(fqdn),
        timeout: const Duration(seconds: 3),
      )) {
        return record.address.address;
      }
    } catch (e) {
      print('[Discovery] mDNS resolve failed for $hostname: $e');
    } finally {
      client.stop();
    }
    return null;
  }

  @override
  void stopScan() {
    _isScanning = false;
  }

  @override
  bool get isScanning => _isScanning;
}

/// Factory function for conditional import.
MdnsDiscoveryService createNativeService({Duration? timeout}) {
  return MdnsDiscoveryServiceNative(
      timeout: timeout ?? const Duration(seconds: 10));
}