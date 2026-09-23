import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../painters/islamic_pattern_painter.dart';
import '../theme/theme_provider.dart';

/// A serene, high-contrast background canvas designed specifically for
/// recitation and scripture reading (Quran, Duas, and Hadiths).
///
/// Features a tranquil obsidian-emerald gradient, a soft sacred top illumination,
/// and a subtle 8-pointed Islamic geometric star lattice watermark.
/// Eliminates visual distraction (no clouds, sun/moon, or twinkling stars)
/// to maximize readability and reverence for sacred scriptures.
class RecitationBackground extends ConsumerWidget {
  final Widget? child;

  const RecitationBackground({
    super.key,
    this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = ref.watch(currentHourProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF07140D),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF06130B),
            Color(0xFF08160E),
            Color(0xFF0B1F15),
            Color(0xFF07140D),
          ],
          stops: [0.0, 0.35, 0.75, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Soft Top Ambient Sacred Glow ──
          Positioned(
            top: -120,
            left: -40,
            right: -40,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.85,
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.07),
                      const Color(0xFF059669).withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Sacred Islamic Geometric Pattern Watermark ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: IslamicPatternPainter(
                  hour: hour,
                  opacity: 0.028,
                  tileSize: 92.0,
                ),
              ),
            ),
          ),

          // ── Foreground Content ──
          ?child,
        ],
      ),
    );
  }
}
