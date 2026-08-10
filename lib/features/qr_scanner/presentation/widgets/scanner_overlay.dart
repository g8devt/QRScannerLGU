import 'package:flutter/material.dart';

/// Rounded-square frame with corner brackets, drawn over the camera
/// preview to show the user where to align the QR code.
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: CustomPaint(painter: _CornerBracketsPainter()),
        ),
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  static const double _bracketLength = 28;
  static const double _inset = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void bracket(Offset corner, Offset dx, Offset dy) {
      canvas.drawLine(corner, corner + dx, paint);
      canvas.drawLine(corner, corner + dy, paint);
    }

    final w = size.width;
    final h = size.height;

    bracket(
      Offset(_inset, _inset),
      const Offset(_bracketLength, 0),
      const Offset(0, _bracketLength),
    );
    bracket(
      Offset(w - _inset, _inset),
      const Offset(-_bracketLength, 0),
      const Offset(0, _bracketLength),
    );
    bracket(
      Offset(_inset, h - _inset),
      const Offset(_bracketLength, 0),
      const Offset(0, -_bracketLength),
    );
    bracket(
      Offset(w - _inset, h - _inset),
      const Offset(-_bracketLength, 0),
      const Offset(0, -_bracketLength),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
