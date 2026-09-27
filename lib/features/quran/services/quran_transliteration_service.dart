import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:quran/quran.dart' as quran;

import '../../../core/utils/bengali_phonetic_helper.dart';
import '../utils/quran_verse_helper.dart';

/// Comprehensive service for fetching, generating, and caching Quranic
/// transliterations and pronunciations (English & Bengali).
///
/// Features 100% offline fallback so pronunciation is never missing.
class QuranTransliterationService {
  QuranTransliterationService._();

  static final QuranTransliterationService instance =
      QuranTransliterationService._();

  // In-memory cache: surahNumber -> (verseNumber -> englishTransliteration)
  final Map<int, Map<int, String>> _cache = {};

  /// Pre-populates the cache with known transliterations.
  void seedCache(int surahNumber, Map<int, String> verseMap) {
    _cache[surahNumber] = Map.from(verseMap);
  }

  /// Returns whether a Surah's transliterations are already cached in memory.
  bool isSurahCached(int surahNumber) => _cache.containsKey(surahNumber);

  /// Retrieves transliterations for an entire Surah.
  /// Checks memory cache -> tries network fetch -> falls back to offline transliteration.
  Future<Map<int, String>> getSurahTransliteration(int surahNumber) async {
    if (_cache.containsKey(surahNumber)) {
      return _cache[surahNumber]!;
    }

    // Attempt network fetch
    try {
      final response = await http
          .get(Uri.parse(
            'https://api.alquran.cloud/v1/surah/$surahNumber/en.transliteration',
          ))
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ayahs = data['data']?['ayahs'] as List?;
        if (ayahs != null && ayahs.isNotEmpty) {
          final map = <int, String>{};
          for (final ayah in ayahs) {
            final num = ayah['numberInSurah'] as int?;
            final text = ayah['text'] as String?;
            if (num != null && text != null && text.isNotEmpty) {
              map[num] = text.trim();
            }
          }
          if (map.isNotEmpty) {
            _cache[surahNumber] = map;
            return map;
          }
        }
      }
    } catch (_) {
      // Network offline or timed out; proceed to offline generation
    }

    // Offline fallback: generate for all verses in the Surah
    final totalVerses = quran.getVerseCount(surahNumber);
    final fallbackMap = <int, String>{};
    for (int v = 1; v <= totalVerses; v++) {
      final arabic = QuranVerseHelper.getCleanVerseText(surahNumber, v);
      fallbackMap[v] = transliterateArabic(arabic);
    }
    _cache[surahNumber] = fallbackMap;
    return fallbackMap;
  }

  /// Returns synchronous transliteration for a specific verse.
  /// Uses cached result or generates offline transliteration immediately.
  String getVerseTransliteration(
    int surahNumber,
    int verseNumber, {
    String? arabicText,
  }) {
    final cached = _cache[surahNumber]?[verseNumber];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final text = arabicText ??
        QuranVerseHelper.getCleanVerseText(surahNumber, verseNumber);
    final transliterated = transliterateArabic(text);

    // Save to cache
    _cache.putIfAbsent(surahNumber, () => {})[verseNumber] = transliterated;
    return transliterated;
  }

  /// Returns the Bengali pronunciation for an Ayah, guaranteeing non-empty output.
  String getBengaliPronunciation(
    int surahNumber,
    int verseNumber, {
    String? transliteration,
    String? arabicText,
  }) {
    final englishTrans = (transliteration != null && transliteration.isNotEmpty)
        ? transliteration
        : getVerseTransliteration(surahNumber, verseNumber,
            arabicText: arabicText);

    final bengali = BengaliPhoneticHelper.toBengaliPronunciation(englishTrans);
    return bengali.isNotEmpty ? bengali : englishTrans;
  }

  /// Dictionary of high-frequency Quranic words for ultra-precise offline transliteration.
  static final Map<String, String> _knownArabicWords = {
    'بِسْمِ': 'Bismi',
    'اللَّهِ': 'Allahi',
    'اللَّهِ': 'Allahi',
    'الله': 'Allah',
    'الرَّحْمَٰنِ': 'Ar-Rahman',
    'الرَّحْمَٰنِ': 'Ar-Rahman',
    'الرحمن': 'Ar-Rahman',
    'الرَّحِيمِ': 'Ar-Raheem',
    'الرَّحِيمِ': 'Ar-Raheem',
    'الرحيم': 'Ar-Raheem',
    'الْحَمْدُ': 'Al-Hamdu',
    'لِلَّهِ': 'Lillahi',
    'لِلَّهِ': 'Lillahi',
    'لله': 'Lillah',
    'رَبِّ': 'Rabbi',
    'رَبِّ': 'Rabbi',
    'الْعَالَمِينَ': "Al-'Alameen",
    'مَالِكِ': 'Maliki',
    'مَلِكِ': 'Maliki',
    'يَوْمِ': 'Yawmi',
    'الدِّينِ': 'Ad-Deen',
    'الدِّينِ': 'Ad-Deen',
    'إِيَّاكَ': 'Iyyaka',
    'إِيَّاكَ': 'Iyyaka',
    'نَعْبُدُ': "Na'budu",
    'وَإِيَّاكَ': "Wa Iyyaka",
    'وَإِيَّاكَ': "Wa Iyyaka",
    'نَسْتَعِينُ': "Nasta'een",
    'اهْدِنَا': 'Ihdina',
    'الصِّرَاطَ': 'As-Sirata',
    'الصِّرَاطَ': 'As-Sirata',
    'الْمُسْتَقِيمَ': 'Al-Mustaqeem',
    'صِرَاطَ': 'Sirata',
    'الَّذِينَ': 'Allazeena',
    'الَّذِينَ': 'Allazeena',
    'أَنْعَمْتَ': "An'amta",
    'عَلَيْهِمْ': "'Alayhim",
    'غَيْرِ': 'Ghayril',
    'الْمَغْضُوبِ': 'Maghdoobi',
    'وَلَا': 'Wa La',
    'الضَّالِّينَ': "Ad-Daalleen",
    'الضَّالِّينَ': "Ad-Daalleen",
    'قُلْ': 'Qul',
    'هُوَ': 'Huwa',
    'أَحَدٌ': 'Ahad',
    'أَحَد': 'Ahad',
    'الصَّمَدُ': 'As-Samad',
    'الصَّمَدُ': 'As-Samad',
    'لَمْ': 'Lam',
    'يَلِدْ': 'Yalid',
    'وَلَمْ': 'Wa Lam',
    'يُولَدْ': 'Yoolad',
    'يَكُن': 'Yakun',
    'لَّهُ': 'Lahu',
    'لَّهُ': 'Lahu',
    'كُفُوًا': 'Kufuwan',
    'أَعُوذُ': "A'oodhu",
    'بِرَبِّ': 'Bi-Rabbi',
    'بِرَبِّ': 'Bi-Rabbi',
    'الْفَلَقِ': 'Al-Falaq',
    'مِن': 'Min',
    'شَرِّ': 'Sharri',
    'شَرِّ': 'Sharri',
    'مَا': 'Ma',
    'خَلَقَ': 'Khalaq',
    'غَاسِقٍ': 'Ghasiqin',
    'إِذَا': 'Iza',
    'وَقَبَ': 'Waqab',
    'النَّفَّاثَاتِ': 'An-Naffathati',
    'النَّفَّاثَاتِ': 'An-Naffathati',
    'فِي': 'Fee',
    'الْعُقَدِ': "Al-'Uqad",
    'حَاسِدٍ': 'Hasidin',
    'حَسَدَ': 'Hasad',
    'النَّاسِ': 'An-Naas',
    'النَّاسِ': 'An-Naas',
    'مَلِكِ النَّاسِ': 'Malikin-Naas',
    'إِلَٰهِ': 'Ilahi',
    'إِلَهِ': 'Ilahi',
    'الْوَسْوَاسِ': 'Al-Waswasi',
    'الْخَنَّاسِ': 'Al-Khannaas',
    'الْخَنَّاسِ': 'Al-Khannaas',
    'يُوَسْوِسُ': 'Yuwaswisu',
    'صُدُورِ': 'Sudoori',
    'الْجِنَّةِ': 'Al-Jinnati',
    'الْجِنَّةِ': 'Al-Jinnati',
  };

  /// Converts Arabic script into readable English phonetic transliteration.
  static String transliterateArabic(String arabicText) {
    if (arabicText.trim().isEmpty) return '';

    // Clean out ayah numbers and decoration marks
    final clean = arabicText
        .replaceAll(RegExp(r"""[0-9٠-٩\(\)\[\]«»"\'.,;:!؟۝]"""), ' ')
        .trim();

    final rawWords = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final resultWords = <String>[];

    for (final rawWord in rawWords) {
      // Check known dictionary
      if (_knownArabicWords.containsKey(rawWord)) {
        resultWords.add(_knownArabicWords[rawWord]!);
        continue;
      }

      // Check stripped version without harakat for known words
      final stripped = rawWord.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
      if (_knownArabicWords.containsKey(stripped)) {
        resultWords.add(_knownArabicWords[stripped]!);
        continue;
      }

      // Algorithmic phonetic transliteration of the word
      resultWords.add(_transliterateWord(rawWord));
    }

    return resultWords.join(' ');
  }

  static String _transliterateWord(String word) {
    final buffer = StringBuffer();
    final runes = word.runes.toList();

    for (int i = 0; i < runes.length; i++) {
      final r = runes[i];
      final char = String.fromCharCode(r);

      switch (char) {
        case 'ا':
        case 'أ':
        case 'إ':
        case 'ٱ':
        case 'آ':
          buffer.write(buffer.isEmpty ? 'A' : 'a');
          break;
        case 'ب':
          buffer.write('b');
          break;
        case 'ت':
          buffer.write('t');
          break;
        case 'ث':
          buffer.write('th');
          break;
        case 'ج':
          buffer.write('j');
          break;
        case 'ح':
          buffer.write('h');
          break;
        case 'خ':
          buffer.write('kh');
          break;
        case 'د':
          buffer.write('d');
          break;
        case 'ذ':
          buffer.write('dh');
          break;
        case 'ر':
          buffer.write('r');
          break;
        case 'ز':
          buffer.write('z');
          break;
        case 'س':
          buffer.write('s');
          break;
        case 'ش':
          buffer.write('sh');
          break;
        case 'ص':
          buffer.write('s');
          break;
        case 'ض':
          buffer.write('d');
          break;
        case 'ط':
          buffer.write('t');
          break;
        case 'ظ':
          buffer.write('z');
          break;
        case 'ع':
          buffer.write("'");
          break;
        case 'غ':
          buffer.write('gh');
          break;
        case 'ف':
          buffer.write('f');
          break;
        case 'ق':
          buffer.write('q');
          break;
        case 'ك':
          buffer.write('k');
          break;
        case 'ل':
          buffer.write('l');
          break;
        case 'م':
          buffer.write('m');
          break;
        case 'ن':
          buffer.write('n');
          break;
        case 'ه':
        case 'ة':
          buffer.write('h');
          break;
        case 'و':
          buffer.write('w');
          break;
        case 'ي':
        case 'ى':
          buffer.write('y');
          break;
        case 'ء':
        case 'ئ':
        case 'ؤ':
          buffer.write("'");
          break;

        // Harakat:
        case '\u064E': // Fatha
          buffer.write('a');
          break;
        case '\u0650': // Kasra
          buffer.write('i');
          break;
        case '\u064F': // Damma
          buffer.write('u');
          break;
        case '\u064B': // Tanween Fath
          buffer.write('an');
          break;
        case '\u064D': // Tanween Kasr
          buffer.write('in');
          break;
        case '\u064C': // Tanween Damm
          buffer.write('un');
          break;
        case '\u0670': // Dagger Alif
          buffer.write('aa');
          break;
        case '\u0651': // Shaddah: duplicate previous letter if possible
          if (buffer.isNotEmpty) {
            final str = buffer.toString();
            final last = str[str.length - 1];
            if (RegExp(r'[a-zA-Z]').hasMatch(last) && !'aeiou'.contains(last.toLowerCase())) {
              buffer.write(last);
            }
          }
          break;
      }
    }

    var str = buffer.toString();
    // Capitalize first letter
    if (str.isNotEmpty) {
      str = str[0].toUpperCase() + str.substring(1);
    }
    return str.isNotEmpty ? str : word;
  }
}
