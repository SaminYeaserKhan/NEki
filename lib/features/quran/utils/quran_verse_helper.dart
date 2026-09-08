import 'package:quran/quran.dart' as quran;

import '../quran_provider.dart';

/// Centralized utility to ensure 100% scripture authenticity across all 114 Surahs.
///
/// Strips raw Tanzil prepended Basmalah from Ayah 1 of Surahs 2–114 (excluding Surah 9),
/// guaranteeing that Ayah 1 Arabic, translation, transliteration, and audio match perfectly.
class QuranVerseHelper {
  QuranVerseHelper._();

  static const String closingAudioPath = 'assets/audio/closing_sadaqallah.mp3';

  static const String taawwudhArabic = 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ';
  static const String basmalahArabic = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
  static const String tasdiqArabic = 'صَدَقَ اللَّهُ الْعَظِيمُ';
  static const String sadaqallahArabic = tasdiqArabic;

  static const String taawwudhBasmalahArabic =
      '$taawwudhArabic • $basmalahArabic';

  static const String taawwudhTransliterationEn =
      "A'udhu billahi min ash-shaytan ir-rajim";
  static const String taawwudhMeaningEn =
      'I seek refuge in Allah from Satan, the expelled [from His mercy].';

  static const String basmalahTransliterationEn =
      'Bismillah ir-rahman ir-rahim';
  static const String basmalahMeaningEn =
      'In the name of Allah, the Entirely Merciful, the Especially Merciful.';

  static const String tasdiqTransliterationEn =
      "Sadaqallahul 'Adheem";
  static const String tasdiqMeaningEn =
      'Almighty Allah has spoken the truth.';

  static const String openingTransliterationEn =
      "Bismillah ir-rahman ir-rahim";
  static const String openingTransliterationBn =
      "বিসমিল্লাহির রাহমানির রাহীম";

  static const String closingTransliterationEn =
      "Sadaqallahul 'Adheem";
  static const String closingTransliterationBn =
      "সাদাকাল্লাহুল আজীম";

  /// Returns whether a surah has an introductory opening recitation before Ayah 1.
  /// - Surah 1 (Al-Fatihah) has Basmalah as Ayah 1 itself, so no separate opening is played.
  /// - Surah 9 (At-Tawbah) does not begin with Basmalah.
  static bool hasOpeningAudio(int surahNumber) {
    return surahNumber != 1 && surahNumber != 9;
  }

  /// Returns the opening audio URL, which is the first ayah of Surah Al-Fatihah.
  static String getOpeningAudioUrl() {
    return quran.getAudioURLByVerse(1, 1);
  }

  /// Regex matching any prepended Basmalah at the start of verse 1.
  static final RegExp _leadingBasmalahRegex =
      RegExp(r'^بِسْمِ\s+[^\s]+\s+[^\s]+\s+[^\s]+\s*');

  /// Returns the authentic, clean Arabic text of any verse.
  ///
  /// For Surah 1 (Al-Fatihah), Ayah 1 is authentic Basmalah.
  /// For Surahs 2–114 (except 9), strips the raw Basmalah prefix from Ayah 1.
  /// Preserves the Quranic verse end symbol if [verseEndSymbol] is true.
  static String getCleanVerseText(
    int surahNumber,
    int verseNumber, {
    bool verseEndSymbol = false,
  }) {
    final rawText = quran.getVerse(
      surahNumber,
      verseNumber,
      verseEndSymbol: verseEndSymbol,
    );

    // Surah 1 (Al-Fatihah) has Basmalah as its actual first verse
    if (surahNumber == 1) {
      return rawText.trim();
    }

    // Only verse 1 in Surahs 2–114 has the raw prepended Basmalah
    if (verseNumber == 1) {
      final clean = rawText.replaceFirst(_leadingBasmalahRegex, '').trim();
      return clean.isNotEmpty ? clean : rawText.trim();
    }

    return rawText.trim();
  }

  /// Returns the translation in either Bengali or English Saheeh International.
  static String getVerseTranslation(
    int surahNumber,
    int verseNumber,
    TranslationLang lang,
  ) {
    if (lang == TranslationLang.bengali) {
      return quran.getVerseTranslation(
        surahNumber,
        verseNumber,
        translation: quran.Translation.bengali,
      );
    }
    return quran.getVerseTranslation(
      surahNumber,
      verseNumber,
      translation: quran.Translation.enSaheeh,
    );
  }
}
