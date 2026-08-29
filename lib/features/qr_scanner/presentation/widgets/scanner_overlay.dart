import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Rounded-square frame with bold corner brackets and a sweeping scan
/// line, drawn over the camera preview to show the user where to align
/// the QR code and that a scan is actively in progress. Everything
/// outside the frame is dimmed so the eye is pulled straight to the
/// active scan area, and the frame briefly tints to the app's success
/// color for the one frame a code has just been [isDetected] — a purely
/// visual cue that a scan landed, distinct from the steady neutral look
/// while still searching (the sweep also stops the instant that happens).
class ScannerOverlay extends StatefulWidget {
  const ScannerOverlay({super.key, this.isDetected = false});

  final bool isDetected;

  static const double margin = 48;
  static const double cornerRadius = 28;

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDetected
        ? Theme.of(context).extension<AppStatusColors>()!.success
        : Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = math.min(constraints.maxWidth, constraints.maxHeight);
        final side = math.max(0.0, maxSide - ScannerOverlay.margin * 2);
        final frameRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: side,
          height: side,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _DimMaskPainter(
                frameRect: frameRect,
                radius: ScannerOverlay.cornerRadius,
              ),
            ),
            CustomPaint(
              painter: _FramePainter(
                frameRect: frameRect,
                radius: ScannerOverlay.cornerRadius,
                color: accent,
              ),
            ),
            if (!widget.isDetected)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ScanLinePainter(
                    frameRect: frameRect,
                    progress: _controller.value,
                    color: accent,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Darkens everything outside [frameRect] so the scan window reads as
/// the clear focal point rather than one shape among several on top of
/// a busy camera feed.
class _DimMaskPainter extends CustomPainter {
  const _DimMaskPainter({required this.frameRect, required this.radius});

  final Rect frameRect;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, Radius.circular(radius)));
    final mask = Path.combine(PathOperation.difference, outer, hole);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant _DimMaskPainter oldDelegate) =>
      oldDelegate.frameRect != frameRect || oldDelegate.radius != radius;
}

/// Draws the frame's rounded border plus its four bold, rounded-cap
/// corner brackets in [color], scaled to [frameRect] — thicker and more
/// confident than a hairline square, matching a modern scanner app's
/// corner-mark language rather than a generic dashed outline.
class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.frameRect,
    required this.radius,
    required this.color,
  });

  final Rect frameRect;
  final double radius;
  final Color color;

  static const double _bracketLength = 36;
  static const double _inset = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, Radius.circular(radius)),
      borderPaint,
    );

    final bracketPaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void bracket(Offset corner, Offset dx, Offset dy) {
      canvas.drawLine(corner, corner + dx, bracketPaint);
      canvas.drawLine(corner, corner + dy, bracketPaint);
    }

    final left = frameRect.left + _inset;
    final top = frameRect.top + _inset;
    final right = frameRect.right - _inset;
    final bottom = frameRect.bottom - _inset;

    bracket(
      Offset(left, top),
      const Offset(_bracketLength, 0),
      const Offset(0, _bracketLength),
    );
    bracket(
      Offset(right, top),
      const Offset(-_bracketLength, 0),
      const Offset(0, _bracketLength),
    );
    bracket(
      Offset(left, bottom),
      const Offset(_bracketLength, 0),
      const Offset(0, -_bracketLength),
    );
    bracket(
      Offset(right, bottom),
      const Offset(-_bracketLength, 0),
      const Offset(0, -_bracketLength),
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.frameRect != frameRect ||
      oldDelegate.radius != radius ||
      oldDelegate.color != color;
}

/// A soft, glowing horizontal line that sweeps top-to-bottom (and back)
/// inside the frame while actively scanning — the one motion cue on
/// this screen, communicating "still looking" rather than a static
/// frame that gives no feedback while nothing has happened yet.
class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter({
    required this.frameRect,
    required this.progress,
    required this.color,
  });

  final Rect frameRect;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = frameRect.deflate(6);
    final y = inset.top + inset.height * progress;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(inset.left, y - 1, inset.width, 2))
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawLine(Offset(inset.left, y), Offset(inset.right, y), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.frameRect != frameRect ||
      oldDelegate.color != color;
}
