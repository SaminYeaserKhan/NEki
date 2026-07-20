import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/neki_colors.dart';

/// A glassmorphic Bento-grid card with spring-physics press animation.
///
/// Features:
/// - Semi-transparent frosted-glass background
/// - Subtle white border
/// - 2–3 % scale-down on tap with spring bounce
/// - Soft shadow bloom on press
///
/// ```dart
/// BentoCard(
///   onTap: () => ...,
///   height: 160,
///   child: Column(...),
/// )
/// ```
class BentoCard extends StatefulWidget {
  /// Content inside the card.
  final Widget child;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Fixed height of the card. If `null`, the card sizes to its child.
  final double? height;

  /// Override the glass tint colour.
  /// Defaults to the [NekiColorExtension.cardGlass] from the theme.
  final Color? color;

  /// If `true`, applies a [BackdropFilter] blur behind the card.
  /// Disable on older devices for better performance.
  final bool enableBlur;

  /// Border radius. Defaults to 24.
  final double borderRadius;

  /// Optional gradient overlay rendered on top of the glass fill.
  final Gradient? gradient;

  const BentoCard({
    super.key,
    required this.child,
    this.onTap,
    this.height,
    this.color,
    this.enableBlur = true,
    this.borderRadius = 24,
    this.gradient,
  });

  @override
  State<BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<BentoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final nekiExt = Theme.of(context).extension<NekiColorExtension>();
    final glassColor =
        widget.color ?? nekiExt?.cardGlass ?? Colors.white.withValues(alpha: 0.15);
    final borderColor =
        nekiExt?.cardGlassBorder ?? Colors.white.withValues(alpha: 0.20);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: _buildInner(glassColor, borderColor),
          ),
        ),
      ),
    );
  }

  Widget _buildInner(Color glassColor, Color borderColor) {
    Widget inner = Container(
      decoration: BoxDecoration(
        color: glassColor,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: widget.child,
    );

    if (widget.enableBlur) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: inner,
      );
    }
    return inner;
  }
}
