import 'package:flutter_test/flutter_test.dart';
import 'package:neki/core/locale/locale_provider.dart';
import 'package:neki/core/utils/hadith_text_sanitizer.dart';

void main() {
  group('HadithTextSanitizer Tests', () {
    test('cleanBengaliText strips leading untranslated Arabic header from Hadith 1', () {
      const rawText =
          'وَقَوْلُ اللهِ جَلَّ ذِكْرُهُ (إِنَّا أَوْحَيْنَا إِلَيْكَ كَمَا أَوْحَيْنَا إِلَى نُوحٍ وَالنَّبِيِّينَ مِنْ بَعْدِ­­هِ) '
          'এ মর্মে আল্লাহ্ তা’আলার বাণীঃ ‘‘নিশ্চয় আমি আপনার প্রতি সেরূপ ওয়াহী প্রেরণ করেছি যেরূপ নূহ ও তাঁর পরবর্তী নবীদের প্রতি ওয়াহী প্রেরণ করেছিলাম।’’ '
          '১. ‘আলক্বামাহ ইবনু ওয়াক্কাস আল-লায়সী (রহ.) হতে বর্ণিত।';

      final cleaned = HadithTextSanitizer.cleanBengaliText(rawText);

      expect(cleaned.startsWith('এ মর্মে আল্লাহ্ তা’আলার বাণীঃ'), isTrue);
      expect(cleaned.contains('وَقَوْلُ'), isFalse);
    });

    test('cleanBengaliText strips leading Arabic bab titles (Hadith 59, 63)', () {
      const rawBab =
          '(بَاب فَضْلِ الْعِلْمِ '
          '৩/১. ‘ইলমের ফাযীলাত। '
          'আল্লাহর রাসূল সাল্লাল্লাহু আলাইহি ওয়াসাল্লাম বলেছেন...';

      final cleaned = HadithTextSanitizer.cleanBengaliText(rawBab);
      expect(cleaned.startsWith('৩/১. ‘ইলমের ফাযীলাত।'), isTrue);
      expect(cleaned.contains('بَاب'), isFalse);
    });

    test('cleanBengaliText leaves already-clean Bengali text completely intact', () {
      const cleanText =
          'নিশ্চয়ই প্রতিটি কাজ নিয়তের ওপর নির্ভরশীল। আর প্রত্যেক ব্যক্তি যা নিয়ত করবে তাই পাবে।';

      final result = HadithTextSanitizer.cleanBengaliText(cleanText);
      expect(result, equals(cleanText));
    });

    test('resolveTranslation prioritizes Bengali for Bengali locale', () {
      final res = HadithTextSanitizer.resolveTranslation(
        bengali: '‘উমার (রাঃ) হতে বর্ণিত। কাজ নিয়ত অনুযায়ী হয়।',
        english: 'Narrated Umar: Deeds are by intentions.',
        locale: AppLocale.bangla,
      );

      expect(res.text, equals('‘উমার (রাঃ) হতে বর্ণিত। কাজ নিয়ত অনুযায়ী হয়।'));
      expect(res.narrator, contains('‘উমার (রাঃ) হতে বর্ণিত'));
    });

    test('resolveTranslation falls back to English when Bengali is null without returning Arabic', () {
      final res = HadithTextSanitizer.resolveTranslation(
        bengali: null,
        english: 'Narrated Umar: Deeds are by intentions.',
        fallbackText: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
        locale: AppLocale.bangla,
      );

      expect(res.text, equals('Narrated Umar: Deeds are by intentions.'));
    });

    test('isPureArabic correctly identifies pure Arabic scripture', () {
      expect(
        HadithTextSanitizer.isPureArabic(
            'حَدَّثَنَا الْحُمَيْدِيُّ عَبْدُ اللَّهِ بْنُ الزُّبَيْرِ ، قَالَ : حَدَّثَنَا سُفْيَانُ'),
        isTrue,
      );
      expect(
        HadithTextSanitizer.isPureArabic('উমার (রাঃ) হতে বর্ণিত। কাজ নিয়ত অনুযায়ী হয়।'),
        isFalse,
      );
    });
  });
}
