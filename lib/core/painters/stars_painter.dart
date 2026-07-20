import 'dart:math';

import 'package:flutter/material.dart';

/// Paints twinkling stars on a night-sky background.
///
/// [animationValue] should cycle between 0.0 and 1.0 over time
/// to create the twinkle effect. Pass it from an [AnimationController].
///
/// Stars only appear in the upper 60 % of the canvas so they sit
/// above the mosque silhouette.
class StarsPainter extends CustomPainter {
  /// Current animation progress (0.0 → 1.0), drives the twinkle phase.
  final double animationValue;

  /// Total number of stars to draw.
  final int starCount;

  /// Base star colour (alpha is modulated per-star).
  final Color color;

  StarsPainter({
    required this.animationValue,
    this.starCount = 50,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed seed guarantees the same star positions every frame.
    final rng = Random(42);

    for (int i = 0; i < starCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.60;
      final baseRadius = rng.nextDouble() * 1.4 + 0.4; // 0.4 – 1.8 px

      // Each star gets a unique twinkle phase.
      final phase = rng.nextDouble() * 2 * pi;
      final twinkle = (sin(animationValue * 2 * pi + phase) + 1) / 2;
      final opacity = 0.25 + twinkle * 0.75;
      final radius = baseRadius * (0.7 + twinkle * 0.3);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Add a soft glow halo to the brighter stars.
      if (baseRadius > 1.3) {
        final glow = Paint()
          ..color = color.withValues(alpha: opacity * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
        canvas.drawCircle(Offset(x, y), radius * 2.5, glow);
      }
    }
  }

  @override
  bool shouldRepaint(StarsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
