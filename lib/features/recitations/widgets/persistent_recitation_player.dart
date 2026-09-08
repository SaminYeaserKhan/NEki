import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/neki_colors.dart';
import '../../quran/utils/quran_verse_helper.dart';
import '../providers/recitation_audio_provider.dart';
import 'audio_visualizer_widget.dart';
import 'pronunciation_checker_modal.dart';

/// Floating mini-player at the bottom of the screen with live audio waves,
/// scrub slider, and expandable full player sheet.
class PersistentRecitationPlayer extends ConsumerWidget {
  final double bottomPadding;

  const PersistentRecitationPlayer({
    super.key,
    this.bottomPadding = 80.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(recitationAudioProvider);

    if (!audio.hasAudio) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomPadding,
      child: GestureDetector(
        onTap: () => _showFullPlayerModal(context, ref),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF132B1F).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: NekiColors.emeraldLight.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress Bar Top Accent
                  LinearProgressIndicator(
                    value: audio.progress,
                    minHeight: 2.5,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      NekiColors.emeraldLight,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Live Audio Waveform icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: NekiColors.emeraldPrimary
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: AudioVisualizerWidget(
                            isPlaying: audio.isPlaying,
                            barCount: 4,
                            height: 18,
                            barWidth: 2.5,
                            color: NekiColors.emeraldLight,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                audio.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                audio.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Rewind 10s
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded,
                              size: 20, color: Colors.white70),
                          onPressed: () => ref
                              .read(recitationAudioProvider.notifier)
                              .rewind(),
                        ),

                        // Play/Pause
                        IconButton(
                          icon: Icon(
                            audio.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            size: 32,
                            color: NekiColors.emeraldLight,
                          ),
                          onPressed: () => ref
                              .read(recitationAudioProvider.notifier)
                              .togglePlayPause(),
                        ),

                        // Fast forward 10s
                        IconButton(
                          icon: const Icon(Icons.forward_10_rounded,
                              size: 20, color: Colors.white70),
                          onPressed: () => ref
                              .read(recitationAudioProvider.notifier)
                              .fastForward(),
                        ),

                        // Stop/Dismiss
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Colors.white38),
                          onPressed: () => ref
                              .read(recitationAudioProvider.notifier)
                              .stop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullPlayerModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FullPlayerSheet(),
    );
  }
}

class _FullPlayerSheet extends ConsumerWidget {
  const _FullPlayerSheet();

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(recitationAudioProvider);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1E16).withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: NekiColors.emeraldLight.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Medallion Artwork
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [NekiColors.emeraldPrimary, Color(0xFF09160F)],
                  ),
                  border: Border.all(
                    color: NekiColors.goldLight.withValues(alpha: 0.5),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 50,
                    color: NekiColors.goldLight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Titles
            Text(
              audio.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              audio.subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Dancing Visualizer Wave
            Center(
              child: AudioVisualizerWidget(
                isPlaying: audio.isPlaying,
                barCount: 16,
                height: 38,
                barWidth: 3.5,
                color: NekiColors.emeraldLight,
              ),
            ),
            const SizedBox(height: 24),

            // Progress Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: NekiColors.emeraldLight,
                inactiveTrackColor: Colors.white12,
                thumbColor: NekiColors.goldLight,
              ),
              child: Slider(
                value: audio.progress,
                onChanged: (val) {
                  final newMs = (val * audio.duration.inMilliseconds).round();
                  ref
                      .read(recitationAudioProvider.notifier)
                      .seekTo(Duration(milliseconds: newMs));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(audio.position),
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                  Text(
                    _formatDuration(audio.duration),
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Playback Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Repeat Mode
                IconButton(
                  icon: Icon(
                    audio.repeatMode == RecitationRepeatMode.verse
                        ? Icons.repeat_one_rounded
                        : audio.repeatMode == RecitationRepeatMode.all
                            ? Icons.repeat_rounded
                            : Icons.repeat_rounded,
                    color: audio.repeatMode != RecitationRepeatMode.off
                        ? NekiColors.goldLight
                        : Colors.white38,
                  ),
                  onPressed: () => ref
                      .read(recitationAudioProvider.notifier)
                      .toggleRepeatMode(),
                ),

                // Rewind 10s
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded,
                      size: 32, color: Colors.white),
                  onPressed: () =>
                      ref.read(recitationAudioProvider.notifier).rewind(),
                ),

                // Play/Pause Large
                GestureDetector(
                  onTap: () => ref
                      .read(recitationAudioProvider.notifier)
                      .togglePlayPause(),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [NekiColors.emeraldPrimary, Color(0xFF13452B)],
                      ),
                      border: Border.all(
                        color: NekiColors.emeraldLight,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: NekiColors.emeraldPrimary.withValues(alpha: 0.4),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Icon(
                      audio.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Fast forward 10s
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded,
                      size: 32, color: Colors.white),
                  onPressed: () =>
                      ref.read(recitationAudioProvider.notifier).fastForward(),
                ),

                // Speed Selector
                PopupMenuButton<double>(
                  initialValue: audio.speed,
                  icon: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${audio.speed}x',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: NekiColors.emeraldLight,
                      ),
                    ),
                  ),
                  onSelected: (s) =>
                      ref.read(recitationAudioProvider.notifier).setSpeed(s),
                  itemBuilder: (_) => [0.75, 1.0, 1.25, 1.5, 2.0].map((sp) {
                    return PopupMenuItem<double>(
                      value: sp,
                      child: Text('${sp}x Speed'),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // "Recite & Check Pronunciation" Action Button (if Quran verse)
            if (audio.type == RecitationType.quran &&
                audio.currentSurah != null &&
                audio.currentVerse != null) ...[
              ElevatedButton.icon(
                onPressed: () {
                  final isSurah9 = audio.currentSurah == 9;
                  final total = audio.totalVersesInSurah ?? 0;
                  final arabic = audio.currentVerse == 0
                      ? (isSurah9
                          ? QuranVerseHelper.taawwudhArabic
                          : QuranVerseHelper.taawwudhBasmalahArabic)
                      : audio.currentVerse! > total
                          ? QuranVerseHelper.tasdiqArabic
                          : QuranVerseHelper.getCleanVerseText(
                              audio.currentSurah!,
                              audio.currentVerse!,
                              verseEndSymbol: false,
                            );
                  Navigator.of(context).pop();
                  PronunciationCheckerModal.show(
                    context,
                    title: audio.title,
                    arabicText: arabic,
                    surahNumber: audio.currentSurah,
                    verseNumber: audio.currentVerse,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                  foregroundColor: NekiColors.emeraldLight,
                  side: const BorderSide(color: NekiColors.emeraldLight),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.mic_external_on_rounded),
                label: const Text(
                  'Vocalize & Check My Pronunciation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
