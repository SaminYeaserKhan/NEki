import 'package:flutter/material.dart';

/// Paints a detailed mosque skyline silhouette.
///
/// Two visual variants controlled by [isBackLayer]:
/// - `false` (default): Detailed front-layer skyline with tall minarets
///   and a grand central dome.
/// - `true`: Simpler, lighter skyline placed behind the front layer for
///   parallax depth.
///
/// Both variants include small crescent moons atop domes and minarets.
class MosqueSilhouettePainter extends CustomPainter {
  /// Fill colour of the silhouette.
  final Color color;

  /// If `true`, draws the simpler back-layer skyline.
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

    final path =
        isBackLayer ? _buildBackSkyline(size) : _buildFrontSkyline(size);

    canvas.drawPath(path, paint);

    // Draw crescent moons on top of minarets and domes
    _drawCrescents(canvas, paint, size);
  }

  // ───────────────────────────────────────────────
  //  Front-layer skyline (detailed)
  // ───────────────────────────────────────────────

  Path _buildFrontSkyline(Size size) {
    final w = size.width;
    final h = size.height;
    final wall = h * 0.75; // base wall height (bottom 25%)

    final path = Path();
    path.moveTo(0, h); // bottom-left corner
    path.lineTo(0, wall); // left wall upward

    // ── Small dome (far left) ──
    path.lineTo(w * 0.04, wall);
    path.quadraticBezierTo(w * 0.09, wall - h * 0.18, w * 0.14, wall);

    // ── Minaret 1 (medium) ──
    path.lineTo(w * 0.185, wall);
    path.lineTo(w * 0.185, h * 0.48);
    // small dome cap on minaret
    path.quadraticBezierTo(w * 0.20, h * 0.42, w * 0.215, h * 0.48);
    path.lineTo(w * 0.215, wall);

    // ── Medium dome ──
    path.lineTo(w * 0.27, wall);
    path.quadraticBezierTo(w * 0.35, h * 0.30, w * 0.43, wall);

    // ── Tall minaret (tallest element) ──
    path.lineTo(w * 0.46, wall);
    path.lineTo(w * 0.46, h * 0.25);
    path.quadraticBezierTo(w * 0.475, h * 0.18, w * 0.49, h * 0.25);
    path.lineTo(w * 0.49, wall);

    // ── Grand dome (central, widest) ──
    path.lineTo(w * 0.52, wall - h * 0.01);
    path.quadraticBezierTo(w * 0.65, h * 0.15, w * 0.78, wall - h * 0.01);

    // ── Right minaret ──
    path.lineTo(w * 0.81, wall);
    path.lineTo(w * 0.81, h * 0.28);
    path.quadraticBezierTo(w * 0.825, h * 0.22, w * 0.84, h * 0.28);
    path.lineTo(w * 0.84, wall);

    // ── Small dome (far right) ──
    path.lineTo(w * 0.87, wall);
    path.quadraticBezierTo(w * 0.92, wall - h * 0.14, w * 0.97, wall);

    // ── Close path ──
    path.lineTo(w, wall);
    path.lineTo(w, h); // bottom-right corner
    path.close();

    return path;
  }

  // ───────────────────────────────────────────────
  //  Back-layer skyline (simpler / parallax)
  // ───────────────────────────────────────────────

  Path _buildBackSkyline(Size size) {
    final w = size.width;
    final h = size.height;
    final wall = h * 0.80; // slightly lower than front

    final path = Path();
    path.moveTo(0, h);
    path.lineTo(0, wall);

    // ── Dome (left) ──
    path.lineTo(w * 0.02, wall);
    path.quadraticBezierTo(w * 0.10, wall - h * 0.16, w * 0.18, wall);

    // ── Small minaret ──
    path.lineTo(w * 0.22, wall);
    path.lineTo(w * 0.22, h * 0.55);
    path.quadraticBezierTo(w * 0.235, h * 0.50, w * 0.25, h * 0.55);
    path.lineTo(w * 0.25, wall);

    // ── Wide dome ──
    path.lineTo(w * 0.32, wall);
    path.quadraticBezierTo(w * 0.44, wall - h * 0.22, w * 0.56, wall);

    // ── Minaret ──
    path.lineTo(w * 0.60, wall);
    path.lineTo(w * 0.60, h * 0.42);
    path.quadraticBezierTo(w * 0.615, h * 0.37, w * 0.63, h * 0.42);
    path.lineTo(w * 0.63, wall);

    // ── Dome (right-center) ──
    path.lineTo(w * 0.68, wall);
    path.quadraticBezierTo(w * 0.76, wall - h * 0.18, w * 0.84, wall);

    // ── Small dome (far right) ──
    path.lineTo(w * 0.88, wall);
    path.quadraticBezierTo(w * 0.94, wall - h * 0.12, w * 1.0, wall);

    path.lineTo(w, h);
    path.close();

    return path;
  }

  // ───────────────────────────────────────────────
  //  Crescent moons
  // ───────────────────────────────────────────────

  void _drawCrescents(Canvas canvas, Paint paint, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.020; // base crescent radius

    if (isBackLayer) {
      _drawCrescentAt(canvas, paint, w * 0.235, h * 0.47, r * 0.8);
      _drawCrescentAt(canvas, paint, w * 0.615, h * 0.34, r * 0.8);
    } else {
      // Minaret 1 crescent
      _drawCrescentAt(canvas, paint, w * 0.20, h * 0.39, r);

      // Tall minaret crescent (with pole)
      _drawPole(canvas, paint, w * 0.475, h * 0.15, h * 0.18);
      _drawCrescentAt(canvas, paint, w * 0.475, h * 0.12, r * 1.1);

      // Grand dome crescent (with pole)
      _drawPole(canvas, paint, w * 0.65, h * 0.18, h * 0.24);
      _drawCrescentAt(canvas, paint, w * 0.65, h * 0.15, r * 1.2);

      // Right minaret crescent
      _drawCrescentAt(canvas, paint, w * 0.825, h * 0.19, r);
    }
  }

  /// Draws a thin vertical pole (finial) above a dome or minaret.
  void _drawPole(
      Canvas canvas, Paint paint, double x, double top, double bottom) {
    canvas.drawRect(
      Rect.fromLTWH(x - 0.8, top, 1.6, bottom - top),
      paint,
    );
  }

  /// Draws a crescent moon shape at ([cx], [cy]) with the given [radius].
  ///
  /// The crescent opens to the left, consistent with Islamic iconography.
  void _drawCrescentAt(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double radius,
  ) {
    final outer = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    final inner = Path()
      ..addOval(Rect.fromCircle(
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
