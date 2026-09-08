import 'package:flutter/material.dart';

/// Paints a highly detailed and intricate mosque skyline silhouette.
///
/// Uses advanced path operations to create realistic domes, multi-tiered 
/// minarets, and Moorish arch cut-outs for negative space.
class MosqueSilhouettePainter extends CustomPainter {
  final Color color;
  final bool isBackLayer;

  const MosqueSilhouettePainter({
    required this.color,
    this.isBackLayer = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final baseSilhouette = Path();
    final cutouts = Path();

    if (isBackLayer) {
      _buildBackSkyline(baseSilhouette, cutouts, size);
    } else {
      _buildFrontSkyline(baseSilhouette, cutouts, size);
    }

    // Subtract cutouts from the silhouette to create intricate windows/arches
    final finalPath = Path.combine(PathOperation.difference, baseSilhouette, cutouts);
    canvas.drawPath(finalPath, paint);

    // Draw crescent moons
    _drawCrescents(canvas, paint, size);
  }

  void _buildFrontSkyline(Path p, Path cutouts, Size size) {
    final w = size.width;
    final h = size.height;
    final wall = h * 0.75; 

    p.moveTo(0, h);
    p.lineTo(0, wall);

    // 1. Far left dome
    _addOnionDome(p, w * 0.06, w * 0.12, h * 0.15, wall);

    // 2. Left Minaret (Multi-tier)
    _addMinaret(p, w * 0.21, w * 0.05, h * 0.50, wall);
    _addMinaretWindows(cutouts, w * 0.21, w * 0.015, h * 0.50, wall);

    // 3. Left cascade dome
    _addHalfDome(p, w * 0.34, w * 0.08, h * 0.12, wall, true);

    // 4. Central Grand Dome
    _addOnionDome(p, w * 0.50, w * 0.24, h * 0.35, wall);
    // Add central dome windows (high up in the dome base)
    _addBaseArches(cutouts, w, h, wall - h * 0.05, 3, heightRatio: 0.08, startX: w * 0.42, endX: w * 0.58, archBottom: wall - h * 0.02);

    // 5. Right cascade dome
    _addHalfDome(p, w * 0.66, w * 0.08, h * 0.12, wall, false);

    // 6. Right Minaret
    _addMinaret(p, w * 0.79, w * 0.05, h * 0.50, wall);
    _addMinaretWindows(cutouts, w * 0.79, w * 0.015, h * 0.50, wall);

    // 7. Far right dome
    _addOnionDome(p, w * 0.94, w * 0.12, h * 0.15, wall);

    p.lineTo(w, wall);
    p.lineTo(w, h);
    p.close();

    // Base wall arches (cutouts) across the whole width
    _addBaseArches(cutouts, w, h, wall, 8, heightRatio: 0.18, startX: w * 0.05, endX: w * 0.95, archBottom: h);
  }

  void _buildBackSkyline(Path p, Path cutouts, Size size) {
    final w = size.width;
    final h = size.height;
    final wall = h * 0.80; 

    p.moveTo(0, h);
    p.lineTo(0, wall);

    // 1. Minaret
    _addMinaret(p, w * 0.15, w * 0.025, h * 0.40, wall);
    
    // 2. Wide dome
    _addOnionDome(p, w * 0.30, w * 0.18, h * 0.22, wall);
    
    // 3. Tall thin minaret
    _addMinaret(p, w * 0.45, w * 0.02, h * 0.45, wall);
    
    // 4. Flat classic dome
    final d4L = w * 0.55;
    final d4R = w * 0.75;
    p.lineTo(d4L, wall);
    p.quadraticBezierTo(w * 0.65, wall - h * 0.18, d4R, wall);
    
    // 5. Minaret
    _addMinaret(p, w * 0.85, w * 0.025, h * 0.35, wall);

    p.lineTo(w, wall);
    p.lineTo(w, h);
    p.close();

    _addBaseArches(cutouts, w, h, wall, 12, heightRatio: 0.12, startX: w * 0.02, endX: w * 0.98, archBottom: h);
  }

  // ───────────────────────────────────────────────
  //  Shape Generators
  // ───────────────────────────────────────────────

  void _addOnionDome(Path p, double cx, double width, double height, double base) {
    final left = cx - width / 2;
    final right = cx + width / 2;
    final top = base - height;

    p.lineTo(left, base);
    p.cubicTo(
      left - width * 0.15, base - height * 0.4, 
      cx - width * 0.05, top + height * 0.1, 
      cx, top
    );
    p.cubicTo(
      cx + width * 0.05, top + height * 0.1, 
      right + width * 0.15, base - height * 0.4, 
      right, base
    );
  }

  void _addHalfDome(Path p, double cx, double width, double height, double base, bool isLeft) {
    final left = cx - width / 2;
    final right = cx + width / 2;
    final top = base - height;

    if (isLeft) {
      p.lineTo(left, base);
      p.quadraticBezierTo(left + width * 0.1, top, right, top);
      p.lineTo(right, base);
    } else {
      p.lineTo(left, base);
      p.lineTo(left, top);
      p.quadraticBezierTo(right - width * 0.1, top, right, base);
    }
  }

  void _addMinaret(Path p, double cx, double width, double height, double base) {
    final left = cx - width / 2;
    final right = cx + width / 2;
    final top = base - height;

    p.lineTo(left, base);
    
    // Lower shaft tapers slightly
    final b1 = base - height * 0.35;
    p.lineTo(left + width * 0.15, b1);
    
    // Lower balcony (protrudes)
    p.lineTo(left - width * 0.3, b1);
    p.lineTo(left - width * 0.3, b1 - height * 0.02);
    p.lineTo(left + width * 0.2, b1 - height * 0.02);

    // Mid shaft
    final b2 = base - height * 0.70;
    p.lineTo(left + width * 0.25, b2);

    // Upper balcony (protrudes)
    p.lineTo(left - width * 0.2, b2);
    p.lineTo(left - width * 0.2, b2 - height * 0.02);
    p.lineTo(left + width * 0.3, b2 - height * 0.02);

    // Upper shaft (narrow)
    final roofBase = top + height * 0.1;
    p.lineTo(left + width * 0.35, roofBase);
    
    // Roof eaves
    p.lineTo(left - width * 0.15, roofBase);
    
    // Pointy roof
    p.lineTo(cx, top);
    p.lineTo(right + width * 0.15, roofBase);
    p.lineTo(right - width * 0.35, roofBase);

    // Descending right side
    p.lineTo(right - width * 0.3, b2 - height * 0.02);
    p.lineTo(right + width * 0.2, b2 - height * 0.02);
    p.lineTo(right + width * 0.2, b2);
    p.lineTo(right - width * 0.25, b2);

    p.lineTo(right - width * 0.2, b1 - height * 0.02);
    p.lineTo(right + width * 0.3, b1 - height * 0.02);
    p.lineTo(right + width * 0.3, b1);
    p.lineTo(right - width * 0.15, b1);

    p.lineTo(right, base);
  }

  void _addMinaretWindows(Path cutouts, double cx, double width, double height, double base) {
    final b1 = base - height * 0.15;
    _addArch(cutouts, cx, width * 1.5, height * 0.1, b1);

    final b2 = base - height * 0.50;
    _addArch(cutouts, cx, width * 1.2, height * 0.08, b2);
  }

  void _addBaseArches(Path cutouts, double w, double h, double wall, int count, {
    required double heightRatio, 
    required double startX, 
    required double endX,
    required double archBottom,
  }) {
    final totalWidth = endX - startX;
    final spacing = totalWidth / count;
    final archWidth = spacing * 0.55;
    final archHeight = h * heightRatio;

    for (int i = 0; i < count; i++) {
      final cx = startX + (i * spacing) + (spacing / 2);
      _addArch(cutouts, cx, archWidth, archHeight, archBottom);
    }
  }

  void _addArch(Path p, double cx, double width, double height, double bottom) {
    final left = cx - width / 2;
    final right = cx + width / 2;
    final top = bottom - height;
    final archStart = bottom - height * 0.5;

    p.moveTo(left, bottom);
    p.lineTo(left, archStart);
    // Moorish arch bulge and point
    p.cubicTo(
      left - width * 0.1, archStart - height * 0.2, 
      cx - width * 0.2, top, 
      cx, top
    );
    p.cubicTo(
      cx + width * 0.2, top, 
      right + width * 0.1, archStart - height * 0.2, 
      right, archStart
    );
    p.lineTo(right, bottom);
    p.close();
  }

  // ───────────────────────────────────────────────
  //  Crescent moons
  // ───────────────────────────────────────────────

  void _drawCrescents(Canvas canvas, Paint paint, Size size) {
    final w = size.width;
    final h = size.height;

    if (isBackLayer) {
      _drawCrescentAt(canvas, paint, w * 0.15, h * 0.40 - w * 0.015, w * 0.01);
      _drawPole(canvas, paint, w * 0.30, h * 0.58 - h * 0.06, h * 0.58);
      _drawCrescentAt(canvas, paint, w * 0.30, h * 0.58 - h * 0.08, w * 0.012);
      _drawCrescentAt(canvas, paint, w * 0.45, h * 0.35 - w * 0.015, w * 0.01);
      _drawPole(canvas, paint, w * 0.65, h * 0.62 - h * 0.05, h * 0.62);
      _drawCrescentAt(canvas, paint, w * 0.65, h * 0.62 - h * 0.07, w * 0.012);
      _drawCrescentAt(canvas, paint, w * 0.85, h * 0.45 - w * 0.015, w * 0.01);
    } else {
      _drawCrescentAt(canvas, paint, w * 0.21, h * 0.25 - w * 0.02, w * 0.015);
      
      _drawPole(canvas, paint, w * 0.50, h * 0.40 - h * 0.08, h * 0.40);
      _drawCrescentAt(canvas, paint, w * 0.50, h * 0.40 - h * 0.11, w * 0.025);
      
      _drawCrescentAt(canvas, paint, w * 0.79, h * 0.25 - w * 0.02, w * 0.015);
    }
  }

  void _drawPole(Canvas canvas, Paint paint, double x, double top, double bottom) {
    canvas.drawRect(Rect.fromLTWH(x - 0.8, top, 1.6, bottom - top), paint);
  }

  void _drawCrescentAt(Canvas canvas, Paint paint, double cx, double cy, double radius) {
    final outer = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    final inner = Path()..addOval(Rect.fromCircle(
        center: Offset(cx + radius * 0.4, cy - radius * 0.1),
        radius: radius * 0.75,
    ));
    final crescent = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(MosqueSilhouettePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isBackLayer != isBackLayer;
  }
}
