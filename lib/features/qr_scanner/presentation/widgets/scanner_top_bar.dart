import 'package:flutter/material.dart';

/// A frosted, translucent circular icon button floating over the camera
/// preview — the scanner's whole control vocabulary (back, search,
/// torch) is built from this one shape instead of a titled pill bar, so
/// controls read as a camera app's chrome rather than a page header
/// pasted onto a live feed.
class ScannerIconButton extends StatelessWidget {
  const ScannerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Tints the button with the theme's accent when the control it
  /// represents is toggled on (e.g. torch).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active
          ? scheme.primary
          : Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          icon: Icon(
            icon,
            color: active ? scheme.onPrimary : Colors.white,
            size: 22,
          ),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
