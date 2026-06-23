/// @file mdns_discovery_stub.dart
/// @brief Stub implementation for conditional import on web platforms.
///
/// This file provides a stub factory that is overridden by the native
/// implementation when dart.library.io is available.

import 'mdns_discovery.dart';

/// Stub — never actually called because kIsWeb routes to Web implementation.
/// This exists solely so the conditional import resolves on web targets.
MdnsDiscoveryService createNativeService({Duration? timeout}) {
  throw UnsupportedError('mDNS native discovery is not available on web');
}