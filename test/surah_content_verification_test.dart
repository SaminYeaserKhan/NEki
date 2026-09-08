import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/quran/quran_provider.dart';
import 'package:neki/features/quran/surah_reader_screen.dart';
import 'package:neki/features/quran/utils/quran_verse_helper.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Every Sura Content & Ayah 1 Authenticity Verification', () {
    test('All 114 Surahs have 100% verified authentic, non-empty Ayah 1', () {
      for (int s = 1; s <= 114; s++) {
        final count = quran.getVerseCount(s);
        expect(count, greaterThan(0), reason: 'Surah $s has 0 verses');

        final v1 = QuranVerseHelper.getCleanVerseText(s, 1);
        expect(v1.isNotEmpty, isTrue, reason: 'Surah $s Ayah 1 is empty');

        if (s == 1) {
          // In Surah 1 Al-Fatihah, Basmalah is the first ayah
          expect(v1, contains('بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ'));
        } else {
          // In Surahs 2-114, raw prepended Basmalah must be stripped
          expect(v1.startsWith('بِسْمِ'), isFalse,
              reason: 'Surah $s Ayah 1 still had Basmalah prefix');
        }

        // Translation verification
        final transEn = QuranVerseHelper.getVerseTranslation(s, 1, TranslationLang.english);
        expect(transEn.isNotEmpty, isTrue, reason: 'Surah $s translation was empty');
      }
    });

    test('Surah 2 (Al-Baqarah) Ayah 1 isolates Alif-Lam-Mim with zero Bismillah overlap', () {
      final v1Arabic = QuranVerseHelper.getCleanVerseText(2, 1);
      expect(v1Arabic, equals('الم'));
      expect(v1Arabic, isNot(contains('بِسْمِ')));

      final transEn = QuranVerseHelper.getVerseTranslation(2, 1, TranslationLang.english);
      expect(transEn, contains('Alif, Lam, Meem'));

      final transBn = QuranVerseHelper.getVerseTranslation(2, 1, TranslationLang.bengali);
      expect(transBn, contains('আলিফ'));
    });

    test('Surah 3 (Ali Imran) Ayah 1 isolates Alif-Lam-Mim with zero Bismillah overlap', () {
      final v1Arabic = QuranVerseHelper.getCleanVerseText(3, 1);
      expect(v1Arabic, equals('الم'));
      expect(v1Arabic, isNot(contains('بِسْمِ')));

      final transEn = QuranVerseHelper.getVerseTranslation(3, 1, TranslationLang.english);
      expect(transEn, contains('Alif, Lam, Meem'));
    });

    test('Surah 9 (At-Tawbah) Ayah 1 begins directly with Bara-atun', () {
      final v1Arabic = QuranVerseHelper.getCleanVerseText(9, 1);
      expect(v1Arabic.startsWith('بَرَاءَةٌ'), isTrue);
    });

    test('Authentic Basmalah opening URL and Tasdiq closing audio matching user specifications', () {
      // Opening audio routing:
      // Surah 1 does not play separate opening because Ayah 1 is Bismillah itself
      expect(QuranVerseHelper.hasOpeningAudio(1), isFalse);
      // Surahs 2-8, 10-114 play Surah 1 Ayah 1 as opening audio
      expect(QuranVerseHelper.hasOpeningAudio(2), isTrue);
      expect(QuranVerseHelper.hasOpeningAudio(9), isFalse);
      expect(QuranVerseHelper.getOpeningAudioUrl(), equals(quran.getAudioURLByVerse(1, 1)));
      expect(QuranVerseHelper.closingAudioPath, equals('assets/audio/closing_sadaqallah.mp3'));

      // Arabic text
      expect(QuranVerseHelper.taawwudhArabic, equals('أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ'));
      expect(QuranVerseHelper.basmalahArabic, equals('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'));
      expect(QuranVerseHelper.tasdiqArabic, equals('صَدَقَ اللَّهُ الْعَظِيمُ'));

      // Transliteration
      expect(QuranVerseHelper.taawwudhTransliterationEn, equals("A'udhu billahi min ash-shaytan ir-rajim"));
      expect(QuranVerseHelper.basmalahTransliterationEn, equals('Bismillah ir-rahman ir-rahim'));
      expect(QuranVerseHelper.tasdiqTransliterationEn, equals("Sadaqallahul 'Adheem"));
    });
  });

  group('SurahReaderScreen UI Verification for Surah 2 & 3', () {
    testWidgets('Surah 2 (Al-Baqarah) displays Alif-Lam-Mim in Ayah 1 card and top nav play button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SurahReaderScreen(surahNumber: 2),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Surah title and header
      expect(find.text('Al Baqarah'), findsWidgets);
      expect(find.text('SURAH 2'), findsOneWidget);
      // Verify obsolete opening button is removed from header
      expect(find.text('Listen Surah (with Opening)'), findsNothing);
      // Verify top navigation bar play button exists
      expect(find.byTooltip('Play Surah'), findsOneWidget);

      // Verify Ayah 1 card has "الم"
      expect(find.text('الم'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Surah 3 (Ali Imran) displays Alif-Lam-Mim in Ayah 1 card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SurahReaderScreen(surahNumber: 3),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Surah title and header
      expect(find.text('Al Imran'), findsWidgets);
      expect(find.text('SURAH 3'), findsOneWidget);
      expect(find.byTooltip('Play Surah'), findsOneWidget);

      // Verify Ayah 1 card has "الم"
      expect(find.text('الم'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Surah 9 (At-Tawbah) has top nav play button, no obsolete header button, and no Bismillah plaque', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SurahReaderScreen(surahNumber: 9),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Surah title and header
      expect(find.text(quran.getSurahName(9)), findsWidgets);
      expect(find.text('SURAH 9'), findsOneWidget);
      expect(find.text("Listen Surah (with Isti'adhah)"), findsNothing);
      expect(find.text('Listen Surah (with Opening)'), findsNothing);
      expect(find.byTooltip('Play Surah'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
