import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/neki_colors.dart';

class CloudsPainter extends CustomPainter {
  final double animationValue;
  final int hour;

  CloudsPainter({
    required this.animationValue,
    required this.hour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool isDark = NekiColors.isDarkSky(hour);
    // Cloud color based on time
    Color cloudColor;
    if (isDark) {
      cloudColor = const Color(0xFF3949AB).withValues(alpha: 0.2); // Night clouds
    } else if (hour >= 17 || hour <= 6) {
      cloudColor = const Color(0xFFFF8A65).withValues(alpha: 0.3); // Sunset/Sunrise clouds
    } else {
      cloudColor = Colors.white.withValues(alpha: 0.4); // Day clouds
    }

    final paint = Paint()
      ..color = cloudColor
      ..style = PaintingStyle.fill;

    // Background drifting clouds
    _drawCloud(canvas, paint, size, 0.1, 0.2, 1.5, animationValue, 1.0);
    _drawCloud(canvas, paint, size, 0.6, 0.15, 1.0, animationValue, 0.6); // Slightly slower
    _drawCloud(canvas, paint, size, 0.8, 0.35, 1.2, animationValue, 0.8);
  }

  void _drawCloud(Canvas canvas, Paint paint, Size size, double startX, double startY, double scale, double anim, double speedMultiplier) {
    // Calculate drift. To loop seamlessly, we use (anim * speedMultiplier) % 1.0
    double drift = (anim * speedMultiplier) % 1.0;
    if (drift < 0) drift += 1.0;
    
    // Start X will drift completely across screen (and wrap)
    double x = (startX + drift) % 1.0;
    x = (x * size.width * 2) - (size.width * 0.5); // Map to slightly off screen on both sides
    
    double y = startY * size.height;

    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale);

    // Simple bezier cloud shape
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(20, -30, 40, -10);
    path.quadraticBezierTo(70, -40, 90, 0);
    path.quadraticBezierTo(120, -10, 110, 20);
    path.lineTo(-10, 20);
    path.quadraticBezierTo(-20, -10, 0, 0);
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CloudsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.hour != hour;
  }
}

class BirdsPainter extends CustomPainter {
  final double animationValue;
  final int hour;

  BirdsPainter({
    required this.animationValue,
    required this.hour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Only show birds during the day
    if (NekiColors.isDarkSky(hour)) return;

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Flock of birds drifting
    double drift = (animationValue * 1.5) % 1.0;
    double x = (drift * size.width * 1.5) - (size.width * 0.2); // Start off left, go to right
    double y = size.height * 0.25 + sin(animationValue * pi * 4) * 20; // Bob up and down

    canvas.save();
    canvas.translate(x, y);

    _drawBird(canvas, paint, 0, 0, 1.0);
    _drawBird(canvas, paint, -30, -20, 0.8);
    _drawBird(canvas, paint, -20, 20, 0.9);
    _drawBird(canvas, paint, -50, -10, 0.7);
    _drawBird(canvas, paint, -60, 30, 0.6);

    canvas.restore();
  }

  void _drawBird(Canvas canvas, Paint paint, double x, double y, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale);
    
    // Flapping animation
    double flap = sin(animationValue * pi * 20); 
    
    final path = Path();
    path.moveTo(-10, -5 + (flap * 8)); 
    path.quadraticBezierTo(-2, 0, 0, 3); 
    path.quadraticBezierTo(2, 0, 10, -5 + (flap * 8)); 
    
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BirdsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.hour != hour;
  }
}
