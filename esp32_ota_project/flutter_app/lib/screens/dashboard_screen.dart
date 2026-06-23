/// @file dashboard_screen.dart
/// @brief Industrial Dashboard — main shell with Overview, Matrix, Charts tabs.
///
/// Displays real-time data from a connected ESP32 device with:
///   - Overview: live gauges, key metrics, device info cards
///   - Matrix: industrial health grid with status cells
///   - Charts: time-series line charts for heap, uptime, tick rate

import 'package:flutter/material.dart';

import '../models/device_info.dart';
import '../services/dashboard_data_service.dart';
import 'dashboard_overview_tab.dart';
import 'dashboard_matrix_tab.dart';
import 'dashboard_charts_tab.dart';

class DashboardScreen extends StatefulWidget {
  final DeviceInfo device;

  const DashboardScreen({super.key, required this.device});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DashboardDataService _dataService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _dataService = DashboardDataService(baseUrl: widget.device.baseUrl);
    _dataService.start();
  }

  @override
  void dispose() {
    _dataService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dashboard_outlined, size: 20),
            const SizedBox(width: 8),
            Text('Dashboard', style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              widget.device.ipAddress,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'RobotoMono',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          ListenableBuilder(
            listenable: _dataService,
            builder: (_, __) {
              final ok = _dataService.latest != null && _dataService.lastError == null;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ok ? Colors.green : Colors.orange,
                        boxShadow: ok
                            ? [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 4)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ok ? 'Live' : 'Polling',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ok ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.speed_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.grid_view_outlined), text: 'Matrix'),
            Tab(icon: Icon(Icons.show_chart), text: 'Charts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DashboardOverviewTab(dataService: _dataService, device: widget.device),
          DashboardMatrixTab(dataService: _dataService),
          DashboardChartsTab(dataService: _dataService),
        ],
      ),
    );
  }
}