import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/neki_colors.dart';

/// Modern mobile splash screen with full-bleed 3D mosque background,
/// gradient overlay, animated geometric Islamic patterns, and elegant
/// text reveal — designed for Android/iOS feel.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _pulseController;

  late Animation<double> _bgOpacity;
  late Animation<double> _imageScale;
  late Animation<double> _overlayOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _progressOpacity;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Fade in whole scene
    _bgOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
      ),
    );

    // Image zooms in slowly (ken burns effect)
    _imageScale = Tween(begin: 1.15, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Dark overlay fades in
    _overlayOpacity = Tween(begin: 0.3, end: 0.55).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Logo appears
    _logoScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.55, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.45, curve: Curves.easeOut),
      ),
    );

    // Tagline
    _taglineOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.50, 0.70, curve: Curves.easeOut),
      ),
    );

    // Loading bar
    _progressOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.65, 0.80, curve: Curves.easeOut),
      ),
    );

    _mainController.forward();

    // Navigate after splash
    Future.delayed(const Duration(milliseconds: 3500), widget.onComplete);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _mainController,
        _particleController,
        _pulseController,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF080E0A),
          body: Opacity(
            opacity: _bgOpacity.value,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Full-bleed background image with Ken Burns ──
                Transform.scale(
                  scale: _imageScale.value,
                  child: Image.asset(
                    'assets/images/splash_mosque.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),

                // ── Gradient overlay (bottom-heavy for text readability) ──
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.3, 0.6, 1.0],
                      colors: [
                        Colors.black.withValues(
                            alpha: _overlayOpacity.value * 0.6),
                        Colors.transparent,
                        Colors.black.withValues(
                            alpha: _overlayOpacity.value * 0.5),
                        Colors.black.withValues(
                            alpha: _overlayOpacity.value * 1.2),
                      ],
                    ),
                  ),
                ),

                // ── Floating golden particles ──
                CustomPaint(
                  painter: _ParticlePainter(
                    progress: _particleController.value,
                    size: size,
                  ),
                ),

                // ── Center content ──
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 5),

                      // ── Logo ──
                      Opacity(
                        opacity: _logoOpacity.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Crescent icon with glow
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      NekiColors.goldLight.withValues(
                                          alpha: 0.15 +
                                              _pulseController.value * 0.1),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.brightness_2_rounded,
                                  size: 48,
                                  color: NekiColors.goldLight,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // App name
                              ShaderMask(
                                shaderCallback: (bounds) {
                                  return const LinearGradient(
                                    colors: [
                                      Colors.white,
                                      NekiColors.goldLight,
                                    ],
                                  ).createShader(bounds);
                                },
                                child: const Text(
                                  'NEki',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 4,
                                    height: 1.1,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Arabic
                              const Text(
                                'نیکی',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: NekiColors.goldLight,
                                  height: 1.3,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Tagline ──
                      Opacity(
                        opacity: _taglineOpacity.value.clamp(0.0, 1.0),
                        child: Text(
                          'Your Complete Islamic Companion',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 1.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),

                      const Spacer(flex: 3),

                      // ── Loading indicator ──
                      Opacity(
                        opacity: _progressOpacity.value.clamp(0.0, 1.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 80),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1800),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return LinearProgressIndicator(
                                  value: value,
                                  minHeight: 3,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    NekiColors.goldLight,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
//  Floating particles painter
// ──────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Size size;

  _ParticlePainter({required this.progress, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final rng = Random(42);
    const count = 25;

    for (int i = 0; i < count; i++) {
      final baseX = rng.nextDouble() * canvasSize.width;
      final baseY = rng.nextDouble() * canvasSize.height;
      final speed = rng.nextDouble() * 0.4 + 0.2;
      final phase = rng.nextDouble() * 2 * pi;

      final x = baseX + sin(progress * 2 * pi * speed + phase) * 12;
      final y = baseY + cos(progress * 2 * pi * speed * 0.6 + phase) * 8;

      final twinkle = (sin(progress * 2 * pi * 1.5 + phase) + 1) / 2;
      final opacity = 0.1 + twinkle * 0.35;
      final radius = rng.nextDouble() * 2.0 + 0.5;

      final paint = Paint()
        ..color = NekiColors.goldLight.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
          Offset(x % canvasSize.width, y % canvasSize.height), radius, paint);

      if (radius > 1.5) {
        final glow = Paint()
          ..color = NekiColors.goldLight.withValues(alpha: opacity * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(
            Offset(x % canvasSize.width, y % canvasSize.height),
            radius * 3,
            glow);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
