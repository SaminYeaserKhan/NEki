import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/core/widgets/neki_snack_bar.dart';
import 'package:neki/features/quran/quran_provider.dart';
import 'package:neki/features/recitations/providers/recitation_audio_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (call) async {
      return <String, dynamic>{};
    });
  });

  group('Last Played & Reading Progress Tests', () {
    test('ReadingProgressNotifier loads and clamps persisted values safely', () async {
      SharedPreferences.setMockInitialValues({
        'neki_last_surah': 200, // Invalid, should clamp to 114
        'neki_last_verse': 999, // Invalid, should clamp to total verses of Surah 114 (6)
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(readingProgressProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final progress = container.read(readingProgressProvider);
      expect(progress.surahNumber, equals(114));
      expect(progress.verseNumber, equals(6));
    });

    test('ReadingProgressNotifier update clamps values and writes to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(readingProgressProvider.notifier);
      await notifier.update(18, 50);

      final progress = container.read(readingProgressProvider);
      expect(progress.surahNumber, equals(18));
      expect(progress.verseNumber, equals(50));
      expect(progress.lastReadTime, isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('neki_last_surah'), equals(18));
      expect(prefs.getInt('neki_last_verse'), equals(50));
      expect(prefs.getInt('neki_last_read_timestamp'), isNotNull);
    });

    test('recitationAudioProvider playVerse updates readingProgressProvider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Listen to progress to keep provider alive
      container.listen(readingProgressProvider, (prev, next) {});

      final audioNotifier = container.read(recitationAudioProvider.notifier);

      // Play verse 36:12 (Surah Ya-Sin)
      await audioNotifier.playVerse(36, 12);

      final progress = container.read(readingProgressProvider);
      expect(progress.surahNumber, equals(36));
      expect(progress.verseNumber, equals(12));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('neki_last_surah'), equals(36));
      expect(prefs.getInt('neki_last_verse'), equals(12));
    });
  });

  group('NekiSnackBar Tests', () {
    testWidgets('NekiSnackBar renders white text and high-contrast styling for bookmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  NekiSnackBar.showBookmark(
                    context,
                    isSaved: true,
                    message: 'Saved Al-Kahf to bookmarks',
                  );
                },
                child: const Text('Show Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Toast'));
      await tester.pumpAndSettle();

      // Verify SnackBar content
      expect(find.text('Saved Al-Kahf to bookmarks'), findsOneWidget);
      expect(find.text('SAVED'), findsOneWidget);

      // Verify the text widget has white color for high contrast
      final textWidget = tester.widget<Text>(find.text('Saved Al-Kahf to bookmarks'));
      expect(textWidget.style?.color, equals(Colors.white));

      // Verify bookmark added icon
      expect(find.byIcon(Icons.bookmark_added_rounded), findsOneWidget);
    });

    testWidgets('NekiSnackBar renders REMOVED badge when isSaved is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  NekiSnackBar.showBookmark(
                    context,
                    isSaved: false,
                    message: 'Removed from bookmarks',
                  );
                },
                child: const Text('Show Remove Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Remove Toast'));
      await tester.pumpAndSettle();

      expect(find.text('Removed from bookmarks'), findsOneWidget);
      expect(find.text('REMOVED'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_remove_rounded), findsOneWidget);
    });
  });
}
