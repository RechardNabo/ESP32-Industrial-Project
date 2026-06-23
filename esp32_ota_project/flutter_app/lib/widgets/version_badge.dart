/// @file version_badge.dart
/// @brief Badge widget displaying a firmware version number.
///
/// Shows version string with colored background — green for "up to date",
/// orange for "update available", grey for unknown.

import 'package:flutter/material.dart';

class VersionBadge extends StatelessWidget {
  final String version;
  final bool isUpToDate;
  final bool isUnknown;

  const VersionBadge({
    super.key,
    required this.version,
    this.isUpToDate = false,
    this.isUnknown = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    if (isUnknown) {
      bgColor = Colors.grey[300]!;
      textColor = Colors.grey[700]!;
      label = 'v$version';
    } else if (isUpToDate) {
      bgColor = Colors.green[100]!;
      textColor = Colors.green[800]!;
      label = 'v$version ✓';
    } else {
      bgColor = Colors.orange[100]!;
      textColor = Colors.orange[800]!;
      label = 'v$version ↑';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'RobotoMono',
            ),
      ),
    );
  }
}