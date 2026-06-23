/// @file dashboard_overview_tab.dart
/// @brief Overview tab for the industrial dashboard.
///
/// Displays live gauges (heap, tick rate), key metric cards, and device info.

import 'package:flutter/material.dart';

import '../models/device_info.dart';
import '../services/dashboard_data_service.dart';

class DashboardOverviewTab extends StatelessWidget {
  final DashboardDataService dataService;
  final DeviceInfo device;

  const DashboardOverviewTab({
    super.key,
    required this.dataService,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dataService,
      builder: (_, __) {
        final snap = dataService.latest;
        final err = dataService.lastError;

        if (snap == null && err == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap == null && err != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Device unreachable', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(err, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () { dataService.stop(); dataService.start(); },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Row 1: Live Gauges
            Row(
              children: [
                Expanded(child: _HeapGauge(freeHeap: snap!.freeHeap, flashSize: snap.flashSize)),
                const SizedBox(width: 12),
                Expanded(child: _TickRateGauge(tickRate: dataService.tickRate, interval: snap.heartbeatIntervalMs)),
              ],
            ),
            const SizedBox(height: 16),

            // Row 2: Key Metrics
            Row(
              children: [
                Expanded(child: _MetricCard(
                  icon: Icons.memory,
                  label: 'Free Heap',
                  value: _fmtBytes(snap.freeHeap),
                  color: _heapColor(snap.freeHeap),
                )),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(
                  icon: Icons.timer,
                  label: 'Uptime',
                  value: _fmtUptime(snap.uptimeSeconds),
                  color: Colors.blue,
                )),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(
                  icon: Icons.toggle_on,
                  label: 'Heartbeat',
                  value: snap.heartbeatRunning == true ? 'Running' : 'Stopped',
                  color: snap.heartbeatRunning == true ? Colors.green : Colors.grey,
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Row 3: Device Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.devices, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Device Info', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const Divider(),
                    _infoRow(context, 'Hostname', device.hostname),
                    _infoRow(context, 'IP', '${device.ipAddress}:${device.port}'),
                    if (snap.firmwareVersion != null)
                      _infoRow(context, 'Firmware', snap.firmwareVersion!),
                    if (snap.chipModel != null)
                      _infoRow(context, 'Chip', snap.chipModel!),
                    if (snap.mac != null)
                      _infoRow(context, 'MAC', snap.mac!),
                    _infoRow(context, 'Flash', _fmtBytes(snap.flashSize)),
                    _infoRow(context, 'OTA', snap.otaUnlocked == true ? 'Unlocked' : 'Locked'),
                    if (snap.otaUnlocked == true && snap.otaRemainingSeconds != null && snap.otaRemainingSeconds! > 0)
                      _infoRow(context, 'OTA Expires', '${snap.otaRemainingSeconds}s'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Row 4: Tick count
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.counting, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Tick Count', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      '${snap.tickCount ?? 0}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: 'RobotoMono',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Polling info
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Polling every ${dataService.pollInterval.inSeconds}s · ${dataService.history.length} samples',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _infoRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          Flexible(child: Text(value, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontFamily: 'RobotoMono'))),
        ],
      ),
    );
  }

  static Color _heapColor(int? heap) {
    if (heap == null) return Colors.grey;
    if (heap > 200000) return Colors.green;
    if (heap > 100000) return Colors.orange;
    return Colors.red;
  }

  static String _fmtBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _fmtUptime(int? seconds) {
    if (seconds == null) return '—';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}

// ============================================================================
// Heap Gauge — circular progress indicator
// ============================================================================

class _HeapGauge extends StatelessWidget {
  final int? freeHeap;
  final int? flashSize;

  const _HeapGauge({this.freeHeap, this.flashSize});

  @override
  Widget build(BuildContext context) {
    final heap = freeHeap ?? 0;
    final flash = flashSize ?? 1;
    final pct = (heap / flash).clamp(0.0, 1.0);
    final color = pct > 0.3 ? Colors.green : (pct > 0.15 ? Colors.orange : Colors.red);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Heap', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 80, width: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey[200],
                    color: color,
                  ),
                  Center(
                    child: Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(heap / 1024).toStringAsFixed(0)} KB free',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'RobotoMono',
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tick Rate Gauge
// ============================================================================

class _TickRateGauge extends StatelessWidget {
  final double? tickRate;
  final int? interval;

  const _TickRateGauge({this.tickRate, this.interval});

  @override
  Widget build(BuildContext context) {
    final rate = tickRate;
    final expected = interval != null && interval! > 0 ? 1000.0 / interval! : 0;
    final displayRate = rate ?? 0;
    final color = rate == null
        ? Colors.grey
        : (displayRate > 0 ? Colors.blue : Colors.red);
    final pct = expected > 0 ? (displayRate / expected).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Tick Rate', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 80, width: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey[200],
                    color: color,
                  ),
                  Center(
                    child: Text(
                      rate != null ? '${displayRate.toStringAsFixed(1)}' : '—',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ticks/s (exp: ${expected.toStringAsFixed(1)})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'RobotoMono',
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Metric Card — compact icon + label + value
// ============================================================================

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'RobotoMono',
            ), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}