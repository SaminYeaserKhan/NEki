import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../painters/environment_painter.dart';
import '../painters/mosque_painter.dart';
import '../painters/stars_painter.dart';
import '../theme/neki_colors.dart';
import '../theme/theme_provider.dart';
import 'celestial_body_widget.dart';

/// A full-screen animated gradient background that shifts colours
/// based on the current time of day.
///
/// Overlays a [MosqueSilhouettePainter] (two layers for parallax depth)
/// and animated [StarsPainter] when the sky is dark.
///
/// Wrap your screen content in this widget using [child].
class AnimatedGradientBackground extends ConsumerStatefulWidget {
  /// Content rendered on top of the background.
  final Widget? child;

  /// If `true`, draws the mosque silhouette and stars overlay.
  /// Set to `false` for screens that only need the gradient.
  final bool showMosque;

  /// If `true`, stars twinkle during dark-sky hours.
  final bool showStars;

  /// If `true`, renders the sun/moon celestial body.
  final bool showCelestialBody;

  /// If `true`, renders animated drifting clouds.
  final bool showClouds;

  /// If `true`, renders animated birds during daytime.
  final bool showBirds;

  const AnimatedGradientBackground({
    super.key,
    this.child,
    this.showMosque = true,
    this.showStars = true,
    this.showCelestialBody = true,
    this.showClouds = true,
    this.showBirds = true,
  });

  @override
  ConsumerState<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends ConsumerState<AnimatedGradientBackground>
    with TickerProviderStateMixin {
  late Timer _timer;

  // Star twinkle animation
  late AnimationController _starController;
  
  // Environment (Clouds & Birds) drift animation
  late AnimationController _envController;

  @override
  void initState() {
    super.initState();

    // Refresh gradient every 60 s (catches period transitions in system mode).
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });

    // Continuous star twinkle animation.
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Continuous environment drift animation.
    _envController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _timer.cancel();
    _starController.dispose();
    _envController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = ref.watch(currentHourProvider);
    final isDark = NekiColors.isDarkSky(hour);
    final targetGradient = NekiColors.gradientForHour(hour);
    final nekiExt = Theme.of(context).extension<NekiColorExtension>();

    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: targetGradient,
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

          // ── Celestial Body (Sun/Moon) ──
          if (widget.showCelestialBody)
            Positioned.fill(
              child: CelestialBodyWidget(hour: hour),
            ),

          // ── Clouds ──
          if (widget.showClouds)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _envController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: CloudsPainter(
                      animationValue: _envController.value,
                      hour: hour,
                    ),
                  );
                },
              ),
            ),

          // ── Birds ──
          if (widget.showBirds && !isDark)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _envController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: BirdsPainter(
                      animationValue: _envController.value,
                      hour: hour,
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

/// A header version of the animated gradient background.
/// It sizes itself to the height of its [child] plus additional padding
/// at the bottom to reveal the mosque silhouette.
class AnimatedGradientHeader extends ConsumerStatefulWidget {
  final Widget child;
  final bool showMosque;
  final bool showStars;
  final double bottomPadding;
  final double? minHeight;

  const AnimatedGradientHeader({
    super.key,
    required this.child,
    this.showMosque = true,
    this.showStars = true,
    this.bottomPadding = 180.0,
    this.minHeight,
  });

  @override
  ConsumerState<AnimatedGradientHeader> createState() =>
      _AnimatedGradientHeaderState();
}

class _AnimatedGradientHeaderState extends ConsumerState<AnimatedGradientHeader>
    with TickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _starController;
  late AnimationController _envController;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _envController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _timer.cancel();
    _starController.dispose();
    _envController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = ref.watch(currentHourProvider);
    final isDark = NekiColors.isDarkSky(hour);
    final targetGradient = NekiColors.gradientForHour(hour);
    final nekiExt = Theme.of(context).extension<NekiColorExtension>();

    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      constraints: widget.minHeight != null
          ? BoxConstraints(minHeight: widget.minHeight!)
          : null,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: targetGradient,
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

          // ── Celestial Body (Sun/Moon) ──
          Positioned.fill(
            child: CelestialBodyWidget(hour: hour),
          ),

          // ── Clouds ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _envController,
              builder: (context, _) {
                return CustomPaint(
                  painter: CloudsPainter(
                    animationValue: _envController.value,
                    hour: hour,
                  ),
                );
              },
            ),
          ),

          // ── Birds ──
          if (!isDark)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _envController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: BirdsPainter(
                      animationValue: _envController.value,
                      hour: hour,
                    ),
                  );
                },
              ),
            ),

          // ── Mosque back layer (parallax) ──
          if (widget.showMosque)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 250,
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
              height: 250,
              child: CustomPaint(
                painter: MosqueSilhouettePainter(
                  color: nekiExt?.mosqueSilhouetteFront ??
                      NekiColors.silhouetteDark,
                  isBackLayer: false,
                ),
              ),
            ),

          // ── Content ──
          // Not positioned, dictates the height of the Stack
          Padding(
            padding: EdgeInsets.only(bottom: widget.bottomPadding),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

