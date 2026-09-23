import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/neki_colors.dart';
import '../providers/recitation_audio_provider.dart';

/// Reusable frosted-glass horizontal scroll panning navigation bar.
/// Used in Quran (verses), Dua (supplications), and Hadith (traditions) reading screens.
/// Features:
/// - Previous (<) and Next (>) sequential steppers with bounds disabling
/// - Smooth horizontal pill carousel with auto-centering on active item
/// - Subtle glowing emerald active indicator with haptic feedback
/// - Dynamic responsive elevation above persistent recitation audio player
class BottomPanningNavBar extends ConsumerStatefulWidget {
  final int itemCount;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final String Function(int index)? labelBuilder;
  final String? prevTooltip;
  final String? nextTooltip;

  const BottomPanningNavBar({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    required this.onItemSelected,
    this.labelBuilder,
    this.prevTooltip,
    this.nextTooltip,
  });

  @override
  ConsumerState<BottomPanningNavBar> createState() => _BottomPanningNavBarState();
}

class _BottomPanningNavBarState extends ConsumerState<BottomPanningNavBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.currentIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _panIntoView(widget.currentIndex, animate: false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant BottomPanningNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _panIntoView(widget.currentIndex, animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _panIntoView(int index, {bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final targetOffset = (index * 56.0) - 110.0;
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 1) return const SizedBox.shrink();

    final hasAudio = ref.watch(recitationAudioProvider).hasAudio;
    final bottomOffset = hasAudio ? 76.0 : 14.0;
    final isFirst = widget.currentIndex <= 0;
    final isLast = widget.currentIndex >= widget.itemCount - 1;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: 16,
      right: 16,
      bottom: bottomOffset,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2016).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: NekiColors.emeraldLight.withValues(alpha: 0.35),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Previous Stepper Button
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                  tooltip: widget.prevTooltip ?? 'Previous',
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    size: 22,
                    color: !isFirst ? NekiColors.emeraldLight : Colors.white24,
                  ),
                  onPressed: !isFirst
                      ? () {
                          HapticFeedback.lightImpact();
                          widget.onItemSelected(widget.currentIndex - 1);
                        }
                      : null,
                ),

                // Panning Numbers Strip
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.itemCount,
                    itemBuilder: (context, index) {
                      final isActive = index == widget.currentIndex;
                      final label = widget.labelBuilder != null
                          ? widget.labelBuilder!(index)
                          : '#${index + 1}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (!isActive) {
                                HapticFeedback.selectionClick();
                                widget.onItemSelected(index);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? NekiColors.emeraldPrimary
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? NekiColors.emeraldLight
                                      : Colors.white.withValues(alpha: 0.1),
                                  width: isActive ? 1.3 : 0.7,
                                ),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: NekiColors.emeraldPrimary
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Next Stepper Button
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                  tooltip: widget.nextTooltip ?? 'Next',
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: !isLast ? NekiColors.emeraldLight : Colors.white24,
                  ),
                  onPressed: !isLast
                      ? () {
                          HapticFeedback.lightImpact();
                          widget.onItemSelected(widget.currentIndex + 1);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
