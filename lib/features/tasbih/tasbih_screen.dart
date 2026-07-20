import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/neki_colors.dart';
import '../../core/widgets/animated_gradient_bg.dart';

// ─────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────

class TasbihState {
  final int count;
  final int target;

  const TasbihState({this.count = 0, this.target = 33});

  double get progress => target > 0 ? (count / target).clamp(0.0, 1.0) : 0;
}

class TasbihNotifier extends Notifier<TasbihState> {
  static const _countKey = 'neki_tasbih_count';
  static const _targetKey = 'neki_tasbih_target';

  @override
  TasbihState build() {
    _loadPersisted();
    return const TasbihState();
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    state = TasbihState(
      count: prefs.getInt(_countKey) ?? 0,
      target: prefs.getInt(_targetKey) ?? 33,
    );
  }

  Future<void> increment() async {
    state = TasbihState(count: state.count + 1, target: state.target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, state.count);
  }

  Future<void> reset() async {
    state = TasbihState(count: 0, target: state.target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, 0);
  }

  Future<void> setTarget(int target) async {
    state = TasbihState(count: state.count, target: target);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_targetKey, target);
  }
}

final tasbihProvider =
    NotifierProvider<TasbihNotifier, TasbihState>(TasbihNotifier.new);

// ─────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────

class TasbihScreen extends ConsumerWidget {
  const TasbihScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasbih = ref.watch(tasbihProvider);

    return AnimatedGradientBackground(
      showMosque: true,
      showStars: true,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tasbih Counter',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Reset
                  IconButton(
                    icon: Icon(Icons.refresh_rounded,
                        color: Colors.white.withValues(alpha: 0.6)),
                    onPressed: () =>
                        ref.read(tasbihProvider.notifier).reset(),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Target selector ──
            _TargetSelector(currentTarget: tasbih.target),

            const SizedBox(height: 24),

            // ── Progress ring + counter ──
            _ProgressRing(tasbih: tasbih),

            const SizedBox(height: 16),

            // ── Status text ──
            Text(
              tasbih.count >= tasbih.target
                  ? 'Alhamdulillah! Target reached ✓'
                  : '${tasbih.target - tasbih.count} remaining',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tasbih.count >= tasbih.target
                    ? NekiColors.goldLight
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),

            const Spacer(),

            // ── Tap button ──
            _TapButton(),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Target Selector
// ─────────────────────────────────────────────────────

class _TargetSelector extends ConsumerWidget {
  final int currentTarget;

  const _TargetSelector({required this.currentTarget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const targets = [33, 99, 100, 500, 1000];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        itemCount: targets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final target = targets[index];
          final isSelected = target == currentTarget;

          return GestureDetector(
            onTap: () =>
                ref.read(tasbihProvider.notifier).setTarget(target),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? NekiColors.emeraldPrimary.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? NekiColors.emeraldLight.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$target',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Progress Ring
// ─────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final TasbihState tasbih;

  const _ProgressRing({required this.tasbih});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring
          SizedBox(
            width: 200,
            height: 200,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: tasbih.progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  painter: _RingPainter(
                    progress: value,
                    isComplete: tasbih.count >= tasbih.target,
                  ),
                );
              },
            ),
          ),

          // Counter number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: tasbih.count),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, _) {
                  return Text(
                    '$value',
                    style: GoogleFonts.inter(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              Text(
                'of ${tasbih.target}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isComplete;

  _RingPainter({required this.progress, required this.isComplete});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = isComplete ? NekiColors.goldLight : NekiColors.emeraldLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );

    // Glow on progress end
    if (progress > 0) {
      final angle = -pi / 2 + 2 * pi * progress;
      final glowX = center.dx + radius * cos(angle);
      final glowY = center.dy + radius * sin(angle);

      final glowPaint = Paint()
        ..color = (isComplete ? NekiColors.goldLight : NekiColors.emeraldLight)
            .withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(glowX, glowY), 6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isComplete != isComplete;
  }
}

// ─────────────────────────────────────────────────────
//  Tap Button
// ─────────────────────────────────────────────────────

class _TapButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TapButton> createState() => _TapButtonState();
}

class _TapButtonState extends ConsumerState<_TapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _controller.forward().then((_) => _controller.reverse());
    ref.read(tasbihProvider.notifier).increment();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                NekiColors.emeraldMedium,
                NekiColors.emeraldPrimary,
                NekiColors.emeraldDeep,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: NekiColors.emeraldPrimary.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.touch_app_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      ),
    );
  }
}
