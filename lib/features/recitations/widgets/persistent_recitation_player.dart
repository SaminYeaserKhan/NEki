import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/neki_colors.dart';
import '../../quran/utils/quran_verse_helper.dart';
import '../providers/reading_settings_provider.dart';
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
    final locale = ref.watch(localeProvider);
    final isBn = locale == AppLocale.bangla;

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

                  // ── Tier 1: Track Information & Quick Dismiss ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                    child: Row(
                      children: [
                        // Live Audio Waveform visualizer
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 5),
                          decoration: BoxDecoration(
                            color: NekiColors.emeraldPrimary
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: AudioVisualizerWidget(
                            isPlaying: audio.isPlaying,
                            barCount: 4,
                            height: 16,
                            barWidth: 2.2,
                            color: NekiColors.emeraldLight,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title & Subtitle (Maximum room for what is playing right now)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                audio.title.isNotEmpty ? audio.title : 'Recitation',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (audio.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 1.5),
                                Text(
                                  audio.subtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.72),
                                    decoration: TextDecoration.none,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Close / Dismiss Player Button
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          tooltip: isBn ? 'প্লেয়ার বন্ধ করুন' : 'Dismiss player',
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: Colors.white54),
                          onPressed: () => ref
                              .read(recitationAudioProvider.notifier)
                              .stop(),
                        ),
                      ],
                    ),
                  ),

                  // ── Tier 2: Speed Controls, Track Mode, & Playback Skip Actions ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
                    child: Row(
                      children: [
                        // Playback Speed Controller Capsule (Slow Down, Speed Indicator, Speed Up)
                        _buildSpeedStepper(context, ref, audio, isBn),
                        const SizedBox(width: 6),

                        // Track Mode Switcher (Recitation <-> Translation) right next to speed stepper
                        _buildTrackModeSwitcher(context, ref, audio, isBn),

                        const Spacer(),

                        // Go Back 5 Seconds Button
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 38, minHeight: 38),
                          tooltip: isBn ? '৫ সেকেন্ড পেছনে যান' : 'Go back 5 seconds',
                          icon: const Icon(
                            Icons.replay_5_rounded,
                            size: 23,
                            color: Colors.white,
                          ),
                          onPressed: () => ref
                              .read(recitationAudioProvider.notifier)
                              .rewind5Seconds(),
                        ),
                        const SizedBox(width: 4),

                        // Play/Pause Primary Center Button
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 42, minHeight: 42),
                          tooltip: audio.isPlaying
                              ? (isBn ? 'বিরতি' : 'Pause')
                              : (isBn ? 'চালান' : 'Play'),
                          icon: Icon(
                            audio.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            size: 38,
                            color: NekiColors.emeraldLight,
                          ),
                          onPressed: () => ref
                              .read(recitationAudioProvider.notifier)
                              .togglePlayPause(),
                        ),
                        const SizedBox(width: 4),

                        // Go Forward 5 Seconds Button
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 38, minHeight: 38),
                          tooltip: isBn ? '৫ সেকেন্ড সামনে যান' : 'Go forward 5 seconds',
                          icon: const Icon(
                            Icons.forward_5_rounded,
                            size: 23,
                            color: Colors.white,
                          ),
                          onPressed: () => ref
                              .read(recitationAudioProvider.notifier)
                              .fastForward5Seconds(),
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

  /// Compact toggle between Arabic Recitation and Spoken Translation
  Widget _buildTrackModeSwitcher(
    BuildContext context,
    WidgetRef ref,
    RecitationAudioState audio,
    bool isBn,
  ) {
    return Tooltip(
      message: audio.trackMode == AudioTrackMode.recitation
          ? (isBn
              ? 'অনুবাদে পরিবর্তন করতে চাপুন'
              : 'Switch to Translation')
          : (isBn
              ? 'আরবিতে পরিবর্তন করতে চাপুন'
              : 'Switch to Arabic'),
      child: GestureDetector(
        onTap: () {
          final next = audio.trackMode == AudioTrackMode.recitation
              ? AudioTrackMode.translation
              : AudioTrackMode.recitation;
          ref.read(recitationAudioProvider.notifier).switchTrackMode(next);
        },
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: NekiColors.emeraldPrimary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: NekiColors.emeraldLight.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                audio.trackMode == AudioTrackMode.recitation
                    ? Icons.volume_up_rounded
                    : Icons.record_voice_over_rounded,
                size: 13,
                color: NekiColors.emeraldLight,
              ),
              const SizedBox(width: 3.5),
              Text(
                audio.trackMode == AudioTrackMode.recitation
                    ? (isBn ? 'আরবি' : 'Arabic')
                    : (isBn ? 'অনুবাদ' : 'Translation'),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.emeraldLight,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact, frosted-glass speed controller featuring slow-down (-), current speed, and speed-up (+)
  Widget _buildSpeedStepper(
    BuildContext context,
    WidgetRef ref,
    RecitationAudioState audio,
    bool isBn,
  ) {
    final speed = audio.speed;
    final isMin = speed <= 0.5;
    final isMax = speed >= 2.0;

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF0C2016).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: NekiColors.emeraldLight.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slow down (-) button
          Tooltip(
            message: isBn ? 'গতি কমান (Slow down)' : 'Slow down',
            child: InkWell(
              onTap: isMin
                  ? null
                  : () => ref
                      .read(recitationAudioProvider.notifier)
                      .decreaseSpeed(),
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Icon(
                  Icons.remove_rounded,
                  size: 14,
                  color: isMin ? Colors.white24 : NekiColors.emeraldLight,
                ),
              ),
            ),
          ),

          // Speed Display & Quick Menu
          PopupMenuButton<double>(
            initialValue: speed,
            tooltip: isBn ? 'প্লেব্যাক গতি' : 'Playback Speed',
            padding: EdgeInsets.zero,
            offset: const Offset(0, -220),
            color: const Color(0xFF132B1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: NekiColors.emeraldLight.withValues(alpha: 0.3),
              ),
            ),
            onSelected: (s) =>
                ref.read(recitationAudioProvider.notifier).setSpeed(s),
            itemBuilder: (_) =>
                RecitationAudioNotifier.availableSpeeds.map((sp) {
              final isSelected = (sp - speed).abs() < 0.01;
              return PopupMenuItem<double>(
                value: sp,
                height: 36,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check_rounded,
                          size: 15, color: NekiColors.emeraldLight)
                    else
                      const SizedBox(width: 15),
                    const SizedBox(width: 6),
                    Text(
                      '${sp}x',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color:
                            isSelected ? NekiColors.emeraldLight : Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '${speed.toStringAsFixed(speed.truncateToDouble() == speed ? 0 : (speed * 10 % 1 == 0 ? 1 : 2))}x',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),

          // Speed up (+) button
          Tooltip(
            message: isBn ? 'গতি বাড়ান (Speed up)' : 'Speed up',
            child: InkWell(
              onTap: isMax
                  ? null
                  : () => ref
                      .read(recitationAudioProvider.notifier)
                      .increaseSpeed(),
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: isMax ? Colors.white24 : NekiColors.emeraldLight,
                ),
              ),
            ),
          ),
        ],
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
            if (audio.currentArabicText != null && audio.currentArabicText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 90),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    audio.currentArabicText!,
                    style: GoogleFonts.amiri(
                      fontSize: 17,
                      height: 1.8,
                      color: const Color(0xFFFFFBEA),
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

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
            const SizedBox(height: 14),

            // ── Audio Track Mode Selector (Recitation vs Spoken Translation) ──
            Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref
                          .read(recitationAudioProvider.notifier)
                          .switchTrackMode(AudioTrackMode.recitation),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: audio.trackMode == AudioTrackMode.recitation
                              ? NekiColors.emeraldPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.volume_up_rounded,
                              size: 15,
                              color: audio.trackMode == AudioTrackMode.recitation
                                  ? Colors.white
                                  : Colors.white60,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ref.watch(localeProvider) == AppLocale.bangla
                                  ? 'আরবি (Arabic)'
                                  : 'Arabic',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: audio.trackMode == AudioTrackMode.recitation
                                    ? Colors.white
                                    : Colors.white60,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref
                          .read(recitationAudioProvider.notifier)
                          .switchTrackMode(AudioTrackMode.translation),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: audio.trackMode == AudioTrackMode.translation
                              ? NekiColors.emeraldPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.record_voice_over_rounded,
                              size: 15,
                              color: audio.trackMode == AudioTrackMode.translation
                                  ? Colors.white
                                  : Colors.white60,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ref.watch(localeProvider) == AppLocale.bangla
                                  ? 'অনুবাদ (Translation)'
                                  : 'Translation',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: audio.trackMode == AudioTrackMode.translation
                                    ? Colors.white
                                    : Colors.white60,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  itemBuilder: (_) =>
                      RecitationAudioNotifier.availableSpeeds.map((sp) {
                    return PopupMenuItem<double>(
                      value: sp,
                      child: Text('${sp}x Speed'),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // "Recite & Check Pronunciation" Action Button for Quran, Dua, and Hadith
            if (audio.hasAudio) ...[
              ElevatedButton.icon(
                onPressed: () {
                  String title = audio.title;
                  String arabic = audio.currentArabicText ?? '';
                  String? trans;
                  String? meaning;
                  int? surahNum = audio.currentSurah;
                  int? verseNum = audio.currentVerse;

                  if (audio.type == RecitationType.quran &&
                      audio.currentSurah != null &&
                      audio.currentVerse != null) {
                    final isSurah9 = audio.currentSurah == 9;
                    final total = audio.totalVersesInSurah ?? 0;
                    arabic = audio.currentVerse == 0
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
                  } else if (audio.type == RecitationType.dua && audio.currentDua != null) {
                    final dua = audio.currentDua!;
                    title = dua.title;
                    arabic = dua.arabic;
                    trans = dua.transliteration;
                    meaning = dua.bengali ?? dua.description;
                    surahNum = dua.surahNumber;
                    verseNum = dua.verseNumber;
                  } else if (audio.type == RecitationType.hadith && audio.currentHadith != null) {
                    final hadith = audio.currentHadith!;
                    title = hadith.reference ?? 'Hadith ${hadith.number}';
                    arabic = hadith.arabic;
                    trans = hadith.transliteration;
                    meaning = hadith.bengali ?? hadith.english ?? hadith.text;
                  }

                  Navigator.of(context).pop();
                  PronunciationCheckerModal.show(
                    context,
                    title: title,
                    arabicText: arabic,
                    transliteration: trans,
                    translation: meaning,
                    surahNumber: surahNum,
                    verseNumber: verseNum,
                    dua: audio.currentDua,
                    hadith: audio.currentHadith,
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
