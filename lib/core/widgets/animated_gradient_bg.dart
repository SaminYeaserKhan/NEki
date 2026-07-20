import 'dart:async';

import 'package:flutter/material.dart';

import '../painters/mosque_painter.dart';
import '../painters/stars_painter.dart';
import '../theme/neki_colors.dart';

/// A full-screen animated gradient background that shifts colours
/// based on the current time of day.
///
/// Overlays a [MosqueSilhouettePainter] (two layers for parallax depth)
/// and animated [StarsPainter] when the sky is dark.
///
/// Wrap your screen content in this widget using [child].
class AnimatedGradientBackground extends StatefulWidget {
  /// Content rendered on top of the background.
  final Widget? child;

  /// If `true`, draws the mosque silhouette and stars overlay.
  /// Set to `false` for screens that only need the gradient.
  final bool showMosque;

  /// If `true`, stars twinkle during dark-sky hours.
  final bool showStars;

  const AnimatedGradientBackground({
    super.key,
    this.child,
    this.showMosque = true,
    this.showStars = true,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late List<Color> _currentGradient;
  late Timer _timer;

  // Star twinkle animation
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _currentGradient = NekiColors.gradientForHour(DateTime.now().hour);

    // Refresh gradient every 60 s (catches period transitions).
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      final next = NekiColors.gradientForHour(DateTime.now().hour);
      if (!_colorsEqual(next, _currentGradient)) {
        setState(() => _currentGradient = next);
      }
    });

    // Continuous star twinkle animation.
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  bool _colorsEqual(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _timer.cancel();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = NekiColors.isDarkSky(DateTime.now().hour);
    final nekiExt = Theme.of(context).extension<NekiColorExtension>();

    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _currentGradient,
        ),
      ),
      child: Stack(
        children: [
          // ── Stars (only during dark-sky hours) ──
          if (widget.showStars && isDark)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _starController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: StarsPainter(
                      animationValue: _starController.value,
                      starCount: 50,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),

          // ── Mosque back layer (lighter, parallax) ──
          if (widget.showMosque)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.45,
              child: CustomPaint(
                painter: MosqueSilhouettePainter(
                  color: (nekiExt?.mosqueSilhouetteBack ??
                          NekiColors.silhouetteMid)
                      .withValues(alpha: 0.5),
                  isBackLayer: true,
                ),
              ),
            ),

          // ── Mosque front layer (detailed) ──
          if (widget.showMosque)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.45,
              child: CustomPaint(
                painter: MosqueSilhouettePainter(
                  color: nekiExt?.mosqueSilhouetteFront ??
                      NekiColors.silhouetteDark,
                  isBackLayer: false,
                ),
              ),
            ),

          // ── Content ──
          if (widget.child != null) Positioned.fill(child: widget.child!),
        ],
      ),
    );
  }
}
