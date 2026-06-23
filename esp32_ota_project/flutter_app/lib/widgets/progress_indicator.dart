/// @file progress_indicator.dart
/// @brief Upload progress indicator widget with speed and ETA display.
///
/// Shows a linear progress bar, transferred bytes, speed, and estimated
/// time remaining during firmware upload.

import 'package:flutter/material.dart';

class OtaProgressIndicator extends StatelessWidget {
  final double progress;
  final int bytesTransferred;
  final int totalBytes;
  final double speedBytesPerSecond;
  final Duration estimatedTimeRemaining;

  const OtaProgressIndicator({
    super.key,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.speedBytesPerSecond,
    required this.estimatedTimeRemaining,
  });

  /// Format bytes as human-readable (e.g. "184 KB", "1.2 MB").
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Format duration as "M:SS" or "Ss".
  static String formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '--';
    if (d.inMinutes == 0) return '${d.inSeconds}s';
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasSpeed = speedBytesPerSecond > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bytes transferred
            Text(
              '${formatBytes(bytesTransferred)} / ${formatBytes(totalBytes)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'RobotoMono',
                  ),
            ),
            // Speed
            if (hasSpeed)
              Text(
                '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            // ETA
            Text(
              'ETA: ${formatDuration(estimatedTimeRemaining)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ],
    );
  }
}