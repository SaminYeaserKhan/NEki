import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/bengali_phonetic_helper.dart';
import '../../core/widgets/animated_gradient_bg.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/audio_visualizer_widget.dart';
import '../recitations/widgets/persistent_recitation_player.dart';
import '../recitations/widgets/pronunciation_checker_modal.dart';
import 'hadith_provider.dart';

/// Full-screen hadith reader for a section/chapter with single docked audio.
class HadithDetailScreen extends ConsumerWidget {
  final String bookId;
  final HadithSection section;

  const HadithDetailScreen({
    super.key,
    required this.bookId,
    required this.section,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hadithsAsync = ref.watch(
      hadithBySectionProvider((bookId: bookId, sectionNumber: section.sectionNumber)),
    );
    final hour = ref.watch(currentHourProvider);

    return AnimatedGradientBackground(
      showMosque: false,
      showStars: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_rounded,
                            color: NekiColors.adaptiveTextPrimary(hour),
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.name,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: NekiColors.adaptiveTextPrimary(hour),
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${section.hadithCount} Hadiths in Chapter',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: NekiColors.adaptiveTextSecondary(hour),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Hadith List ──
                  Expanded(
                    child: hadithsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: NekiColors.emeraldLight),
                      ),
                      error: (_, _) => Center(
                        child: Text(
                          'Failed to load hadiths.',
                          style: TextStyle(
                            color: NekiColors.adaptiveTextSecondary(hour),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      data: (hadiths) => ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                        itemCount: hadiths.length,
                        itemBuilder: (context, index) => _HadithCard(
                          hadith: hadiths[index],
                          bookId: bookId,
                          hour: hour,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Single Docked Floating Audio Player ──
            const PersistentRecitationPlayer(bottomPadding: 24),
          ],
        ),
      ),
    );
  }
}

class _HadithCard extends ConsumerWidget {
  final HadithEntry hadith;
  final String bookId;
  final int hour;

  const _HadithCard({
    required this.hadith,
    required this.bookId,
    required this.hour,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(hadithBookmarkProvider);
    final isBookmarked = bookmarks.contains('$bookId:${hadith.number}');
    final audio = ref.watch(recitationAudioProvider);
    final isPlaying = audio.isPlaying &&
        audio.type == RecitationType.hadith &&
        audio.currentVerse == hadith.number;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isPlaying
            ? NekiColors.emeraldPrimary.withValues(alpha: 0.18)
            : NekiColors.adaptiveCardColor(hour),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPlaying
              ? NekiColors.emeraldLight
              : NekiColors.adaptiveCardBorder(hour),
          width: isPlaying ? 1.6 : 1.0,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? NekiColors.emeraldPrimary
                      : NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${hadith.number}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (hadith.grade != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    hadith.grade!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.goldLight,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
              const Spacer(),

              if (isPlaying) ...[
                const AudioVisualizerWidget(
                  isPlaying: true,
                  barCount: 3,
                  height: 14,
                  barWidth: 2,
                  color: NekiColors.emeraldLight,
                ),
                const SizedBox(width: 8),
              ],

              // Copy button
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white38),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: '${hadith.arabic}\n\n${hadith.text}\n(${hadith.reference ?? "Hadith ${hadith.number}"})',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied Hadith to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Bookmark
              GestureDetector(
                onTap: () => ref
                    .read(hadithBookmarkProvider.notifier)
                    .toggle(bookId, hadith.number),
                child: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isBookmarked ? NekiColors.goldLight : Colors.white38,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Arabic Matn
          if (hadith.arabic.isNotEmpty)
            Text(
              hadith.arabic,
              style: GoogleFonts.amiri(
                fontSize: 20,
                height: 1.85,
                color: isPlaying ? const Color(0xFFFFFBEA) : NekiColors.adaptiveTextPrimary(hour),
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),

          if (hadith.arabic.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 6),
          ],

          // Translation
          Text(
            hadith.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.88),
              decoration: TextDecoration.none,
            ),
          ),

          if (hadith.reference != null) ...[
            const SizedBox(height: 8),
            Text(
              hadith.reference!,
              style: TextStyle(
                fontSize: 11,
                color: NekiColors.adaptiveTextSecondary(hour).withValues(alpha: 0.7),
                decoration: TextDecoration.none,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Actions: Recite & Listen
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final isBangla = ref.read(localeProvider) == AppLocale.bangla;
                    final pronunciation = isBangla && hadith.transliteration != null
                        ? BengaliPhoneticHelper.toBengaliPronunciation(hadith.transliteration!)
                        : hadith.transliteration;
                    PronunciationCheckerModal.show(
                      context,
                      title: hadith.reference ?? 'Hadith ${hadith.number}',
                      arabicText: hadith.arabic,
                      transliteration: pronunciation,
                      translation: hadith.bengali ?? hadith.english ?? hadith.text,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.goldLight,
                    side: BorderSide(color: NekiColors.goldLight.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 16),
                  label: const Text('Recite & Check', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isPlaying) {
                      ref.read(recitationAudioProvider.notifier).togglePlayPause();
                    } else {
                      ref.read(recitationAudioProvider.notifier).playHadith(hadith);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NekiColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded, size: 16),
                  label: Text(isPlaying ? 'Pause' : 'Pronunciation', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
