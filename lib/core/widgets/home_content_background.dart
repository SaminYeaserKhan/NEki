import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../painters/hanging_lanterns_painter.dart';
import '../painters/islamic_pattern_painter.dart';
import '../painters/mosque_painter.dart';
import '../theme/neki_colors.dart';
import '../theme/theme_provider.dart';

/// A rich, multi-layered atmospheric background designed specifically
/// for the bottom (content) page of the HomeScreen.
///
/// Features:
/// 1. Time-adaptive ambient gradient base with deep tones
/// 2. Diffused radial luminous glow auras (emerald & gold)
/// 3. Authentic 8-point Islamic geometric star (Khatam / Girih) pattern
/// 4. Animated swaying Fanous lanterns with flickering candlelight
/// 5. Serene floating ambient light motes
/// 6. Subtle lower mosque skyline watermark
class HomeContentBackground extends ConsumerStatefulWidget {
  final Widget child;

  const HomeContentBackground({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<HomeContentBackground> createState() =>
      _HomeContentBackgroundState();
}

class _HomeContentBackgroundState extends ConsumerState<HomeContentBackground>
    with TickerProviderStateMixin {
  late AnimationController _lanternController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    // Smooth pendulum sway for hanging lanterns (8 second cycle)
    _lanternController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Gentle floating motion for ambient light motes (12 second cycle)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _lanternController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = ref.watch(currentHourProvider);
    final bgTones = _getDeepBackgroundTones(hour);
    final auraColors = _getAuraColors(hour);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bgTones,
        ),
      ),
      child: Stack(
        children: [
          // ── 1. Top-Right Ambient Glow Aura ──
          Positioned(
            top: -60,
            right: -60,
            width: 320,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      auraColors.first.withValues(alpha: 0.16),
                      auraColors.first.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 2. Mid-Left Ambient Glow Aura ──
          Positioned(
            top: 280,
            left: -80,
            width: 300,
            height: 300,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      auraColors.last.withValues(alpha: 0.12),
                      auraColors.last.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 3. Islamic Sacred Geometry (Girih Star Pattern) ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: IslamicPatternPainter(
                  hour: hour,
                  opacity: 0.045,
                  tileSize: 92.0,
                ),
              ),
            ),
          ),

          // ── 4. Lower Mosque Skyline Watermark ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 180,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: CustomPaint(
                  painter: MosqueSilhouettePainter(
                    color: NekiColors.emeraldLight,
                    isBackLayer: true,
                  ),
                ),
              ),
            ),
          ),

          // ── 5. Ambient Floating Light Motes ──
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _LightMotesPainter(
                      progress: _particleController.value,
                      hour: hour,
                    ),
                  );
                },
              ),
            ),
          ),

          // ── 6. Hanging Lanterns (Fanous) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _lanternController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: HangingLanternsPainter(
                      animationValue: _lanternController.value,
                      hour: hour,
                    ),
                  );
                },
              ),
            ),
          ),

          // ── 7. Foreground Content ──
          widget.child,
        ],
      ),
    );
  }

  /// Deep ambient tones for the content page surface based on time of day.
  List<Color> _getDeepBackgroundTones(int hour) {
    if (hour >= 4 && hour < 6) {
      // Fajr
      return const [
        Color(0xFF0F0D24),
        Color(0xFF14132E),
        Color(0xFF0B0A1A),
      ];
    } else if (hour >= 6 && hour < 7) {
      // Sunrise
      return const [
        Color(0xFF1E1718),
        Color(0xFF261D1A),
        Color(0xFF151012),
      ];
    } else if (hour >= 7 && hour < 15) {
      // Dhuhr
      return const [
        Color(0xFF0A1B22),
        Color(0xFF0E242E),
        Color(0xFF08151B),
      ];
    } else if (hour >= 15 && hour < 17) {
      // Asr
      return const [
        Color(0xFF12221A),
        Color(0xFF182D23),
        Color(0xFF0D1B14),
      ];
    } else if (hour >= 17 && hour < 19) {
      // Maghrib
      return const [
        Color(0xFF1A1222),
        Color(0xFF24182E),
        Color(0xFF120B19),
      ];
    }
    // Isha / Night
    return const [
      Color(0xFF0B1713),
      Color(0xFF0F221B),
      Color(0xFF08120E),
    ];
  }

  /// Dynamic aura accent colors (primary glow, secondary glow).
  List<Color> _getAuraColors(int hour) {
    if (hour >= 4 && hour < 6) {
      return const [Color(0xFF7E57C2), Color(0xFF26A69A)];
    } else if (hour >= 6 && hour < 7) {
      return const [Color(0xFFFFB74D), Color(0xFFE57373)];
    } else if (hour >= 7 && hour < 15) {
      return const [Color(0xFF29B6F6), Color(0xFF26A69A)];
    } else if (hour >= 15 && hour < 17) {
      return const [Color(0xFFFFA726), Color(0xFF66BB6A)];
    } else if (hour >= 17 && hour < 19) {
      return const [Color(0xFFAB47BC), Color(0xFFFF7043)];
    }
    return const [NekiColors.emeraldPrimary, NekiColors.gold];
  }
}

/// Paints subtle floating light motes / barakah dust particles
class _LightMotesPainter extends CustomPainter {
  final double progress;
  final int hour;

  const _LightMotesPainter({
    required this.progress,
    required this.hour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rng = Random(77);
    final isDark = NekiColors.isDarkSky(hour);
    final baseColor = isDark ? const Color(0xFFFFF8E1) : Colors.white;

    const count = 16;
    for (int i = 0; i < count; i++) {
      final initialX = rng.nextDouble() * size.width;
      final initialY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final radius = 0.8 + rng.nextDouble() * 1.6;

      // Upward drift with slight sinusoidal horizontal sway
      final currentY = (initialY - (progress * speed * size.height)) % size.height;
      final sway = sin((progress * 2 * pi) + (i * 0.8)) * 14.0;
      final currentX = (initialX + sway) % size.width;

      final twinkle = (sin(progress * 4 * pi + (i * 1.3)) + 1) / 2;
      final alpha = (0.15 + 0.45 * twinkle) * 0.45;

      final paint = Paint()
        ..color = baseColor.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(currentX, currentY), radius, paint);

      if (radius > 1.8) {
        final glow = Paint()
          ..color = baseColor.withValues(alpha: alpha * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawCircle(Offset(currentX, currentY), radius * 2.2, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LightMotesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.hour != hour;
  }
}
