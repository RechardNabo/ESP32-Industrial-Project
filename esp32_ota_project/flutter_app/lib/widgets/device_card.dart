/// @file device_card.dart
/// @brief Card widget displaying a single discovered ESP32 device.
///
/// Shows hostname, IP address, and a brief status indicator.
/// Tapping the card selects the device for detail/OTA operations.

import 'package:flutter/material.dart';

import '../../models/device_info.dart';

class DeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeSinceSeen = DateTime.now().difference(device.lastSeen);
    final seenLabel = timeSinceSeen.inSeconds < 5
        ? 'just now'
        : '${timeSinceSeen.inSeconds}s ago';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ESP32 icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.memory,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.hostname,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${device.ipAddress}:${device.port}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontFamily: 'RobotoMono',
                          ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Online',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    seenLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}