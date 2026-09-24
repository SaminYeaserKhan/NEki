import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/recitations/services/arabic_pronunciation_matcher.dart';

void main() {
  group('ArabicPronunciationMatcher Normalization Tests', () {
    test('strips Harakat and normalizes Alif variants in Basmalah', () {
      const basmalah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
      final normalized = ArabicPronunciationMatcher.normalizeArabic(basmalah);
      expect(normalized, equals('بسم الله الرحمن الرحيم'));
    });

    test('normalizes Hamza forms, Alif Maqsura, and Ta Marbuta', () {
      const text = 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ۝ ٱهْدِنَا ٱلصِّرَٰطَ';
      final normalized = ArabicPronunciationMatcher.normalizeArabic(text);
      expect(normalized, contains('اياك نعبد واياك نستعين'));
      expect(normalized, contains('اهدنا الصراط'));
    });

    test('removes Quranic Waqf marks, verse numbers, and punctuation', () {
      const text = 'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ (٢)';
      final normalized = ArabicPronunciationMatcher.normalizeArabic(text);
      expect(normalized, equals('ذلك الكتاب لا ريب فيه هدي للمتقين'));
    });
  });

  group('ArabicPronunciationMatcher Evaluation Tests', () {
    test('exact match yields high score and perfect word statuses', () {
      const target = 'قُلْ هُوَ اللَّهُ أَحَدٌ';
      const spoken = 'قل هو الله احد';

      final result = ArabicPronunciationMatcher.instance.evaluate(
        targetArabic: target,
        spokenArabic: spoken,
      );

      expect(result.overallScore, greaterThanOrEqualTo(90));
      expect(result.qualityTitle, contains('Mumtāz'));
      expect(result.words.length, equals(4));
      for (final word in result.words) {
        expect(word.status, equals(WordPronunciationStatus.perfect));
      }
    });

    test('close phonetic match yields good status and guidance', () {
      const target = 'مَالِكِ يَوْمِ الدِّينِ';
      // User says "الدين" slightly off as "الديم"
      const spoken = 'مالك يوم الديم';

      final result = ArabicPronunciationMatcher.instance.evaluate(
        targetArabic: target,
        spokenArabic: spoken,
      );

      expect(result.words[0].status, equals(WordPronunciationStatus.perfect));
      expect(result.words[1].status, equals(WordPronunciationStatus.perfect));
      expect(result.words[2].status, equals(WordPronunciationStatus.good));
      expect(result.overallScore, greaterThanOrEqualTo(75));
    });

    test('empty spoken text returns 0 score with no speech guidance', () {
      const target = 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ';
      final result = ArabicPronunciationMatcher.instance.evaluate(
        targetArabic: target,
        spokenArabic: '',
      );

      expect(result.overallScore, equals(0));
      expect(result.qualityTitle, equals('No Speech Detected'));
      expect(result.words.every((w) => w.status == WordPronunciationStatus.needsPractice), isTrue);
    });

    test('detects Tajweed rules present in scripture', () {
      const textWithQalqalah = 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ';
      final result = ArabicPronunciationMatcher.instance.evaluate(
        targetArabic: textWithQalqalah,
        spokenArabic: 'قل اعوذ برب الفلق',
      );

      final hasQalqalah = result.detectedTajweedRules.any((r) => r.name.contains('Qalqalah'));
      expect(hasQalqalah, isTrue);
    });
  });
}
