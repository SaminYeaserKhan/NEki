import '../locale/locale_provider.dart';

/// Structured result of sanitized Hadith translation content.
class SanitizedHadithTranslation {
  /// The clean, readable translation text in the active language.
  final String text;

  /// Optional contextual note or Quranic verse citation extracted from preamble.
  final String? contextNote;

  /// Optional narrator attribution extracted from the text (e.g. "উমার ইবনুল খাত্তাব (রাঃ)").
  final String? narrator;

  const SanitizedHadithTranslation({
    required this.text,
    this.contextNote,
    this.narrator,
  });
}

/// Utility for cleaning and formatting Hadith translation data.
/// Resolves issues where raw publisher datasets prepend untranslated Arabic
/// chapter headings, bab titles, or mixed script lines into Bengali translations.
class HadithTextSanitizer {
  HadithTextSanitizer._();

  static final RegExp _arabicCharRegex = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  static final RegExp _bengaliCharRegex = RegExp(r'[\u0980-\u09FF]');

  /// Cleans Bengali translation text by stripping leading untranslated Arabic
  /// chapter titles, sub-headings, or bab prefixes that publisher databases
  /// inadvertently placed inside the translation field.
  static String cleanBengaliText(String raw) {
    if (raw.isEmpty) return raw;

    String trimmed = raw.trim();

    // Check if the string contains Bengali characters
    final matchBn = _bengaliCharRegex.firstMatch(trimmed);
    if (matchBn == null) {
      // If there are zero Bengali characters, return as is or empty
      return trimmed;
    }

    final firstBnIndex = matchBn.start;
    if (firstBnIndex > 0) {
      final prefix = trimmed.substring(0, firstBnIndex);
      // If the prefix before the first Bengali character contains Arabic script,
      // it is an untranslated Arabic chapter/bab header. Strip it.
      if (_arabicCharRegex.hasMatch(prefix)) {
        trimmed = trimmed.substring(firstBnIndex).trim();

        // Clean any leading orphaned punctuation from the stripped header
        trimmed = trimmed.replaceFirst(RegExp(r'^[।\.\,\:\;\-\–\—\(\)\[\]\s‘‘"“”]+'), '').trim();
      }
    }

    return trimmed;
  }

  /// Cleans English translation text, removing repetitive publisher formatting.
  static String cleanEnglishText(String raw) {
    if (raw.isEmpty) return raw;
    String trimmed = raw.trim();
    // Normalize excessive whitespace or quotation artifacts
    trimmed = trimmed.replaceAll(RegExp(r'\s{2,}'), ' ');
    return trimmed;
  }

  /// Resolves the optimal, sanitized translation for a Hadith based on the active locale.
  /// Guarantees that the translation will NEVER fall back to raw Arabic scripture.
  static SanitizedHadithTranslation resolveTranslation({
    String? bengali,
    String? english,
    String? fallbackText,
    required AppLocale locale,
  }) {
    final isBangla = locale == AppLocale.bangla;

    String primary = '';

    if (isBangla) {
      if (bengali != null && bengali.trim().isNotEmpty) {
        primary = cleanBengaliText(bengali);
      } else if (english != null && english.trim().isNotEmpty) {
        primary = cleanEnglishText(english);
      } else if (fallbackText != null && fallbackText.trim().isNotEmpty) {
        final cleaned = cleanBengaliText(fallbackText);
        // Only use fallbackText if it's not pure Arabic
        if (_bengaliCharRegex.hasMatch(cleaned) || !isPureArabic(cleaned)) {
          primary = cleaned;
        }
      }
    } else {
      if (english != null && english.trim().isNotEmpty) {
        primary = cleanEnglishText(english);
      } else if (bengali != null && bengali.trim().isNotEmpty) {
        primary = cleanBengaliText(bengali);
      } else if (fallbackText != null && fallbackText.trim().isNotEmpty) {
        final cleaned = cleanEnglishText(fallbackText);
        if (!isPureArabic(cleaned)) {
          primary = cleaned;
        }
      }
    }

    // Safety fallback if no translation found
    if (primary.isEmpty) {
      primary = isBangla
          ? 'এই হাদিসের অনুবাদ শীঘ্রই যুক্ত করা হবে।'
          : 'Translation for this Hadith will be available shortly.';
    }

    // Extract narrator if present at the start of Bengali text
    String? narrator;
    if (isBangla && primary.isNotEmpty) {
      final narratorMatch = RegExp(
        r'^([^\n।]{4,55}?(?:(?:হতে|থেকে)\s+বর্ণিত|(?:বলেন|বলেছেন)))[\।\:\,\s]',
      ).firstMatch(primary);
      if (narratorMatch != null) {
        narrator = narratorMatch.group(1)?.trim();
      }
    }

    return SanitizedHadithTranslation(
      text: primary,
      narrator: narrator,
    );
  }

  /// Checks if a string contains almost exclusively Arabic characters.
  static bool isPureArabic(String text) {
    if (text.isEmpty) return false;
    final totalLetters = text.replaceAll(RegExp(r'[\s\d\p{P}]', unicode: true), '');
    if (totalLetters.isEmpty) return false;
    final arabicMatches = _arabicCharRegex.allMatches(totalLetters).length;
    return (arabicMatches / totalLetters.length) > 0.8;
  }
}
