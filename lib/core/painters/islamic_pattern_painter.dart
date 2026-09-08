import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/neki_colors.dart';

/// Paints an authentic, seamless 8-pointed Islamic geometric star (Khatam / Girih)
/// lattice across the canvas.
///
/// Designed to provide subtle texture and sacred geometry depth behind cards.
class IslamicPatternPainter extends CustomPainter {
  final int hour;
  final double opacity;
  final double tileSize;

  const IslamicPatternPainter({
    required this.hour,
    this.opacity = 0.05,
    this.tileSize = 84.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Color baseColor = _patternColorForHour(hour);
    final paint = Paint()
      ..color = baseColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    final accentPaint = Paint()
      ..color = baseColor.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..isAntiAlias = true;

    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    final starPath = Path();
    final octPath = Path();

    for (int col = 0; col <= cols; col++) {
      for (int row = 0; row <= rows; row++) {
        final cx = col * tileSize;
        final cy = row * tileSize;

        _addEightPointStar(starPath, cx, cy, tileSize * 0.36);
        _addOctagonLattice(octPath, cx, cy, tileSize * 0.48);
      }
    }

    canvas.drawPath(octPath, accentPaint);
    canvas.drawPath(starPath, paint);
  }

  void _addEightPointStar(Path path, double cx, double cy, double outerRadius) {
    final innerRadius = outerRadius * 0.5412; // Perfect 8-point star ratio
    const points = 16;
    const step = pi / 8;

    for (int i = 0; i < points; i++) {
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final angle = i * step - pi / 2;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Inner diamond diagonals for central rosette richness
    final miniRadius = innerRadius * 0.45;
    for (int i = 0; i < 8; i++) {
      final a = i * (pi / 4);
      path.moveTo(cx, cy);
      path.lineTo(cx + miniRadius * cos(a), cy + miniRadius * sin(a));
    }
  }

  void _addOctagonLattice(Path path, double cx, double cy, double radius) {
    // Outer boundary octagon connecting to adjacent cells
    const points = 8;
    const step = pi / 4;
    final halfStep = pi / 8;

    for (int i = 0; i < points; i++) {
      final angle = i * step + halfStep;
      final x = cx + radius * cos(angle);
      final y = cy + radius * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Connecting grid lines to adjacent stars
    path.moveTo(cx - radius * 1.05, cy);
    path.lineTo(cx + radius * 1.05, cy);
    path.moveTo(cx, cy - radius * 1.05);
    path.lineTo(cx, cy + radius * 1.05);
  }

  Color _patternColorForHour(int hour) {
    if (hour >= 4 && hour < 6) {
      // Fajr: Soft lilac/indigo tint
      return const Color(0xFFB39DDB);
    } else if (hour >= 6 && hour < 7) {
      // Sunrise: Warm golden amber
      return NekiColors.goldLight;
    } else if (hour >= 7 && hour < 15) {
      // Dhuhr: Minty emerald
      return NekiColors.emeraldMint;
    } else if (hour >= 15 && hour < 17) {
      // Asr: Warm golden sand
      return NekiColors.gold;
    } else if (hour >= 17 && hour < 19) {
      // Maghrib: Rose-gold
      return const Color(0xFFFFAB91);
    }
    // Isha / Night: Emerald Light
    return NekiColors.emeraldLight;
  }

  @override
  bool shouldRepaint(covariant IslamicPatternPainter oldDelegate) {
    return oldDelegate.hour != hour ||
        oldDelegate.opacity != opacity ||
        oldDelegate.tileSize != tileSize;
  }
}
