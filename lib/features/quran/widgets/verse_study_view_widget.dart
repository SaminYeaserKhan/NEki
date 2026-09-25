import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/theme/neki_colors.dart';
import '../../../core/utils/bengali_phonetic_helper.dart';
import '../../../core/widgets/neki_snack_bar.dart';
import '../../recitations/providers/reading_settings_provider.dart';
import '../../recitations/providers/recitation_audio_provider.dart';
import '../../recitations/widgets/audio_visualizer_widget.dart';
import '../../recitations/widgets/pronunciation_checker_modal.dart';
import '../../recitations/widgets/verse_action_bottom_sheet.dart';
import '../quran_provider.dart';
import '../utils/quran_verse_helper.dart';
import 'surah_ornate_header.dart';

/// Structured Line-by-Line Study Flow (Verse Study Mode).
/// Displays clean, elegant verse cards with clear typography, optional transliteration
/// and translation, without the distraction of repetitive button clutter.
class VerseStudyViewWidget extends ConsumerStatefulWidget {
  final int surahNumber;
  final ScrollController? scrollController;
  final Map<int, String> transliterations;
  final int initialVerse;
  final int? highlightedVerse;
  final VoidCallback? onJumpRequested;
  final ValueChanged<int>? onVisibleVerseChanged;

  const VerseStudyViewWidget({
    super.key,
    required this.surahNumber,
    this.scrollController,
    this.transliterations = const {},
    this.initialVerse = 1,
    this.highlightedVerse,
    this.onJumpRequested,
    this.onVisibleVerseChanged,
  });

  @override
  ConsumerState<VerseStudyViewWidget> createState() => VerseStudyViewWidgetState();
}

class VerseStudyViewWidgetState extends ConsumerState<VerseStudyViewWidget> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _lastReportedVerse = 1;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Find the topmost visible item near the upper reading line of the screen
    final candidates = positions.where((p) => p.itemTrailingEdge > 0.05).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));

    if (candidates.isNotEmpty) {
      final topItem = candidates.first;
      // Index 0 is the SurahOrnateHeader (Ayah 1), indices 1..N correspond to Verses 1..N
      final verse = topItem.index == 0 ? 1 : topItem.index;
      if (verse != _lastReportedVerse) {
        _lastReportedVerse = verse;
        widget.onVisibleVerseChanged?.call(verse);
      }
    }
  }

  /// Instantly and reliably scrolls to any Ayah within the surah on the first call.
  void scrollToVerse(int verse) {
    final total = quran.getVerseCount(widget.surahNumber);
    if (verse < 1 || verse > total) return;

    // Index 0 is header (Ayah 1), index N is verse N
    final targetIndex = verse == 1 ? 0 : verse;

    void performScroll() {
      if (_itemScrollController.isAttached) {
        _itemScrollController.scrollTo(
          index: targetIndex,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: verse == 1 ? 0.0 : 0.03,
        );
      }
    }

    if (_itemScrollController.isAttached) {
      performScroll();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => performScroll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    final audio = ref.watch(recitationAudioProvider);
    final translationLang = ref.watch(translationProvider);
    final count = quran.getVerseCount(widget.surahNumber);

    ref.listen<RecitationAudioState>(recitationAudioProvider, (prev, next) {
      if (next.type == RecitationType.quran &&
          next.currentSurah == widget.surahNumber &&
          next.currentVerse != null &&
          next.currentVerse != prev?.currentVerse) {
        scrollToVerse(next.currentVerse!);
      }
    });

    final isThisSurah = audio.type == RecitationType.quran &&
        audio.currentSurah == widget.surahNumber;

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex: widget.initialVerse > 1 ? widget.initialVerse : 0,
      initialAlignment: widget.initialVerse > 1 ? 0.03 : 0.0,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 170),
      itemCount: count + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return SurahOrnateHeader(
            surahNumber: widget.surahNumber,
            onJumpTap: widget.onJumpRequested,
          );
        }

        final verseNum = index;
        final isCurrentVerse = isThisSurah && audio.currentVerse == verseNum && audio.hasAudio;
        final isHighlighted = widget.highlightedVerse == verseNum;
        final isPlaying = isCurrentVerse && audio.isPlaying;
        final isLoading = isCurrentVerse && audio.isLoading;
        final transliteration = widget.transliterations[verseNum];

        return _VerseStudyRow(
          surahNumber: widget.surahNumber,
          verseNumber: verseNum,
          transliteration: transliteration,
          translationLang: translationLang,
          settings: settings,
          isCurrentVerse: isCurrentVerse,
          isHighlighted: isHighlighted,
          isPlaying: isPlaying,
          isLoading: isLoading,
          onPlayTap: () {
            if (isCurrentVerse) {
              ref.read(recitationAudioProvider.notifier).togglePlayPause();
            } else {
              ref.read(recitationAudioProvider.notifier).playVerse(widget.surahNumber, verseNum, autoAdvance: false);
            }
          },
          onVocalizeTap: () {
            final arabic = QuranVerseHelper.getCleanVerseText(widget.surahNumber, verseNum, verseEndSymbol: false);
            final trans = QuranVerseHelper.getVerseTranslation(widget.surahNumber, verseNum, translationLang);
            final pronunciation = translationLang == TranslationLang.bengali && transliteration != null
                ? BengaliPhoneticHelper.toBengaliPronunciation(transliteration)
                : transliteration;

            PronunciationCheckerModal.show(
              context,
              title: '${quran.getSurahName(widget.surahNumber)} • Ayah $verseNum',
              arabicText: arabic,
              transliteration: pronunciation,
              translation: trans,
              surahNumber: widget.surahNumber,
              verseNumber: verseNum,
            );
          },
        );
      },
    );
  }
}

class _VerseStudyRow extends ConsumerWidget {
  final int surahNumber;
  final int verseNumber;
  final String? transliteration;
  final TranslationLang translationLang;
  final ReadingSettingsState settings;
  final bool isCurrentVerse;
  final bool isHighlighted;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onPlayTap;
  final VoidCallback onVocalizeTap;

  const _VerseStudyRow({
    required this.surahNumber,
    required this.verseNumber,
    this.transliteration,
    required this.translationLang,
    required this.settings,
    required this.isCurrentVerse,
    this.isHighlighted = false,
    required this.isPlaying,
    required this.isLoading,
    required this.onPlayTap,
    required this.onVocalizeTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabicText = QuranVerseHelper.getCleanVerseText(surahNumber, verseNumber, verseEndSymbol: false);
    final translation = QuranVerseHelper.getVerseTranslation(surahNumber, verseNumber, translationLang);
    final bookmarks = ref.watch(quranBookmarkProvider);
    final isBookmarked = bookmarks.contains('$surahNumber:$verseNumber');

    final arabicStyle = settings.arabicScript == ArabicScript.uthmanic
        ? GoogleFonts.amiriQuran(
            fontSize: settings.arabicFontSize,
            height: 2.1,
            color: (isHighlighted || isCurrentVerse) ? const Color(0xFFFFFBEA) : const Color(0xFFF7F5EA),
            decoration: TextDecoration.none,
          )
        : GoogleFonts.scheherazadeNew(
            fontSize: settings.arabicFontSize,
            height: 2.1,
            color: (isHighlighted || isCurrentVerse) ? const Color(0xFFFFFBEA) : const Color(0xFFF7F5EA),
            decoration: TextDecoration.none,
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? NekiColors.goldLight.withValues(alpha: 0.18)
            : isCurrentVerse
                ? NekiColors.emeraldPrimary.withValues(alpha: 0.22)
                : const Color(0xFF0F241A).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? NekiColors.goldLight
              : isCurrentVerse
                  ? NekiColors.emeraldLight
                  : Colors.white.withValues(alpha: 0.08),
          width: isHighlighted ? 2.0 : isCurrentVerse ? 1.6 : 1.0,
        ),
        boxShadow: (isHighlighted || isCurrentVerse)
            ? [
                BoxShadow(
                  color: isHighlighted
                      ? NekiColors.goldLight.withValues(alpha: 0.45)
                      : NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                  blurRadius: isHighlighted ? 20 : 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Clean Header Row ──
          Row(
            children: [
              // Verse number badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentVerse
                      ? NekiColors.emeraldPrimary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$surahNumber:$verseNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCurrentVerse ? Colors.white : NekiColors.goldLight,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

              if (isPlaying) ...[
                const SizedBox(width: 8),
                const AudioVisualizerWidget(
                  isPlaying: true,
                  barCount: 3,
                  height: 14,
                  barWidth: 2,
                  color: NekiColors.emeraldLight,
                ),
              ],

              const Spacer(),

              // Quick Copy Action
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: translationLang == TranslationLang.bengali ? 'কপি করুন' : 'Copy Ayah',
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white54),
                onPressed: () {
                  final surahName = quran.getSurahName(surahNumber);
                  final textToCopy = '$arabicText\n\n$translation\n($surahName $surahNumber:$verseNumber)';
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  NekiSnackBar.showSuccess(
                    context,
                    message: translationLang == TranslationLang.bengali
                        ? 'আয়াত কপি করা হয়েছে'
                        : 'Ayah copied to clipboard',
                  );
                },
              ),
              const SizedBox(width: 4),

              // Quick Bookmark Action
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: isBookmarked
                    ? (translationLang == TranslationLang.bengali ? 'বুকমার্ক সরান' : 'Remove Bookmark')
                    : (translationLang == TranslationLang.bengali ? 'বুকমার্ক করুন' : 'Bookmark Ayah'),
                icon: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 19,
                  color: isBookmarked ? NekiColors.goldLight : Colors.white54,
                ),
                onPressed: () {
                  final willBeBookmarked = !isBookmarked;
                  ref.read(quranBookmarkProvider.notifier).toggle(surahNumber, verseNumber);
                  final surahName = quran.getSurahName(surahNumber);
                  final isBn = translationLang == TranslationLang.bengali;
                  NekiSnackBar.showBookmark(
                    context,
                    isSaved: willBeBookmarked,
                    message: willBeBookmarked
                        ? (isBn
                            ? '$surahName আয়াত $verseNumber বুকমার্কে সংরক্ষণ করা হয়েছে'
                            : 'Saved $surahName Verse $verseNumber to Bookmarks')
                        : (isBn
                            ? '$surahName আয়াত $verseNumber বুকমার্ক সরানো হয়েছে'
                            : 'Bookmark removed for $surahName Verse $verseNumber'),
                  );
                },
              ),
              const SizedBox(width: 2),

              // Contextual Action Menu Button
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
                onPressed: () {
                  VerseActionBottomSheet.show(
                    context,
                    surahNumber: surahNumber,
                    verseNumber: verseNumber,
                    transliteration: transliteration,
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Arabic Scripture ──
          if (settings.showArabic) ...[
            Text(
              arabicText,
              style: arabicStyle,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ],

          // ── Transliteration Guide (Pronunciation) ──
          if (settings.showTransliteration &&
              transliteration != null &&
              transliteration!.isNotEmpty) ...[
            if (settings.showArabic) const SizedBox(height: 10),
            Text(
              translationLang == TranslationLang.bengali
                  ? BengaliPhoneticHelper.toBengaliPronunciation(transliteration!)
                  : transliteration!,
              style: TextStyle(
                fontSize: 13,
                fontStyle: translationLang == TranslationLang.bengali ? FontStyle.normal : FontStyle.italic,
                color: NekiColors.goldLight.withValues(alpha: 0.9),
                height: 1.45,
                decoration: TextDecoration.none,
              ),
            ),
          ],

          // ── Translation ──
          if (settings.showTranslation) ...[
            if (settings.showArabic ||
                (settings.showTransliteration &&
                    transliteration != null &&
                    transliteration!.isNotEmpty))
              const SizedBox(height: 8),
            Text(
              translation,
              style: TextStyle(
                fontSize: settings.translationFontSize,
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.5,
                decoration: TextDecoration.none,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Clean Action Strip (Matching Dua & Hadith) ──
          Row(
            children: [
              // Pronunciation Checker ("Recite & Check")
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onVocalizeTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.goldLight,
                    side: BorderSide(
                      color: NekiColors.goldLight.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 15),
                  label: Text(
                    translationLang == TranslationLang.bengali ? 'উচ্চারণ যাচাই' : 'Recite & Check',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Listen / Play Ayah Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPlayTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPlaying
                        ? NekiColors.emeraldLight
                        : NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                    foregroundColor: isPlaying ? Colors.black87 : Colors.white,
                    side: BorderSide(
                      color: NekiColors.emeraldLight.withValues(alpha: isPlaying ? 1.0 : 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                          size: 16,
                        ),
                  label: Text(
                    isPlaying
                        ? (translationLang == TranslationLang.bengali ? 'বিরতি' : 'Pause')
                        : (translationLang == TranslationLang.bengali ? 'শুনুন' : 'Play Ayah'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
