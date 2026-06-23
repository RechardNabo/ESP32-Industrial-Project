/// @file dashboard_matrix_tab.dart
/// @brief Industrial Health Matrix tab for the dashboard.
///
/// Displays a grid of status cells showing device subsystem health:
/// Network, Memory, Heartbeat, OTA, Firmware, Flash.

import 'package:flutter/material.dart';

import '../services/dashboard_data_service.dart';

class DashboardMatrixTab extends StatelessWidget {
  final DashboardDataService dataService;

  const DashboardMatrixTab({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dataService,
      builder: (_, __) {
        final snap = dataService.latest;
        final history = dataService.history;

        if (snap == null) {
          return const Center(child: Text('Waiting for data...'));
        }

        // Build matrix cells
        final cells = <_MatrixCellData>[
          // --- Network ---
          _MatrixCellData(
            title: 'Network',
            icon: Icons.wifi,
            status: _MatrixStatus.ok,
            details: [
              ('Uptime', _fmtUptime(snap.uptimeSeconds)),
              ('MAC', snap.mac ?? '—'),
            ],
          ),
          // --- Memory / Heap ---
          _MatrixCellData(
            title: 'Memory',
            icon: Icons.memory,
            status: _heapStatus(snap.freeHeap),
            details: [
              ('Free Heap', _fmtBytes(snap.freeHeap)),
              ('Flash Size', _fmtBytes(snap.flashSize)),
            ],
          ),
          // --- Heartbeat ---
          _MatrixCellData(
            title: 'Heartbeat',
            icon: Icons.favorite,
            status: snap.heartbeatRunning == true ? _MatrixStatus.ok : _MatrixStatus.error,
            details: [
              ('Running', snap.heartbeatRunning == true ? 'Yes' : 'No'),
              ('Interval', '${snap.heartbeatIntervalMs ?? 0} ms'),
              ('Tick Count', '${snap.tickCount ?? 0}'),
              ('Tick Rate', dataService.tickRate?.toStringAsFixed(2) ?? '—'),
            ],
          ),
          // --- OTA ---
          _MatrixCellData(
            title: 'OTA',
            icon: Icons.system_update,
            status: snap.otaUnlocked == true ? _MatrixStatus.warn : _MatrixStatus.ok,
            details: [
              ('Session', snap.otaUnlocked == true ? 'Unlocked' : 'Locked'),
              if (snap.otaUnlocked == true && snap.otaRemainingSeconds != null)
                ('Expires', '${snap.otaRemainingSeconds}s'),
            ],
          ),
          // --- Firmware ---
          _MatrixCellData(
            title: 'Firmware',
            icon: Icons.verified,
            status: _MatrixStatus.ok,
            details: [
              ('Version', snap.firmwareVersion ?? '—'),
              ('Chip', snap.chipModel ?? '—'),
            ],
          ),
          // --- Data Stream ---
          _MatrixCellData(
            title: 'Data Stream',
            icon: Icons.stream,
            status: history.isNotEmpty ? _MatrixStatus.ok : _MatrixStatus.warn,
            details: [
              ('Samples', '${history.length}'),
              ('Poll Rate', '${dataService.pollInterval.inSeconds}s'),
              ('Data Age', snap.timestamp != null
                  ? '${DateTime.now().difference(snap.timestamp!).inSeconds}s ago'
                  : '—'),
            ],
          ),
          // --- Heap Trend ---
          _MatrixCellData(
            title: 'Heap Trend',
            icon: Icons.trending_down,
            status: _heapTrendStatus(history),
            details: [
              ('Current', _fmtBytes(snap.freeHeap)),
              if (history.length >= 2) ...[
                ('Min', _fmtBytes(history.map((s) => s.freeHeap ?? 0).reduce((a, b) => a < b ? a : b))),
                ('Max', _fmtBytes(history.map((s) => s.freeHeap ?? 0).reduce((a, b) => a > b ? a : b))),
              ],
            ],
          ),
          // --- Stability ---
          _MatrixCellData(
            title: 'Stability',
            icon: Icons.shield,
            status: _stabilityStatus(history),
            details: [
              if (history.length >= 2)
                ('Uptime Δ', '${(history.last.uptimeSeconds ?? 0) - (history.first.uptimeSeconds ?? 0)}s'),
              if (history.isNotEmpty)
                ('Poll Errors', dataService.lastError != null ? '1' : '0'),
            ],
          ),
        ];

        return Column(
          children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Text('Health Matrix', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _StatusDot(status: _MatrixStatus.ok, label: 'OK'),
                  const SizedBox(width: 12),
                  _StatusDot(status: _MatrixStatus.warn, label: 'Warning'),
                  const SizedBox(width: 12),
                  _StatusDot(status: _MatrixStatus.error, label: 'Error'),
                ],
              ),
            ),
            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: cells.length,
                itemBuilder: (_, i) => _MatrixCell(data: cells[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  static _MatrixStatus _heapStatus(int? heap) {
    if (heap == null) return _MatrixStatus.warn;
    if (heap > 150000) return _MatrixStatus.ok;
    if (heap > 80000) return _MatrixStatus.warn;
    return _MatrixStatus.error;
  }

  static _MatrixStatus _heapTrendStatus(List<DashboardSnapshot> history) {
    if (history.length < 5) return _MatrixStatus.warn;
    final recent = history.sublist(history.length - 5);
    final avg = recent.map((s) => s.freeHeap ?? 0).reduce((a, b) => a + b) / 5;
    if (avg > 150000) return _MatrixStatus.ok;
    if (avg > 80000) return _MatrixStatus.warn;
    return _MatrixStatus.error;
  }

  static _MatrixStatus _stabilityStatus(List<DashboardSnapshot> history) {
    if (history.length < 3) return _MatrixStatus.warn;
    // Check if uptime is monotonically increasing (no reboots)
    for (int i = 1; i < history.length; i++) {
      final prev = history[i - 1].uptimeSeconds ?? 0;
      final curr = history[i].uptimeSeconds ?? 0;
      if (curr < prev) return _MatrixStatus.warn; // reboot detected
    }
    return _MatrixStatus.ok;
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
// Data types
// ============================================================================

enum _MatrixStatus { ok, warn, error }

class _MatrixCellData {
  final String title;
  final IconData icon;
  final _MatrixStatus status;
  final List<(String, String)> details;

  const _MatrixCellData({
    required this.title,
    required this.icon,
    required this.status,
    required this.details,
  });
}

class _StatusDot extends StatelessWidget {
  final _MatrixStatus status;
  final String label;

  const _StatusDot({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _MatrixStatus.ok => Colors.green,
      _MatrixStatus.warn => Colors.orange,
      _MatrixStatus.error => Colors.red,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}

class _MatrixCell extends StatelessWidget {
  final _MatrixCellData data;

  const _MatrixCell({required this.data});

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (data.status) {
      _MatrixStatus.ok => Colors.green.withValues(alpha: 0.5),
      _MatrixStatus.warn => Colors.orange.withValues(alpha: 0.5),
      _MatrixStatus.error => Colors.red.withValues(alpha: 0.5),
    };
    final bgColor = switch (data.status) {
      _MatrixStatus.ok => Colors.green.withValues(alpha: 0.05),
      _MatrixStatus.warn => Colors.orange.withValues(alpha: 0.05),
      _MatrixStatus.error => Colors.red.withValues(alpha: 0.05),
    };
    final iconColor = switch (data.status) {
      _MatrixStatus.ok => Colors.green,
      _MatrixStatus.warn => Colors.orange,
      _MatrixStatus.error => Colors.red,
    };

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(data.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const Spacer(),
            ...data.details.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.$1, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[600])),
                  Text(e.$2, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFamily: 'RobotoMono')),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}