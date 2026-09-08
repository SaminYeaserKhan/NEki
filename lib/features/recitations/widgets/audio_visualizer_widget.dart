import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/theme/neki_colors.dart';

/// An animated live equalizer soundwave visualizer that bounces
/// dynamically during recitation playback.
class AudioVisualizerWidget extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final double barWidth;
  final Color? color;

  const AudioVisualizerWidget({
    super.key,
    required this.isPlaying,
    this.barCount = 5,
    this.height = 20.0,
    this.barWidth = 3.0,
    this.color,
  });

  @override
  State<AudioVisualizerWidget> createState() => _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends State<AudioVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? NekiColors.emeraldLight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (index) {
            double factor = 0.25;
            if (widget.isPlaying) {
              // Staggered sine oscillation per bar
              final phase = (index * 0.45);
              final wave = sin((_controller.value * 2 * pi) + phase);
              factor = 0.25 + 0.75 * ((wave + 1) / 2);
            }

            final currentHeight = (widget.height * factor).clamp(4.0, widget.height);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: widget.barWidth,
              height: currentHeight,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(widget.barWidth),
                boxShadow: widget.isPlaying
                    ? [
                        BoxShadow(
                          color: baseColor.withValues(alpha: 0.4),
                          blurRadius: 3,
                          spreadRadius: 0.5,
                        )
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}
