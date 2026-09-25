import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/quran/quran_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Quran Bookmark System Tests', () {
    test('QuranBookmarkNotifier toggles Ayah bookmark correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(quranBookmarkProvider.notifier);

      expect(notifier.isBookmarked(2, 255), isFalse);

      await notifier.toggle(2, 255);
      expect(notifier.isBookmarked(2, 255), isTrue);
      expect(container.read(quranBookmarkProvider), contains('2:255'));

      await notifier.toggle(2, 255);
      expect(notifier.isBookmarked(2, 255), isFalse);
      expect(container.read(quranBookmarkProvider), isNot(contains('2:255')));
    });

    test('QuranBookmarkNotifier toggles Surah bookmark correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(quranBookmarkProvider.notifier);

      expect(notifier.isBookmarked(18), isFalse);

      await notifier.toggle(18);
      expect(notifier.isBookmarked(18), isTrue);
      expect(container.read(quranBookmarkProvider), contains('surah:18'));

      await notifier.toggle(18);
      expect(notifier.isBookmarked(18), isFalse);
      expect(container.read(quranBookmarkProvider), isNot(contains('surah:18')));
    });

    test('QuranBookmarkNotifier loads persisted bookmarks from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'neki_quran_bookmarks': ['1:1', 'surah:36'],
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger build and wait for async persistence load
      container.read(quranBookmarkProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final bookmarks = container.read(quranBookmarkProvider);
      expect(bookmarks, contains('1:1'));
      expect(bookmarks, contains('surah:36'));
      expect(container.read(quranBookmarkProvider.notifier).isBookmarked(1, 1), isTrue);
      expect(container.read(quranBookmarkProvider.notifier).isBookmarked(36), isTrue);
    });

    test('bookmarkedQuranProvider resolves authentic verses and surahs', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(quranBookmarkProvider.notifier);
      await notifier.toggle(2, 255); // Ayatul Kursi
      await notifier.toggle(18); // Surah Al-Kahf

      final bookmarks = await container.read(bookmarkedQuranProvider.future);
      expect(bookmarks.length, equals(2));

      final ayah = bookmarks.firstWhere((b) => b.isAyah);
      expect(ayah.surahNumber, equals(2));
      expect(ayah.verseNumber, equals(255));
      expect(ayah.surahNameEn, equals('Al Baqarah'));
      expect(ayah.arabicText, isNotNull);
      expect(ayah.arabicText!.isNotEmpty, isTrue);
      expect(ayah.translationEn, isNotNull);
      expect(ayah.translationBn, isNotNull);

      final surah = bookmarks.firstWhere((b) => b.isSurah);
      expect(surah.surahNumber, equals(18));
      expect(surah.verseNumber, isNull);
      expect(surah.surahNameEn, equals('Al Kahf'));
      expect(surah.totalVerses, equals(110));
    });
  });
}
