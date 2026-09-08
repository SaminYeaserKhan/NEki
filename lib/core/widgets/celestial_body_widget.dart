import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/neki_colors.dart';

class CelestialBodyWidget extends StatelessWidget {
  final int hour;

  const CelestialBodyWidget({super.key, required this.hour});

  @override
  Widget build(BuildContext context) {
    // Determine type: sun or moon
    final isNight = NekiColors.isDarkSky(hour);

    // Calculate position.
    // Hour ranges from 0 to 23.
    // Day is 5 to 19 (14 hours)
    // Night is 19 to 5 (10 hours)
    double progress = 0;
    if (!isNight) {
      double h = hour.clamp(5, 19).toDouble();
      progress = (h - 5) / 14;
    } else {
      if (hour >= 19) {
        progress = (hour - 19) / 10;
      } else {
        progress = (hour + 5) / 10;
      }
    }

    // Alignment goes from -1.0 (left edge) to 1.0 (right edge)
    double alignmentX;
    if (isNight) {
      // The moon stays in the top middle position, drifting slightly to the right
      alignmentX = 0.0 + (progress * 0.3);
    } else {
      // The sun goes from edge to edge (-1.2 to 1.2)
      alignmentX = -1.2 + (progress * 2.4); 
    } 
    
    // Y alignment: 1.0 is bottom edge, -1.0 is top edge.
    double alignmentY;
    if (isNight) {
      // The Moon should stay high up throughout the night so it's behind the Date/Time widget.
      // It will start high at -0.6, peak at -0.95, and end high at -0.6.
      alignmentY = -0.6 - (sin(progress * pi) * 0.35); 
    } else {
      // The Sun starts low at 0.8, peaks at -0.6, and sets at 0.8
      alignmentY = 0.8 - (sin(progress * pi) * 1.4); 
    } 

    return AnimatedAlign(
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      alignment: Alignment(alignmentX, alignmentY),
      child: isNight ? _buildMoon() : _buildSun(),
    );
  }

  Widget _buildSun() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFD54F),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.8),
            blurRadius: 40,
            spreadRadius: 20,
          ),
          BoxShadow(
            color: const Color(0xFFFFA000).withValues(alpha: 0.5),
            blurRadius: 60,
            spreadRadius: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildMoon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF5F5F5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: const Color(0xFF90CAF9).withValues(alpha: 0.3),
            blurRadius: 50,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}
