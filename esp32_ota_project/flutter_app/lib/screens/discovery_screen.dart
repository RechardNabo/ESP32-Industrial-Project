/// @file discovery_screen.dart
/// @brief Device discovery screen — scans for ESP32 devices via mDNS.
///
/// Displays an animated scan indicator while searching, lists discovered
/// devices as tappable cards, and provides a manual IP entry fallback
/// with pull-to-refresh support.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info.dart';
import '../providers/upload_state.dart';
import '../widgets/device_card.dart';
import 'device_config_screen.dart';

typedef DeviceTapCallback = void Function(DeviceInfo device);

class DiscoveryScreen extends ConsumerStatefulWidget {
  final DeviceTapCallback? onDeviceTap;

  const DiscoveryScreen({super.key, this.onDeviceTap});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '80');

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _navigateToDevice(DeviceInfo device) {
    if (widget.onDeviceTap != null) {
      widget.onDeviceTap!(device);
    } else {
      // Fallback: select device and navigate to config screen
      ref.read(selectedDeviceProvider.notifier).state = device;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _DefaultDeviceConfigWrapper(device: device),
        ),
      );
    }
  }

  void _connectToManualIp() {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 80;
    if (ip.isEmpty) return;

    final device = DeviceInfo(
      hostname: 'esp32-$ip',
      ipAddress: ip,
      port: port,
      lastSeen: DateTime.now(),
    );
    _navigateToDevice(device);
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(discoveredDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 OTA Update'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(discoveredDevicesProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Scan animation
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _scanController.value * 2 * 3.14159,
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.wifi_tethering,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scanning for ESP32 devices...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Discovered devices list
            devicesAsync.when(
              data: (devices) {
                if (devices.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No ESP32 devices found',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Make sure your device is powered on\nand connected to the same Wi-Fi network',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[400],
                                ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () =>
                                ref.invalidate(discoveredDevicesProvider),
                            child: const Text('Retry Scan'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final device = devices[index];
                      return DeviceCard(
                        device: device,
                        onTap: () => _navigateToDevice(device),
                      );
                    },
                    childCount: devices.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 12),
                      Text('Scan error: $error'),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () =>
                            ref.invalidate(discoveredDevicesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Manual IP entry
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Manual Connection',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _ipController,
                            decoration: const InputDecoration(
                              labelText: 'IP Address',
                              hintText: '192.168.0.195',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '80',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _connectToManualIp,
                          child: const Text('Connect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback wrapper for when no onDeviceTap callback is provided.
/// Navigates to DeviceConfigScreen.
class _DefaultDeviceConfigWrapper extends StatelessWidget {
  final DeviceInfo device;
  const _DefaultDeviceConfigWrapper({required this.device});

  @override
  Widget build(BuildContext context) {
    return DeviceConfigScreen(device: device);
  }
}