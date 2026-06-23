/// @file device_detail_screen.dart
/// @brief Device detail screen — shows device info and triggers OTA update.
///
/// Displays firmware version, device status, file picker for .bin selection,
/// pre-flight validation, and version gating. The "Begin OTA Update" button
/// triggers the unlock + upload workflow.

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

class DeviceDetailScreen extends ConsumerStatefulWidget {
  final DeviceInfo device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  VersionCheckResult? _versionResult;
  DeviceStatusResult? _statusResult;
  bool _isLoadingInfo = true;
  String? _infoError;

  // Selected firmware file state
  PlatformFile? _selectedFile;
  Uint8List? _selectedFileBytes; // web: bytes read separately
  String? _selectedFilePath; // Native file path (null on web)
  ValidationResult? _validationResult;
  FirmwareVersion? _fileVersion;
  bool _forceDowngrade = false;
  String _otaToken = '';

  /// Format bytes as human-readable (e.g. "184 KB", "1.2 MB").
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
    setState(() {
      _isLoadingInfo = true;
      _infoError = null;
    });

    try {
      final httpService = OtaHttpService(baseUrl: widget.device.baseUrl);
      final version = await httpService.fetchVersion();
      final status = await httpService.fetchStatus();
      httpService.dispose();

      if (mounted) {
        setState(() {
          _versionResult = version;
          _statusResult = status;
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _infoError = 'Failed to connect: $e';
          _isLoadingInfo = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: $e'), backgroundColor: Colors.red[700]),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final platformFile = result.files.first;
    // withData:true loads bytes on all platforms; on web, .path throws so never access it
    final Uint8List fileBytes = platformFile.bytes!;

    // Validate using loaded bytes
    ValidationResult? validation;
    try {
      validation = BinaryValidator.validateBytes(fileBytes, fileSize: platformFile.size);
    } catch (e) {
      validation = ValidationResult.invalid('Validation error: $e');
    }

    if (!mounted) return;
    setState(() {
      _selectedFile = platformFile;
      _selectedFileBytes = fileBytes;
      _selectedFilePath = kIsWeb ? null : platformFile.path;
      _validationResult = validation;
      _fileVersion = null;
      _forceDowngrade = false;
    });

    // Try to extract version from filename pattern (e.g. firmware_1.2.3.bin)
    final versionMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(platformFile.name);
    if (versionMatch != null) {
      setState(() {
        _fileVersion = FirmwareVersion.parse(versionMatch.group(1)!);
      });
    }
  }

  bool get _canStartUpdate {
    if (_selectedFile == null) return false;
    if (_validationResult == null || !_validationResult!.isValid) return false;
    if (_otaToken.isEmpty) return false;
    // Must have either a file path (native) or file bytes (web)
    final hasData = _selectedFilePath != null ||
        (_selectedFileBytes != null && _selectedFileBytes!.isNotEmpty);
    if (!hasData) return false;

    // Version gate: block if file version <= device version unless forced
    if (_versionResult?.success == true && _versionResult?.version != null && _fileVersion != null) {
      final deviceVer = _versionResult!.version!;
      if (!_fileVersion!.isNewerThan(deviceVer) && !_forceDowngrade) {
        return false;
      }
    }

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

    // Use file path on native, file name fallback on web
    final filePath = _selectedFilePath ?? _selectedFile!.name;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UpdateProgressScreen(
          device: widget.device,
          token: _otaToken,
          binFilePath: filePath,
          binFileBytes: _selectedFileBytes ?? _selectedFile!.bytes, // web bytes or native fallback
          binFileName: _selectedFile!.name,
          oldVersion: _versionResult?.version ?? FirmwareVersion(0, 0, 0),
          newVersion: _fileVersion,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.hostname),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDeviceInfo,
            tooltip: 'Refresh device info',
          ),
        ],
      ),
      body: _isLoadingInfo
          ? const Center(child: CircularProgressIndicator())
          : _infoError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_infoError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: _fetchDeviceInfo,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device info card
          _buildDeviceInfoCard(),
          const SizedBox(height: 20),

          // Firmware version section
          _buildVersionSection(),
          const SizedBox(height: 20),

          // File picker section
          _buildFilePickerSection(),
          const SizedBox(height: 20),

          // OTA token input
          _buildTokenSection(),
          const SizedBox(height: 24),

          // Update button
          _buildUpdateButton(),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device Information', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _buildInfoRow('Hostname', widget.device.hostname),
            _buildInfoRow('IP Address', widget.device.ipAddress),
            _buildInfoRow('Port', widget.device.port.toString()),
            if (_statusResult?.success == true) ...[
              _buildInfoRow('Free Heap', '${_statusResult!.freeHeap} bytes'),
              _buildInfoRow('Flash Size', '${(_statusResult!.flashSize! / 1024).round()} KB'),
              _buildInfoRow('Chip Model', _statusResult!.chipModel ?? 'Unknown'),
              _buildInfoRow('MAC', _statusResult!.mac ?? 'Unknown'),
            ],
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
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'RobotoMono')),
        ],
      ),
    );
  }

  Widget _buildVersionSection() {
    final version = _versionResult?.version;
    final isUnlocked = _statusResult?.otaUnlocked ?? false;

    return Card(
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
                    version: version?.toString() ?? '0.0.0',
                    isUnknown: version == null,
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
                    child: Text(
                      'Unlocked',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                if (_statusResult?.otaRemainingSeconds != null && _statusResult!.otaRemainingSeconds! > 0)
                  Text(
                    '${_statusResult!.otaRemainingSeconds}s left',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.orange),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerSection() {
    return Card(
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
    );
  }

  Widget _buildFileInfo() {
    final validation = _validationResult;
    // Use .name (available on all platforms) instead of .path.split
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
        border: Border.all(
          color: validation.isValid ? Colors.green[200]! : Colors.red[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                validation.isValid ? Icons.check_circle : Icons.error,
                color: validation.isValid ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (validation.isValid && validation.fileSize != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_formatSize(validation.fileSize!)} — Valid ESP32 binary',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green[700],
                  ),
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
            Text(
              validation.errorMessage ?? 'Validation failed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTokenSection() {
    return Card(
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
    );
  }

  Widget _buildUpdateButton() {
    final canStart = _canStartUpdate;
    final isVersionWarning = _isVersionWarning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isVersionWarning && _fileVersion != null && !_forceDowngrade) ...[
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
                    'Already up to date — selected version is not newer than device version',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Switch(
                value: _forceDowngrade,
                onChanged: (v) => setState(() => _forceDowngrade = v),
              ),
              const Expanded(child: Text('Force update (override version check)')),
            ],
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: canStart ? _startUpdate : null,
          icon: const Icon(Icons.system_update),
          label: const Text('Begin OTA Update'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}