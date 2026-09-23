import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;

import '../../../core/theme/neki_colors.dart';
import '../../recitations/providers/reading_settings_provider.dart';
import '../../recitations/providers/recitation_audio_provider.dart';
import '../../recitations/widgets/verse_action_bottom_sheet.dart';
import '../utils/quran_verse_helper.dart';
import 'surah_ornate_header.dart';

/// Authentic Continuous Scripture Flow (Mushaf Mode).
/// Displays Quran verses flowing naturally in continuous paragraphs, separated
/// by golden ornamental Ayah markers (۝). Tapping any Ayah opens contextual actions.
class MushafViewWidget extends ConsumerStatefulWidget {
  final int surahNumber;
  final ScrollController scrollController;
  final Map<int, String> transliterations;
  final int initialVerse;
  final int? highlightedVerse;
  final VoidCallback? onJumpRequested;
  final ValueChanged<int>? onVisibleVerseChanged;

  const MushafViewWidget({
    super.key,
    required this.surahNumber,
    required this.scrollController,
    this.transliterations = const {},
    this.initialVerse = 1,
    this.highlightedVerse,
    this.onJumpRequested,
    this.onVisibleVerseChanged,
  });

  @override
  ConsumerState<MushafViewWidget> createState() => MushafViewWidgetState();
}

class MushafViewWidgetState extends ConsumerState<MushafViewWidget> {
  final Map<int, GlobalKey> _ayahKeys = {};
  int _lastReportedVerse = 1;

  @override
  void initState() {
    super.initState();
    final count = quran.getVerseCount(widget.surahNumber);
    for (int i = 1; i <= count; i++) {
      _ayahKeys[i] = GlobalKey();
    }

    widget.scrollController.addListener(_onScroll);

    if (widget.initialVerse > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToAyah(widget.initialVerse);
      });
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !widget.scrollController.hasClients) return;
    if (widget.scrollController.offset <= 30) {
      if (_lastReportedVerse != 1) {
        _lastReportedVerse = 1;
        widget.onVisibleVerseChanged?.call(1);
      }
      return;
    }

    final count = quran.getVerseCount(widget.surahNumber);
    int low = 1;
    int high = count;
    int best = 1;
    const threshold = 130.0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final ctx = _ayahKeys[mid]?.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          if (pos.dy <= threshold) {
            best = mid;
            low = mid + 1;
          } else {
            high = mid - 1;
          }
        } else {
          low = mid + 1;
        }
      } else {
        low = mid + 1;
      }
    }

    if (best != _lastReportedVerse) {
      _lastReportedVerse = best;
      widget.onVisibleVerseChanged?.call(best);
    }
  }

  /// Smoothly scrolls to the target Ayah medallion in continuous mushaf mode
  void scrollToAyah(int verse) {
    final total = quran.getVerseCount(widget.surahNumber);
    if (verse < 1 || verse > total) return;

    final key = _ayahKeys[verse];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    final audio = ref.watch(recitationAudioProvider);
    final count = quran.getVerseCount(widget.surahNumber);

    // Auto-scroll to active verse when reciting
    ref.listen<RecitationAudioState>(recitationAudioProvider, (prev, next) {
      if (next.type == RecitationType.quran &&
          next.currentSurah == widget.surahNumber &&
          next.currentVerse != null &&
          next.currentVerse != prev?.currentVerse) {
        scrollToAyah(next.currentVerse!);
      }
    });

    final activeVerse = (audio.hasAudio &&
            audio.type == RecitationType.quran &&
            audio.currentSurah == widget.surahNumber)
        ? audio.currentVerse
        : null;

    final baseArabicStyle = settings.arabicScript == ArabicScript.uthmanic
        ? GoogleFonts.amiriQuran(
            fontSize: settings.arabicFontSize,
            height: 2.15,
            color: const Color(0xFFF7F5EA),
            decoration: TextDecoration.none,
          )
        : GoogleFonts.scheherazadeNew(
            fontSize: settings.arabicFontSize,
            height: 2.15,
            color: const Color(0xFFF7F5EA),
            decoration: TextDecoration.none,
          );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 170),
      children: [
        // Ornate Arch Header
        SurahOrnateHeader(
          surahNumber: widget.surahNumber,
          onJumpTap: widget.onJumpRequested,
        ),

        // Mushaf Paper Page Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F261A).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: NekiColors.goldLight.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: RichText(
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            text: TextSpan(
              children: List.generate(count, (index) {
                final verseNum = index + 1;
                final isCurrent = activeVerse == verseNum;
                final isHighlighted = widget.highlightedVerse == verseNum;
                final rawVerse = QuranVerseHelper.getCleanVerseText(
                  widget.surahNumber,
                  verseNum,
                  verseEndSymbol: false,
                );

                return TextSpan(
                  children: [
                    // Verse Arabic Text
                    TextSpan(
                      text: '$rawVerse ',
                      style: baseArabicStyle.copyWith(
                        backgroundColor: isHighlighted
                            ? NekiColors.goldLight.withValues(alpha: 0.38)
                            : isCurrent
                                ? NekiColors.emeraldPrimary.withValues(alpha: 0.45)
                                : Colors.transparent,
                        color: isHighlighted
                            ? const Color(0xFFFFFBEA)
                            : isCurrent
                                ? NekiColors.goldLight
                                : const Color(0xFFF7F5EA),
                        fontWeight: (isHighlighted || isCurrent) ? FontWeight.bold : FontWeight.normal,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          VerseActionBottomSheet.show(
                            context,
                            surahNumber: widget.surahNumber,
                            verseNumber: verseNum,
                            transliteration: widget.transliterations[verseNum],
                          );
                        },
                    ),

                    // Ornamental Ayah End Medallion (۝)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        key: _ayahKeys[verseNum],
                        onTap: () {
                          VerseActionBottomSheet.show(
                            context,
                            surahNumber: widget.surahNumber,
                            verseNumber: verseNum,
                            transliteration: widget.transliterations[verseNum],
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? NekiColors.gold.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? NekiColors.goldLight
                                  : NekiColors.goldLight.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            '۝$verseNum',
                            style: TextStyle(
                              fontSize: (settings.arabicFontSize * 0.52).clamp(12.0, 18.0),
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? NekiColors.goldLight
                                  : NekiColors.goldLight.withValues(alpha: 0.9),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' '),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
