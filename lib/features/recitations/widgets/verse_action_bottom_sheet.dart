import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;

import '../../../core/theme/neki_colors.dart';
import '../../../core/utils/bengali_phonetic_helper.dart';
import '../../../core/widgets/neki_snack_bar.dart';
import '../../quran/quran_provider.dart';
import '../../quran/utils/quran_verse_helper.dart';
import '../providers/reading_settings_provider.dart';
import '../providers/recitation_audio_provider.dart';

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
    final bookmarks = ref.watch(quranBookmarkProvider);
    final isBookmarked = bookmarks.contains('$surahNumber:$verseNumber');
    final isBn = translationLang == TranslationLang.bengali;

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

            // ── Primary Action: Listen Ayah ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (isThisVersePlaying) {
                    ref.read(recitationAudioProvider.notifier).togglePlayPause();
                  } else {
                    ref.read(recitationAudioProvider.notifier).playVerse(surahNumber, verseNumber, autoAdvance: false);
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

            const SizedBox(height: 10),

            // ── Secondary Action Row ──
            Row(
              children: [
                // Bookmark
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final willBeBookmarked = !isBookmarked;
                      ref.read(quranBookmarkProvider.notifier).toggle(surahNumber, verseNumber);
                      Navigator.of(context).pop();
                      NekiSnackBar.showBookmark(
                        context,
                        isSaved: willBeBookmarked,
                        message: willBeBookmarked
                            ? (isBn
                                ? '$surahNameEn আয়াত $verseNumber বুকমার্কে সংরক্ষণ করা হয়েছে'
                                : 'Saved $surahNameEn Verse $verseNumber to Bookmarks')
                            : (isBn
                                ? '$surahNameEn আয়াত $verseNumber বুকমার্ক সরানো হয়েছে'
                                : 'Bookmark removed for $surahNameEn Verse $verseNumber'),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isBookmarked ? NekiColors.goldLight : Colors.white70,
                      side: BorderSide(
                        color: isBookmarked ? NekiColors.goldLight.withValues(alpha: 0.6) : Colors.white24,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 16,
                      color: isBookmarked ? NekiColors.goldLight : Colors.white70,
                    ),
                    label: Text(
                      isBookmarked
                          ? (isBn ? 'সংরক্ষিত' : 'Bookmarked')
                          : (isBn ? 'বুকমার্ক' : 'Bookmark'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isBookmarked ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Copy Arabic
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '$arabicText ($surahNameEn $surahNumber:$verseNumber)'));
                      Navigator.of(context).pop();
                      NekiSnackBar.showSuccess(
                        context,
                        message: isBn ? 'আরবি আয়াত কপি করা হয়েছে' : 'Copied Arabic text to clipboard',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(isBn ? 'কপি করুন' : 'Copy Text', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Mark as Last Read Position
            Center(
              child: TextButton.icon(
                onPressed: () {
                  ref.read(readingProgressProvider.notifier).update(surahNumber, verseNumber);
                  Navigator.of(context).pop();
                  NekiSnackBar.show(
                    context,
                    message: isBn
                        ? '$surahNameEn আয়াত $verseNumber পড়ার শেষ অবস্থান হিসেবে সংরক্ষণ করা হয়েছে'
                        : 'Marked $surahNameEn Verse $verseNumber as last read position',
                    icon: Icons.history_rounded,
                    iconColor: NekiColors.goldLight,
                    badgeText: 'POSITION',
                    isGoldAccent: true,
                  );
                },
                icon: const Icon(Icons.history_rounded, size: 15, color: NekiColors.goldLight),
                label: Text(
                  isBn ? 'পড়ার শেষ স্থান হিসেবে চিহ্নিত করুন' : 'Mark as Last Read Position',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
