/// @file update_progress_screen.dart
/// @brief Full-screen OTA progress display — cannot be dismissed during upload.
///
/// Shows the four-phase pipeline (Unlocking → Validating → Uploading → Rebooting)
/// with a linear progress bar, transfer speed, ETA, and success/failure states.
/// Uses WillPopScope to prevent accidental back-navigation during upload.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info.dart';
import '../models/firmware_version.dart';
import '../providers/upload_state.dart';
import '../widgets/progress_indicator.dart';

class UpdateProgressScreen extends ConsumerStatefulWidget {
  final DeviceInfo device;
  final String token;
  final String binFilePath;
  final List<int>? binFileBytes; // For web platform
  final String? binFileName;     // For web platform
  final FirmwareVersion oldVersion;
  final FirmwareVersion? newVersion;

  const UpdateProgressScreen({
    super.key,
    required this.device,
    required this.token,
    required this.binFilePath,
    this.binFileBytes,
    this.binFileName,
    required this.oldVersion,
    this.newVersion,
  });

  @override
  ConsumerState<UpdateProgressScreen> createState() => _UpdateProgressScreenState();
}

class _UpdateProgressScreenState extends ConsumerState<UpdateProgressScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Start the OTA update after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) => _startUpdate());
  }

  void _startUpdate() {
    if (_started) return;
    _started = true;

    final notifier = ref.read(uploadStateProvider.notifier);
    notifier.startUpdate(
      device: widget.device,
      token: widget.token,
      binFilePath: widget.binFilePath,
      binFileBytes: widget.binFileBytes,
      binFileName: widget.binFileName,
      oldVersion: widget.oldVersion,
      newVersion: widget.newVersion,
    );
  }

  /// Map upload state to a phase label.
  String get _phaseLabel {
    final state = ref.watch(uploadStateProvider);
    return switch (state) {
      UploadIdle() => 'Preparing...',
      UploadUnlocking() => 'Unlocking',
      UploadUploading() => 'Uploading',
      UploadSuccess() => 'Rebooting',
      UploadFailure() => 'Failed',
    };
  }

  /// Map upload state to a phase index (0-3).
  int get _phaseIndex {
    final state = ref.watch(uploadStateProvider);
    return switch (state) {
      UploadIdle() => 0,
      UploadUnlocking() => 1,
      UploadUploading() => 2,
      UploadSuccess() => 3,
      UploadFailure() => -1,
    };
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadStateProvider);
    final isUploading = uploadState is UploadUnlocking || uploadState is UploadUploading;

    return PopScope(
      canPop: !isUploading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OTA Update'),
          automaticallyImplyLeading: !isUploading,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: uploadState is UploadIdle
              ? const Center(child: CircularProgressIndicator())
              : uploadState is UploadUnlocking
                  ? _buildUnlockingState()
                  : uploadState is UploadUploading
                      ? _buildUploadingState(uploadState)
                      : uploadState is UploadSuccess
                          ? _buildSuccessState(uploadState)
                          : uploadState is UploadFailure
                              ? _buildFailureState(uploadState)
                              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildUnlockingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          _buildPhaseIndicator(phase: 1),
          const SizedBox(height: 16),
          Text(
            'Unlocking OTA session...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sending authentication token to ${widget.device.hostname}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingState(UploadUploading state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPhaseIndicator(phase: 2),
          const SizedBox(height: 24),
          Text(
            'Uploading Firmware',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          OtaProgressIndicator(
            progress: state.progress,
            bytesTransferred: state.bytesTransferred,
            totalBytes: state.totalBytes,
            speedBytesPerSecond: state.speedBytesPerSecond,
            estimatedTimeRemaining: state.estimatedTimeRemaining,
          ),
          const SizedBox(height: 24),
          Text(
            '${(state.progress * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Do not navigate away or power off the device',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(UploadSuccess state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPhaseIndicator(phase: 3),
          const SizedBox(height: 32),
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Update Successful!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Device rebooted successfully',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.versionChangeLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              ref.read(uploadStateProvider.notifier).reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text('Return to Discovery'),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureState(UploadFailure state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
      children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Update Failed',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
          ),
          const SizedBox(height: 12),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (state.technicalDetail != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Technical Details'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.technicalDetail!,
                    style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(uploadStateProvider.notifier).reset();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.read(uploadStateProvider.notifier).reset();
                  _startUpdate();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ],
    ),
    );
  }

  /// Four-phase indicator showing Unlocking → Validating → Uploading → Rebooting.
  Widget _buildPhaseIndicator({required int phase}) {
    final phases = ['Unlock', 'Validate', 'Upload', 'Reboot'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(phases.length, (i) {
        final isActive = i < phase;
        final isCurrent = i == phase;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green
                    : isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isActive
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : isCurrent
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
              ),
            ),
            if (i < phases.length - 1)
              Container(
                width: 40,
                height: 2,
                color: isActive ? Colors.green : Colors.grey[300],
              ),
          ],
        );
      }),
    );
  }
}