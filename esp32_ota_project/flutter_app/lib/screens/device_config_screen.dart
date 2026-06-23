/// @file device_config_screen.dart
/// @brief Device configuration screen — manage ESP32 device settings remotely.
///
/// Provides a tabbed interface for:
///   - Device overview (connection info, status)
///   - Heartbeat config (interval, tick count, LED pin)
///   - OTA firmware update (unlock, upload, progress)
///
/// User selects a device (from Discovery or manual IP entry), then uses
/// this screen to configure and update the device.

import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info.dart';
import '../models/firmware_version.dart';
import '../providers/upload_state.dart';
import '../services/binary_validator.dart';
import '../services/ota_http_service.dart';
import '../widgets/version_badge.dart';
import 'update_progress_screen.dart';

// ============================================================================
// Device Config Screen — top-level tabbed view
// ============================================================================

class DeviceConfigScreen extends ConsumerStatefulWidget {
  final DeviceInfo device;

  const DeviceConfigScreen({super.key, required this.device});

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _aliveTimer;
  int _lastTickCount = -1;
  int _staleCount = 0;
  bool _isAlive = false;
  bool _firstCheck = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startAliveMonitor();
  }

  @override
  void dispose() {
    _aliveTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Poll /heartbeat every 2 seconds. If tick_count changes → online.
  /// If tick_count stays the same for 3 consecutive polls → offline.
  void _startAliveMonitor() {
    _aliveTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final httpService = OtaHttpService(baseUrl: widget.device.baseUrl);
      try {
        final hb = await httpService.fetchHeartbeat();
        if (!mounted) return;
        final newTick = hb.tickCount ?? 0;
        if (_firstCheck) {
          _lastTickCount = newTick;
          _staleCount = 0;
          _isAlive = true;
          _firstCheck = false;
        } else if (newTick != _lastTickCount) {
          _staleCount = 0;
          _isAlive = true;
          _lastTickCount = newTick;
        } else {
          _staleCount++;
          if (_staleCount >= 3) _isAlive = false;
        }
        setState(() {});
      } catch (_) {
        if (!mounted) return;
        _isAlive = false;
        _staleCount = 3;
        setState(() {});
      } finally {
        httpService.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.device.hostname),
            const SizedBox(width: 12),
            // Online/Offline indicator
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isAlive ? Colors.green : Colors.red,
                boxShadow: _isAlive
                    ? [BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _firstCheck ? 'Checking\u2026' : (_isAlive ? 'Online' : 'Offline'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isAlive ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Overview'),
            Tab(icon: Icon(Icons.favorite), text: 'Heartbeat'),
            Tab(icon: Icon(Icons.system_update), text: 'OTA Update'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(device: widget.device),
          _HeartbeatTab(device: widget.device),
          _OtaUpdateTab(device: widget.device),
        ],
      ),
    );
  }
}

// ============================================================================
// Overview Tab
// ============================================================================

class _OverviewTab extends ConsumerStatefulWidget {
  final DeviceInfo device;
  const _OverviewTab({required this.device});

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  VersionCheckResult? _versionResult;
  DeviceStatusResult? _statusResult;
  HeartbeatResult? _heartbeatResult;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    debugPrint('[Overview] _fetchAll: START');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final httpService = OtaHttpService(baseUrl: widget.device.baseUrl);
    try {
      final results = await Future.wait([
        httpService.fetchVersion(),
        httpService.fetchStatus(),
        httpService.fetchHeartbeat(),
      ]);
      final v = results[0] as VersionCheckResult;
      final s = results[1] as DeviceStatusResult;
      final h = results[2] as HeartbeatResult;
      debugPrint('[Overview] _fetchAll: version=${v.version}, status=${s.success}, heartbeat=${h.success}');
      if (mounted) {
        setState(() {
          _versionResult = v;
          _statusResult = s;
          _heartbeatResult = h;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Overview] _fetchAll: ERROR: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch device info: $e';
          _isLoading = false;
        });
      }
    } finally {
      httpService.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _fetchAll, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection info
          _buildSectionCard(
            title: 'Connection',
            icon: Icons.wifi,
            children: [
              _buildInfoRow('Hostname', widget.device.hostname),
              _buildInfoRow('IP Address', widget.device.ipAddress),
              _buildInfoRow('Port', widget.device.port.toString()),
              _buildInfoRow('Base URL', widget.device.baseUrl),
            ],
          ),
          const SizedBox(height: 16),

          // Firmware version
          _buildSectionCard(
            title: 'Firmware',
            icon: Icons.verified,
            children: [
              Row(
                children: [
                  Text('Version', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                  const Spacer(),
                  VersionBadge(
                    version: _versionResult?.version?.toString() ?? '0.0.0',
                    isUnknown: _versionResult?.version == null,
                    isUpToDate: false,
                  ),
                ],
              ),
              if (_versionResult?.hostname != null)
                _buildInfoRow('Hostname (device)', _versionResult!.hostname!),
              if (_versionResult?.uptimeSeconds != null)
                _buildInfoRow('Uptime', _formatUptime(_versionResult!.uptimeSeconds!)),
            ],
          ),
          const SizedBox(height: 16),

          // System status
          if (_statusResult?.success == true)
            _buildSectionCard(
              title: 'System',
              icon: Icons.memory,
              children: [
                if (_statusResult!.freeHeap != null)
                  _buildInfoRow('Free Heap', _formatBytes(_statusResult!.freeHeap!)),
                if (_statusResult!.flashSize != null)
                  _buildInfoRow('Flash Size', _formatBytes(_statusResult!.flashSize!)),
                _buildInfoRow('Chip Model', _statusResult!.chipModel ?? 'Unknown'),
                _buildInfoRow('MAC', _statusResult!.mac ?? 'Unknown'),
                _buildInfoRow(
                  'OTA Session',
                  _statusResult!.otaUnlocked == true ? 'Unlocked' : 'Locked',
                ),
                if (_statusResult!.otaRemainingSeconds != null && _statusResult!.otaRemainingSeconds! > 0)
                  _buildInfoRow('OTA Expires In', '${_statusResult!.otaRemainingSeconds}s'),
              ],
            ),
          const SizedBox(height: 16),

          // Heartbeat summary
          if (_heartbeatResult?.success == true)
            _buildSectionCard(
              title: 'Heartbeat',
              icon: Icons.favorite,
              children: [
                if (_heartbeatResult!.intervalMs != null)
                  _buildInfoRow('Interval', '${_heartbeatResult!.intervalMs} ms'),
                if (_heartbeatResult!.tickCount != null)
                  _buildInfoRow('Tick Count', _heartbeatResult!.tickCount.toString()),
                if (_heartbeatResult!.ledPin != null)
                  _buildInfoRow('LED Pin', 'GPIO ${_heartbeatResult!.ledPin}'),
                _buildInfoRow('Running', (_heartbeatResult!.running ?? false) ? 'Yes' : 'No'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          Flexible(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'RobotoMono')),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatUptime(int seconds) {
    if (seconds < 60) return '$seconds s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}

// ============================================================================
// Heartbeat Config Tab
// ============================================================================

class _HeartbeatTab extends ConsumerStatefulWidget {
  final DeviceInfo device;
  const _HeartbeatTab({required this.device});

  @override
  ConsumerState<_HeartbeatTab> createState() => _HeartbeatTabState();
}

class _HeartbeatTabState extends ConsumerState<_HeartbeatTab> {
  HeartbeatResult? _heartbeat;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final TextEditingController _intervalController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Preset intervals
  static const List<int> _presets = [100, 200, 500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _fetchHeartbeat();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _fetchHeartbeat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final httpService = OtaHttpService(baseUrl: widget.device.baseUrl);
    try {
      final result = await httpService.fetchHeartbeat();
      if (mounted) {
        setState(() {
          _heartbeat = result;
          _intervalController.text = (result.intervalMs ?? 500).toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch heartbeat: $e';
          _isLoading = false;
        });
      }
    } finally {
      httpService.dispose();
    }
  }

  Future<void> _setInterval(int ms) async {
    setState(() => _isSaving = true);

    final httpService = OtaHttpService(baseUrl: widget.device.baseUrl);
    try {
      final result = await httpService.setHeartbeatInterval(ms);
      if (mounted) {
        if (result.success) {
          setState(() {
            _heartbeat = result;
            _intervalController.text = (result.intervalMs ?? ms).toString();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Heartbeat interval set to ${result.intervalMs} ms'),
              backgroundColor: Colors.green[700],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to set interval'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      httpService.dispose();
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _fetchHeartbeat, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHeartbeat,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Heartbeat Status', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (_heartbeat?.running == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Running', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.green[800], fontWeight: FontWeight.bold)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Stopped', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[700], fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const Divider(),
                  _buildInfoRow('Current Interval', '${_heartbeat?.intervalMs ?? "—"} ms'),
                  _buildInfoRow('Tick Count', '${_heartbeat?.tickCount ?? "—"}'),
                  _buildInfoRow('LED Pin', _heartbeat?.ledPin != null ? 'GPIO ${_heartbeat!.ledPin}' : '—'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Interval configuration card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Set Interval', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Range: 10 – 60,000 ms. Persisted to NVS — survives reboot and OTA.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),

                    // Custom interval input
                    TextFormField(
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Interval (ms)',
                        hintText: '500',
                        border: OutlineInputBorder(),
                        suffixText: 'ms',
                      ),
                      validator: (value) {
                        final v = int.tryParse(value ?? '');
                        if (v == null) return 'Enter a valid number';
                        if (v < 10) return 'Minimum is 10 ms';
                        if (v > 60000) return 'Maximum is 60,000 ms';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            _setInterval(int.parse(_intervalController.text));
                          }
                        },
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: const Text('Apply Interval'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick presets
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flash_on, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Quick Presets', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets.map((ms) => ChoiceChip(
                      label: Text('${ms} ms'),
                      selected: _heartbeat?.intervalMs == ms,
                      onSelected: _isSaving ? null : (_) => _setInterval(ms),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }
}

// ============================================================================
// OTA Update Tab (streamlined from DeviceDetailScreen)
// ============================================================================

class _OtaUpdateTab extends ConsumerStatefulWidget {
  final DeviceInfo device;
  const _OtaUpdateTab({required this.device});

  @override
  ConsumerState<_OtaUpdateTab> createState() => _OtaUpdateTabState();
}

class _OtaUpdateTabState extends ConsumerState<_OtaUpdateTab> {
  VersionCheckResult? _versionResult;
  DeviceStatusResult? _statusResult;
  bool _isLoadingInfo = true;
  String? _infoError;
  PlatformFile? _selectedFile;
  Uint8List? _selectedFileBytes; // web: bytes read separately
  String? _selectedFilePath;
  ValidationResult? _validationResult;
  FirmwareVersion? _fileVersion;
  bool _forceDowngrade = false;
  String _otaToken = '';



  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
  }

  Future<void> _fetchDeviceInfo() async {
    debugPrint('[OTA] _fetchDeviceInfo: START');
    setState(() {
      _isLoadingInfo = true;
      _infoError = null;
    });

    final httpService = OtaHttpService(baseUrl: widget.device.baseUrl);
    try {
      debugPrint('[OTA] _fetchDeviceInfo: fetching version from ${widget.device.baseUrl}');
      final version = await httpService.fetchVersion();
      debugPrint('[OTA] _fetchDeviceInfo: version result = success=${version.success}, version=${version.version}');
      final status = await httpService.fetchStatus();
      debugPrint('[OTA] _fetchDeviceInfo: status result = success=${status.success}');
      httpService.dispose();
      if (mounted) {
        setState(() {
          _versionResult = version;
          _statusResult = status;
          _isLoadingInfo = false;
        });
      }
      debugPrint('[OTA] _fetchDeviceInfo: DONE');
    } catch (e) {
      debugPrint('[OTA] _fetchDeviceInfo: ERROR: $e');
      if (mounted) {
        setState(() {
          _infoError = 'Failed to connect: $e';
          _isLoadingInfo = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    debugPrint('[OTA] _pickFile: START (kIsWeb=$kIsWeb)');
    FilePickerResult? result;
    try {
      debugPrint('[OTA] _pickFile: opening file picker');
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: true, // Needed to load bytes on all platforms
      );
      debugPrint('[OTA] _pickFile: picker returned ${result != null ? "${result.files.length} file(s)" : "null"}');
    } catch (e) {
      debugPrint('[OTA] _pickFile: picker ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: $e'), backgroundColor: Colors.red[700]),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) {
      debugPrint('[OTA] _pickFile: no file selected');
      return;
    }

    final platformFile = result.files.first;
    debugPrint('[OTA] _pickFile: file=${platformFile.name}, size=${platformFile.size}, bytes=${platformFile.bytes != null ? platformFile.bytes!.length : 'null'}');

    // On web + withData:true: bytes are in platformFile.bytes
    // On native + withData:true: bytes are also in platformFile.bytes
    final Uint8List fileBytes = platformFile.bytes!;

    ValidationResult? validation;
    try {
      debugPrint('[OTA] _pickFile: validating ${fileBytes.length} bytes...');
      validation = BinaryValidator.validateBytes(fileBytes, fileSize: platformFile.size);
      debugPrint('[OTA] _pickFile: validation result = isValid=${validation.isValid}, fileSize=${validation.fileSize}, error=${validation.errorMessage}');
    } catch (e) {
      debugPrint('[OTA] _pickFile: validation ERROR: $e');
      validation = ValidationResult.invalid('Validation error: $e');
    }

    if (!mounted) {
      debugPrint('[OTA] _pickFile: widget no longer mounted, aborting');
      return;
    }
    setState(() {
      _selectedFile = platformFile;
      _selectedFileBytes = fileBytes;
      _selectedFilePath = kIsWeb ? null : platformFile.path; // path throws on web
      _validationResult = validation;
      _fileVersion = null;
      _forceDowngrade = false;
    });
    debugPrint('[OTA] _pickFile: setState done, _validationResult=${_validationResult?.isValid}');

    final versionMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(platformFile.name);
    if (versionMatch != null) {
      setState(() {
        _fileVersion = FirmwareVersion.parse(versionMatch.group(1)!);
      });
    }
    debugPrint('[OTA] _pickFile: DONE');
  }

  bool get _canStartUpdate {
    final hasFile = _selectedFile != null;
    final hasValid = _validationResult != null && _validationResult!.isValid;
    final hasToken = _otaToken.isNotEmpty;
    final hasData = _selectedFile != null &&
        (_selectedFilePath != null ||
            (_selectedFileBytes != null && _selectedFileBytes!.isNotEmpty));
    final versionOk = !(_versionResult?.success == true && _versionResult?.version != null && _fileVersion != null && !_fileVersion!.isNewerThan(_versionResult!.version!) && !_forceDowngrade);
    if (!hasFile) return false;
    if (!hasValid) return false;
    if (!hasToken) return false;
    if (!hasData) return false;
    if (!versionOk) return false;
    return true;
  }

  bool get _isVersionWarning {
    if (_versionResult?.success != true || _fileVersion == null) return false;
    final version = _versionResult?.version;
    if (version == null) return false;
    return !_fileVersion!.isNewerThan(version);
  }

  void _startUpdate() {
    ref.read(selectedDeviceProvider.notifier).state = widget.device;
    final filePath = _selectedFilePath ?? _selectedFile!.name;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpdateProgressScreen(
          device: widget.device,
          token: _otaToken,
          binFilePath: filePath,
          binFileBytes: _selectedFileBytes ?? _selectedFile!.bytes,
          binFileName: _selectedFile!.name,
          oldVersion: _versionResult?.version ?? FirmwareVersion(0, 0, 0),
          newVersion: _fileVersion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInfo) {
      debugPrint('[OTA] build: showing loading spinner');
      return const Center(child: CircularProgressIndicator());
    }

    if (_infoError != null) {
      debugPrint('[OTA] build: showing error: $_infoError');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_infoError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _fetchDeviceInfo, child: const Text('Retry')),
          ],
        ),
      );
    }

    final isUnlocked = _statusResult?.otaUnlocked ?? false;
    final remaining = _statusResult?.otaRemainingSeconds ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version + OTA status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.verified, size: 32, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Firmware Version', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        VersionBadge(
                          version: _versionResult?.version?.toString() ?? '0.0.0',
                          isUnknown: _versionResult?.version == null,
                          isUpToDate: false,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Unlocked', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.orange[800], fontWeight: FontWeight.bold)),
                        ),
                      if (remaining > 0)
                        Text('$remaining s left', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.orange)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // File picker
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Firmware Binary', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_selectedFile == null ? 'Select .bin File' : 'Change File'),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 12),
                    _buildFileInfo(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // OTA token
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OTA Token', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Enter the pre-shared token to unlock the OTA session',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _otaToken = value),
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Token',
                      hintText: 'SecretFlash2026',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Version override warning
          if (_isVersionWarning && _fileVersion != null && !_forceDowngrade)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected version is not newer than device version',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          if (_isVersionWarning && _fileVersion != null)
            Row(
              children: [
                Switch(
                  value: _forceDowngrade,
                  onChanged: (v) => setState(() => _forceDowngrade = v),
                ),
                const Expanded(child: Text('Force update (override version check)')),
              ],
            ),
          if (_isVersionWarning && _fileVersion != null && !_forceDowngrade)
            const SizedBox(height: 12),

          // Update button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canStartUpdate ? _startUpdate : null,
              icon: const Icon(Icons.system_update),
              label: const Text('Begin OTA Update'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    final validation = _validationResult;
    final fileName = _selectedFile?.name ?? 'unknown.bin';

    if (validation == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text('Validating...', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: validation.isValid ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: validation.isValid ? Colors.green[200]! : Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(validation.isValid ? Icons.check_circle : Icons.error,
                  color: validation.isValid ? Colors.green : Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(fileName, style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (validation.isValid && validation.fileSize != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_formatSize(validation.fileSize!)} — Valid ESP32 binary',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green[700]),
            ),
            if (_fileVersion != null) ...[
              const SizedBox(height: 2),
              Text(
                'Version from filename: ${_fileVersion!.toString()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ],
          if (!validation.isValid) ...[
            const SizedBox(height: 4),
            Text(validation.errorMessage ?? 'Validation failed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red[700])),
          ],
        ],
      ),
    );
  }
}