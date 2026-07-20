import 'package:flutter/material.dart';

/// Paints a decorative crescent moon with an optional golden glow.
///
/// Used as a standalone decorative element on the splash screen and
/// as a header ornament. For the small crescents atop minarets, use
/// [MosqueSilhouettePainter] instead.
class CrescentMoonPainter extends CustomPainter {
  /// Crescent fill colour (typically [NekiColors.gold]).
  final Color color;

  /// Blur radius for the soft glow behind the crescent.
  final double glowRadius;

  /// Opacity of the glow (0 = no glow, 1 = full opacity).
  final double glowOpacity;

  const CrescentMoonPainter({
    required this.color,
    this.glowRadius = 30,
    this.glowOpacity = 0.15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.shortestSide * 0.35;

    // ── Outer glow ──
    if (glowOpacity > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: glowOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawCircle(Offset(cx, cy), radius * 1.3, glowPaint);
    }

    // ── Crescent shape ──
    final outer = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    final inner = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(cx + radius * 0.4, cy - radius * 0.1),
        radius: radius * 0.78,
      ));
    final crescent = Path.combine(PathOperation.difference, outer, inner);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(CrescentMoonPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.glowRadius != glowRadius ||
        oldDelegate.glowOpacity != glowOpacity;
  }
}
