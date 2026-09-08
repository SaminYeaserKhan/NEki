import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/neki_colors.dart';

/// Paints ornate hanging Islamic lanterns (Fanous) that sway gently
/// with a warm flickering candle glow inside.
class HangingLanternsPainter extends CustomPainter {
  /// Progress of the sway animation (0.0 to 1.0).
  final double animationValue;

  /// Time of day in hours (0–23).
  final int hour;

  const HangingLanternsPainter({
    required this.animationValue,
    required this.hour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Sway angles (radians) using smooth sine oscillation
    final leftAngle = sin(animationValue * 2 * pi) * 0.035;
    final rightAngle = sin((animationValue * 2 * pi) + (pi * 0.5)) * 0.028;

    // Flicker intensity for candlelight (0.75 to 1.0)
    final flicker = 0.85 + 0.15 * sin(animationValue * 6 * pi);

    // Left Lantern (top-left, chain length ~ 120)
    _drawHangingLantern(
      canvas: canvas,
      pivotX: size.width * 0.14,
      chainLength: 105,
      lanternWidth: 32,
      lanternHeight: 64,
      angle: leftAngle,
      flicker: flicker,
    );

    // Right Lantern (top-right, chain length ~ 145)
    _drawHangingLantern(
      canvas: canvas,
      pivotX: size.width * 0.86,
      chainLength: 135,
      lanternWidth: 28,
      lanternHeight: 56,
      angle: rightAngle,
      flicker: flicker,
    );
  }

  void _drawHangingLantern({
    required Canvas canvas,
    required double pivotX,
    required double chainLength,
    required double lanternWidth,
    required double lanternHeight,
    required double angle,
    required double flicker,
  }) {
    canvas.save();
    // Pivot at top edge of screen
    canvas.translate(pivotX, 0);
    canvas.rotate(angle);

    final goldColor = NekiColors.goldLight;
    final bodyStrokeColor = goldColor.withValues(alpha: 0.5);

    // 1. Chain from ceiling to lantern top
    final chainPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw small chain dots/links
    const linkSpacing = 7.0;
    final numLinks = (chainLength / linkSpacing).floor();
    for (int i = 0; i < numLinks; i++) {
      final y = i * linkSpacing;
      canvas.drawCircle(Offset(0, y), 1.2, chainPaint);
    }

    final topY = chainLength;

    // 2. Hanging Ring / Crescent on top of lantern
    final ringPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(Offset(0, topY - 5), 4, ringPaint);

    // 3. Ambient candlelight glow
    final candleCenter = Offset(0, topY + lanternHeight * 0.48);
    final glowRadius = lanternWidth * 1.8 * flicker;
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.18 * flicker)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.6);
    canvas.drawCircle(candleCenter, glowRadius, glowPaint);

    // 4. Lantern Top Dome / Cap
    final capPath = Path();
    capPath.moveTo(-lanternWidth * 0.35, topY + 8);
    capPath.quadraticBezierTo(0, topY - 2, lanternWidth * 0.35, topY + 8);
    capPath.lineTo(lanternWidth * 0.5, topY + 12);
    capPath.lineTo(-lanternWidth * 0.5, topY + 12);
    capPath.close();

    final capFill = Paint()
      ..color = const Color(0xFF1E3A2C).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final capStroke = Paint()
      ..color = bodyStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(capPath, capFill);
    canvas.drawPath(capPath, capStroke);

    // 5. Glass Body with multi-facet panes
    final bodyTopY = topY + 12;
    final bodyBottomY = topY + lanternHeight - 14;
    final halfW = lanternWidth * 0.5;
    final midW = lanternWidth * 0.62;
    final midY = (bodyTopY + bodyBottomY) * 0.5;

    final bodyPath = Path()
      ..moveTo(-halfW, bodyTopY)
      ..lineTo(halfW, bodyTopY)
      ..lineTo(midW, midY)
      ..lineTo(halfW * 0.85, bodyBottomY)
      ..lineTo(-halfW * 0.85, bodyBottomY)
      ..lineTo(-midW, midY)
      ..close();

    // Glass translucent tinted fill
    final glassFill = Paint()
      ..color = const Color(0xFFFFF8E1).withValues(alpha: 0.12 * flicker)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, glassFill);

    // Ribs / Windows
    final ribPaint = Paint()
      ..color = bodyStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawPath(bodyPath, ribPaint);

    // Center vertical ribs
    canvas.drawLine(
      Offset(-halfW * 0.35, bodyTopY),
      Offset(-halfW * 0.3, bodyBottomY),
      ribPaint,
    );
    canvas.drawLine(
      Offset(halfW * 0.35, bodyTopY),
      Offset(halfW * 0.3, bodyBottomY),
      ribPaint,
    );
    canvas.drawLine(
      Offset(-midW, midY),
      Offset(midW, midY),
      ribPaint..strokeWidth = 0.8,
    );

    // 6. Candle flame inside
    final flamePaint = Paint()
      ..color = const Color(0xFFFFF9C4).withValues(alpha: 0.85 * flicker)
      ..style = PaintingStyle.fill;
    final flamePath = Path()
      ..moveTo(0, candleCenter.dy - 6)
      ..quadraticBezierTo(
          3, candleCenter.dy - 1, 2, candleCenter.dy + 3)
      ..quadraticBezierTo(0, candleCenter.dy + 5, -2, candleCenter.dy + 3)
      ..quadraticBezierTo(
          -3, candleCenter.dy - 1, 0, candleCenter.dy - 6);
    canvas.drawPath(flamePath, flamePaint);

    // 7. Base Taper & Tassel
    final basePath = Path()
      ..moveTo(-halfW * 0.85, bodyBottomY)
      ..lineTo(halfW * 0.85, bodyBottomY)
      ..lineTo(halfW * 0.3, bodyBottomY + 7)
      ..lineTo(-halfW * 0.3, bodyBottomY + 7)
      ..close();
    canvas.drawPath(basePath, capFill);
    canvas.drawPath(basePath, capStroke);

    // Bottom drop bead & tassel
    final tasselY = bodyBottomY + 7;
    canvas.drawCircle(Offset(0, tasselY + 4), 2.5,
        Paint()..color = goldColor.withValues(alpha: 0.7));

    // Silk tassel lines
    final tasselPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.5)
      ..strokeWidth = 0.9;
    for (int t = -3; t <= 3; t++) {
      canvas.drawLine(
        Offset(0, tasselY + 6),
        Offset(t * 1.5, tasselY + 18),
        tasselPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HangingLanternsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.hour != hour;
  }
}
