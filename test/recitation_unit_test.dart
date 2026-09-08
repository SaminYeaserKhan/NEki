import 'package:flutter_test/flutter_test.dart';
import 'package:neki/core/utils/bengali_phonetic_helper.dart';
import 'package:neki/features/dua/dua_provider.dart';
import 'package:neki/features/hadith/hadith_provider.dart';
import 'package:neki/features/quran/utils/quran_verse_helper.dart';
import 'package:neki/features/recitations/providers/reading_settings_provider.dart';
import 'package:neki/features/recitations/providers/recitation_audio_provider.dart';
import 'package:neki/features/recitations/services/pronunciation_service.dart';

void main() {
  group('PronunciationService Tests', () {
    test('evaluates Al-Fatihah with high accuracy and detects rules', () {
      const arabic = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';
      const trans = 'Bismillahir-Rahmaanir-Raheem';

      final result = PronunciationService.instance.evaluateRecitation(
        arabicText: arabic,
        transliteration: trans,
        recordedDuration: const Duration(seconds: 4),
      );

      expect(result.overallScore, greaterThanOrEqualTo(75));
      expect(result.overallScore, lessThanOrEqualTo(100));
      expect(result.words.isNotEmpty, isTrue);
      expect(result.feedbackSummary.isNotEmpty, isTrue);
      expect(result.encouragement.isNotEmpty, isTrue);

      // Check for detected Madd rule
      final hasMadd = result.detectedTajweedRules.any((r) => r.name.contains('Madd'));
      expect(hasMadd, isTrue);

      // Check word token mapping
      expect(result.words.first.arabicWord, equals('بِسْمِ'));
      expect(result.words.first.status, isA<WordPronunciationStatus>());
    });

    test('detects Qalqalah and Ghunnah rules correctly', () {
      const ikhlas = 'قُلْ هُوَ اللَّهُ أَحَدٌ اللَّهُ الصَّمَدُ لَمْ يَلِدْ وَلَمْ يُولَدْ';
      final result = PronunciationService.instance.evaluateRecitation(
        arabicText: ikhlas,
        recordedDuration: const Duration(seconds: 6),
      );

      final hasQalqalah = result.detectedTajweedRules.any((r) => r.name.contains('Qalqalah'));
      expect(hasQalqalah, isTrue);

      final hasGhunnah = result.detectedTajweedRules.any((r) => r.name.contains('Ghunnah'));
      expect(hasGhunnah, isTrue);
    });
  });

  group('RecitationAudioState Tests', () {
    test('progress calculates accurately between 0.0 and 1.0', () {
      const state1 = RecitationAudioState(
        position: Duration(seconds: 15),
        duration: Duration(seconds: 30),
      );
      expect(state1.progress, closeTo(0.5, 0.001));

      const stateZero = RecitationAudioState(
        position: Duration.zero,
        duration: Duration.zero,
      );
      expect(stateZero.progress, equals(0.0));
    });

    test('copyWith updates state correctly', () {
      const initial = RecitationAudioState(speed: 1.0);
      final updated = initial.copyWith(
        speed: 1.5,
        repeatMode: RecitationRepeatMode.verse,
      );
      expect(updated.speed, equals(1.5));
      expect(updated.repeatMode, equals(RecitationRepeatMode.verse));
    });
  });

  group('Offline Hadith & Dua Model Tests', () {
    test('HadithEntry parses JSON properly with bilingual fields', () {
      final json = {
        'hadithNumber': 1,
        'bookId': 'bukhari',
        'chapter': 'Revelation',
        'arabic': 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
        'bengali': 'নিশ্চয়ই প্রতিটি কাজ নিয়তের উপর নির্ভরশীল।',
        'english': 'Actions are according to intentions.',
        'narrator': 'Umar ibn al-Khattab',
        'grade': 'Sahih',
        'reference': 'Sahih al-Bukhari 1',
      };

      final hadith = HadithEntry.fromJson(json);
      expect(hadith.number, equals(1));
      expect(hadith.bookId, equals('bukhari'));
      expect(hadith.chapter, equals('Revelation'));
      expect(hadith.bengali, contains('নিয়তের'));
      expect(hadith.english, contains('intentions'));
      expect(hadith.grade, equals('Sahih'));
    });

    test('Dua model parses JSON properly with bilingual fields', () {
      final json = {
        'id': 1,
        'category': 'Morning',
        'title': 'Morning Supplication',
        'arabic': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
        'transliteration': 'Asbahna wa-asbahal-mulku lillah',
        'english': 'We have entered the morning and the kingdom belongs to Allah.',
        'bengali': 'আমরা সকাল করেছি এবং সকাল বেলা রাজত্ব আল্লাহরই রইল।',
        'reference': 'Sahih Muslim 2723',
      };

      final dua = Dua.fromJson(json);
      expect(dua.id, equals(1));
      expect(dua.category, equals('morning'));
      expect(dua.title, equals('Morning Supplication'));
      expect(dua.arabic, contains('أَصْبَحْنَا'));
      expect(dua.bengali, contains('সকাল'));
      expect(dua.reference, contains('Muslim'));
    });
  });

  group('ReadingSettingsState Tests', () {
    test('default settings and copyWith work properly', () {
      const state = ReadingSettingsState();
      expect(state.readingMode, equals(ReadingMode.study));
      expect(state.arabicScript, equals(ArabicScript.uthmanic));
      expect(state.arabicFontSize, equals(26.0));
      expect(state.showTranslation, isTrue);

      final updated = state.copyWith(
        readingMode: ReadingMode.mushaf,
        arabicFontSize: 32.0,
      );
      expect(updated.readingMode, equals(ReadingMode.mushaf));
      expect(updated.arabicFontSize, equals(32.0));
    });
  });

  group('BengaliPhoneticHelper Tests', () {
    test('transliterates Bismillah accurately to Bengali pronunciation', () {
      final bn = BengaliPhoneticHelper.toBengaliPronunciation('Bismillaahir Rahmaanir Raheem');
      expect(bn, contains('বিসমিল্লাহির'));
      expect(bn, contains('রাহমানির'));
      expect(bn, contains('রাহীম'));
    });

    test('transliterates Alhamdu lillahi accurately', () {
      final bn = BengaliPhoneticHelper.toBengaliPronunciation('Alhamdu lillaahi Rabbil aalameen');
      expect(bn, contains('আলহামদু'));
      expect(bn, contains('লিল্লাহি'));
      expect(bn, contains('রাব্বিল'));
      expect(bn, contains('আলামীন'));
    });

    test('handles empty input gracefully', () {
      expect(BengaliPhoneticHelper.toBengaliPronunciation(''), equals(''));
      expect(BengaliPhoneticHelper.toBengaliPronunciation('   '), equals(''));
    });
  });

  group('QuranVerseHelper Tests', () {
    test('Surah 1 Ayah 1 retains Basmalah as authentic verse', () {
      final v1 = QuranVerseHelper.getCleanVerseText(1, 1);
      expect(v1, contains('بِسْمِ اللَّهِ'));
    });

    test('Surah 2 Ayah 1 cleanly isolates Alif-Lam-Mim', () {
      final v1 = QuranVerseHelper.getCleanVerseText(2, 1);
      expect(v1, equals('الم'));
      expect(v1, isNot(contains('بِسْمِ')));
    });

    test('Surah 3 Ayah 1 cleanly isolates Alif-Lam-Mim', () {
      final v1 = QuranVerseHelper.getCleanVerseText(3, 1);
      expect(v1, equals('الم'));
      expect(v1, isNot(contains('بِسْمِ')));
    });

    test('Surah 9 Ayah 1 begins directly with Bara-atun', () {
      final v1 = QuranVerseHelper.getCleanVerseText(9, 1);
      expect(v1.startsWith('بَرَاءَةٌ'), isTrue);
    });

    test('All 114 Surahs have valid non-empty Ayah 1 without duplicate Basmalah', () {
      for (int s = 1; s <= 114; s++) {
        final v1 = QuranVerseHelper.getCleanVerseText(s, 1);
        expect(v1.isNotEmpty, isTrue, reason: 'Surah $s Ayah 1 was empty');
        if (s != 1) {
          expect(v1.startsWith('بِسْمِ'), isFalse,
              reason: 'Surah $s Ayah 1 still had Basmalah prefix');
        }
      }
    });

    test('Preserves verse end symbol when requested', () {
      final v1WithSymbol = QuranVerseHelper.getCleanVerseText(2, 1, verseEndSymbol: true);
      expect(v1WithSymbol, contains('الم'));
      expect(v1WithSymbol.length, greaterThan('الم'.length));
    });
  });
}

