import 'package:flutter/material.dart';
import 'package:rise_for_prayer/utils/colors.dart';

class EthCross extends StatelessWidget {
  const EthCross({
    super.key,
    this.size = 28,
    this.color = AppColors.gold,
    this.opacity = 1.0,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size * 1.14,
        child: CustomPaint(painter: _EthCrossPainter(color: color)),
      ),
    );
  }
}

class _EthCrossPainter extends CustomPainter {
  const _EthCrossPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width, h = size.height;

    // Main vertical
    canvas.drawRect(Rect.fromLTWH(w * 0.43, 0, w * 0.14, h), paint);
    // Main horizontal
    canvas.drawRect(Rect.fromLTWH(0, h * 0.36, w, h * 0.14), paint);

    // Decorative arms
    canvas.drawRect(
      Rect.fromLTWH(w * 0.27, h * 0.14, w * 0.46, h * 0.07),
      paint..color = color.withValues(alpha: 0.65),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.07, h * 0.23, w * 0.30, h * 0.07),
      paint..color = color.withValues(alpha: 0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.63, h * 0.23, w * 0.30, h * 0.07),
      paint..color = color.withValues(alpha: 0.5),
    );

    // Inner diamond
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.36, h * 0.30, w * 0.29, h * 0.29),
        const Radius.circular(1),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Bottom base
    canvas.drawRect(
      Rect.fromLTWH(w * 0.30, h * 0.81, w * 0.39, h * 0.07),
      paint..color = color.withValues(alpha: 0.55),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.38, h * 0.89, w * 0.25, h * 0.05),
      paint..color = color.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
