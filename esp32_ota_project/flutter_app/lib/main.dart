/// @file main.dart
/// @brief Entry point for the ESP32 OTA Updater Flutter application.
///
/// Initialises Riverpod, requests necessary permissions (iOS local network),
/// and launches the main shell with bottom navigation between
/// Discovery and Settings tabs.


import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/device_info.dart';
import 'screens/discovery_screen.dart';
import 'screens/device_config_screen.dart';
import 'screens/dashboard_screen.dart';

/// Global key for accessing the navigator state from error handlers
final _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch Flutter framework errors (null assertions, type errors, etc.)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kIsWeb) {
      // Log to browser console for easy debugging
      print('=== FLUTTER ERROR ===');
      print(details.exceptionAsString());
      print(details.stack?.toString() ?? 'No stack trace');
      print('=== END FLUTTER ERROR ===');
    }
  };

  runApp(const ProviderScope(child: Esp32OtaApp()));
}

class Esp32OtaApp extends ConsumerStatefulWidget {
  const Esp32OtaApp({super.key});

  @override
  ConsumerState<Esp32OtaApp> createState() => _Esp32OtaAppState();
}

class _Esp32OtaAppState extends ConsumerState<Esp32OtaApp> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  /// Request iOS local network permission (required for mDNS discovery).
  /// On Android and desktop, this is a no-op.
  /// On web, permission_handler is not supported, so skip entirely.
  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    await Permission.locationWhenInUse.request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ESP32 OTA Updater',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      home: const MainShell(),
    );
  }
}

/// Main shell with bottom navigation bar and two tabs:
///   - Discover: mDNS device discovery + manual IP
///   - Device Config: connect to a specific device, view status, configure
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  /// Device selected from Discovery tab — navigated to config
  final List<DeviceInfo> _recentDevices = [];
  DeviceInfo? _connectedDevice; // Currently connected device for Dashboard

  void _navigateToDeviceConfig(DeviceInfo device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceConfigScreen(device: device),
      ),
    );
  }

  void _navigateToDashboard(DeviceInfo device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(device: device),
      ),
    );
  }

  /// Set the connected device for the Dashboard tab
  void _setConnectedDevice(DeviceInfo device) {
    setState(() {
      _connectedDevice = device;
      _currentIndex = 2; // Switch to Dashboard tab
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Device Discovery
          DiscoveryScreen(onDeviceTap: _navigateToDeviceConfig),
          // Tab 1: Quick Device Config (manual IP entry)
          _QuickConfigTab(onConnect: _setConnectedDevice),
          // Tab 2: Dashboard (if device connected)
          _connectedDevice != null
              ? DashboardScreen(device: _connectedDevice!)
              : _NoDevicePlaceholder(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.wifi_tethering_outlined),
            selectedIcon: Icon(Icons.wifi_tethering),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Device Config',
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}

/// Quick config tab — manual IP entry for direct device connection.
/// Shows recent devices (if any) and provides a connect form.
class _QuickConfigTab extends ConsumerStatefulWidget {
  final void Function(DeviceInfo) onConnect;

  const _QuickConfigTab({required this.onConnect});

  @override
  ConsumerState<_QuickConfigTab> createState() => _QuickConfigTabState();
}

class _QuickConfigTabState extends ConsumerState<_QuickConfigTab> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '80');

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Configuration'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon and description
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.settings_remote,
                      size: 40,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Configure ESP32 Device',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your device IP address to connect.\n'
                    'You can also discover devices from the Discover tab.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Manual IP entry card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lan, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Manual Connection', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                              prefixIcon: Icon(Icons.numbers),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final ip = _ipController.text.trim();
                          final port = int.tryParse(_portController.text.trim()) ?? 80;
                          if (ip.isEmpty) return;
                          final device = DeviceInfo(
                            hostname: 'esp32-$ip',
                            ipAddress: ip,
                            port: port,
                            lastSeen: DateTime.now(),
                          );
                          widget.onConnect(device);
                        },
                        icon: const Icon(Icons.connect_without_contact),
                        label: const Text('Connect & Configure'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Help section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('How It Works', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHelpStep(1, 'Enter the device IP and port (default 80)'),
                    _buildHelpStep(2, 'Configure heartbeat interval and view system status'),
                    _buildHelpStep(3, 'Enter OTA token and upload .bin firmware file'),
                    const SizedBox(height: 8),
                    Text(
                      'The device must be on the same Wi-Fi network. '
                      'Use the Discover tab to auto-find devices via mDNS.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
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

  Widget _buildHelpStep(int step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown when Dashboard tab is selected but no device is connected.
class _NoDevicePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No Device Connected', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Enter your device IP in the Device Config tab\nto start the live dashboard.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}