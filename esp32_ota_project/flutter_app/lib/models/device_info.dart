/// @file device_info.dart
/// @brief Data model for an mDNS-discovered ESP32 device.
///
/// Represents a single device found on the local network via mDNS scanning,
/// including its hostname, resolved IP address, port, and discovery timestamp.

class DeviceInfo {
  /// mDNS hostname (e.g. "my-esp32")
  final String hostname;

  /// Resolved IP address (e.g. "192.168.1.45")
  final String ipAddress;

  /// HTTP port the device is serving on (typically 80)
  final int port;

  /// Timestamp when this device was last seen during a scan
  final DateTime lastSeen;

  /// Base URL for HTTP communication with this device
  String get baseUrl => 'http://$ipAddress:$port';

  /// mDNS fully-qualified domain name (e.g. "my-esp32.local")
  String get fqdn => '$hostname.local';

  const DeviceInfo({
    required this.hostname,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
  });

  /// Create a copy with updated fields
  DeviceInfo copyWith({
    String? hostname,
    String? ipAddress,
    int? port,
    DateTime? lastSeen,
  }) {
    return DeviceInfo(
      hostname: hostname ?? this.hostname,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceInfo && other.ipAddress == ipAddress && other.port == port;

  @override
  int get hashCode => Object.hash(ipAddress, port);

  @override
  String toString() => 'DeviceInfo($hostname @ $ipAddress:$port)';
}