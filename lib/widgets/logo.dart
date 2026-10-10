import 'package:flutter/material.dart';
import '../theme.dart';

/// Shield + person monogram, drawn to match the original 64x72 SVG.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 58, this.color = AppColors.blue});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 72 / 64,
      child: CustomPaint(painter: _LogoPainter(color)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shield = Path()
      ..moveTo(32 * s, 3 * s)
      ..lineTo(57 * s, 12 * s)
      ..lineTo(57 * s, 32 * s)
      ..cubicTo(57 * s, 50 * s, 47 * s, 61 * s, 32 * s, 69 * s)
      ..cubicTo(17 * s, 61 * s, 7 * s, 50 * s, 7 * s, 32 * s)
      ..lineTo(7 * s, 12 * s)
      ..close();
    canvas.drawPath(shield, paint);
    canvas.drawCircle(Offset(32 * s, 29 * s), 9 * s, paint);
    canvas.drawLine(Offset(20 * s, 51 * s), Offset(44 * s, 51 * s), paint);
    canvas.drawLine(Offset(32 * s, 38 * s), Offset(32 * s, 51 * s), paint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
