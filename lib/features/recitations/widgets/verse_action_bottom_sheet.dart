import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;

import '../../../core/theme/neki_colors.dart';
import '../../../core/utils/bengali_phonetic_helper.dart';
import '../../quran/quran_provider.dart';
import '../../quran/utils/quran_verse_helper.dart';
import '../providers/reading_settings_provider.dart';
import '../providers/recitation_audio_provider.dart';
import 'pronunciation_checker_modal.dart';

class VerseActionBottomSheet extends ConsumerWidget {
  final int surahNumber;
  final int verseNumber;
  final String? transliteration;

  const VerseActionBottomSheet({
    super.key,
    required this.surahNumber,
    required this.verseNumber,
    this.transliteration,
  });

  static void show(
    BuildContext context, {
    required int surahNumber,
    required int verseNumber,
    String? transliteration,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VerseActionBottomSheet(
        surahNumber: surahNumber,
        verseNumber: verseNumber,
        transliteration: transliteration,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahNameEn = quran.getSurahName(surahNumber);
    final surahNameAr = quran.getSurahNameArabic(surahNumber);
    final arabicText = QuranVerseHelper.getCleanVerseText(surahNumber, verseNumber, verseEndSymbol: false);
    final translationLang = ref.watch(translationProvider);
    final translation = QuranVerseHelper.getVerseTranslation(surahNumber, verseNumber, translationLang);

    final settings = ref.watch(readingSettingsProvider);
    final audio = ref.watch(recitationAudioProvider);
    final isThisVersePlaying = audio.isPlaying &&
        audio.type == RecitationType.quran &&
        audio.currentSurah == surahNumber &&
        audio.currentVerse == verseNumber;

    final arabicStyle = settings.arabicScript == ArabicScript.uthmanic
        ? GoogleFonts.amiriQuran(
            fontSize: 24,
            height: 1.9,
            color: const Color(0xFFFFFBEA),
            fontWeight: FontWeight.bold,
          )
        : GoogleFonts.scheherazadeNew(
            fontSize: 24,
            height: 1.9,
            color: const Color(0xFFFFFBEA),
            fontWeight: FontWeight.bold,
          );

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2218).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: NekiColors.emeraldLight.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#$verseNumber',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.emeraldLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$surahNameEn • Ayah $verseNumber',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        'Surah $surahNumber',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  surahNameAr,
                  style: GoogleFonts.amiri(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.goldLight,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const Divider(color: Colors.white12, height: 16),

            // Scrollable Scripture Preview
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            arabicText,
                            style: arabicStyle,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                          ),
                          if (transliteration != null && transliteration!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              translationLang == TranslationLang.bengali
                                  ? BengaliPhoneticHelper.toBengaliPronunciation(transliteration!)
                                  : transliteration!,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: translationLang == TranslationLang.bengali ? FontStyle.normal : FontStyle.italic,
                                color: NekiColors.goldLight.withValues(alpha: 0.9),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            translation,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.4,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Primary Action Grid ──
            Row(
              children: [
                // Listen Ayah Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (isThisVersePlaying) {
                        ref.read(recitationAudioProvider.notifier).togglePlayPause();
                      } else {
                        ref.read(recitationAudioProvider.notifier).playVerse(surahNumber, verseNumber);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NekiColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(
                      isThisVersePlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isThisVersePlaying ? 'Pause Audio' : 'Play Ayah',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Recite & Check Tajweed (Microphone Studio)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      PronunciationCheckerModal.show(
                        context,
                        title: '$surahNameEn • Ayah $verseNumber',
                        arabicText: arabicText,
                        transliteration: transliteration,
                        translation: translation,
                        surahNumber: surahNumber,
                        verseNumber: verseNumber,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NekiColors.gold.withValues(alpha: 0.25),
                      foregroundColor: NekiColors.goldLight,
                      side: const BorderSide(color: NekiColors.goldLight),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.mic_external_on_rounded, size: 18),
                    label: const Text(
                      'Recite & Check',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Secondary Action Row ──
            Row(
              children: [
                // Bookmark
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(readingProgressProvider.notifier).update(surahNumber, verseNumber);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved progress to $surahNameEn Verse $verseNumber'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: NekiColors.emeraldPrimary,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.bookmark_border_rounded, size: 16),
                    label: const Text('Bookmark', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),

                // Copy Arabic
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$arabicText ($surahNameEn $surahNumber:$verseNumber)'));
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied Arabic text to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: NekiColors.emeraldPrimary,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Text', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
