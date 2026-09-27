import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/recitations/widgets/pronunciation_checker_modal.dart';

void main() {
  group('Real-Time Recitation Studio Widget Tests', () {
    testWidgets('Mode selector pill switches between Single Ayah and Whole Surah modes', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PronunciationCheckerModal(
                title: 'Al-Fatihah • Ayah 1',
                arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                transliteration: 'Bismillahir-Rahmanir-Rahim',
                translation: 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
                surahNumber: 1,
                verseNumber: 1,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify mode selector pills are visible
      expect(find.text('Single Ayah'), findsOneWidget);
      expect(find.text('Whole Surah'), findsOneWidget);

      // Tap on 'Whole Surah'
      await tester.tap(find.text('Whole Surah'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Surah Progress is displayed in scripture card
      expect(find.textContaining('Surah Progress: 1 / 7'), findsOneWidget);

      // Tap back to 'Single Ayah'
      await tester.tap(find.text('Single Ayah'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Surah progress bar is no longer present
      expect(find.textContaining('Surah Progress'), findsNothing);
    });

    testWidgets('Real-time recitation pauses on mistake, shows Makhraj HUD, and resumes on correction', (tester) async {
      final modal = PronunciationCheckerModal(
        title: 'Al-Ikhlas • Ayah 1',
        arabicText: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
        transliteration: 'Qul Huwa Allahu Ahad',
        surahNumber: 112,
        verseNumber: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: modal),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(PronunciationCheckerModal));

      // 1. User says "قل هو"
      // ignore: invalid_use_of_protected_member
      (state as dynamic).simulateRealtimeTranscript('قل هو');
      await tester.pump();

      // Recitation is in active recording mode
      expect(find.textContaining('Listening'), findsWidgets);

      // 2. User makes a mistake on word 2 ("الله"): says "الرحمن"
      // ignore: invalid_use_of_protected_member
      (state as dynamic).simulateRealtimeTranscript('قل هو الرحمن');
      await tester.pump();

      // Recitation pauses on mistake and shows the guidance HUD
      expect(find.text('Recitation Paused: Practice Word'), findsOneWidget);
      expect(find.text('Expected Word'), findsOneWidget);
      expect(find.text('What Was Heard'), findsOneWidget);
      expect(find.text('Listening for correction...'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // 3. User corrects the mistake: says "الله"
      // ignore: invalid_use_of_protected_member
      (state as dynamic).simulateRealtimeTranscript('قل هو الرحمن الله');
      await tester.pump();

      // Mistake is resolved, studio resumes normal listening
      expect(find.text('Recitation Paused: Practice Word'), findsNothing);
      expect(find.textContaining('Listening'), findsWidgets);
    });

    testWidgets('User can skip an active mistake to resume recitation', (tester) async {
      final modal = PronunciationCheckerModal(
        title: 'Al-Ikhlas • Ayah 1',
        arabicText: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
        transliteration: 'Qul Huwa Allahu Ahad',
        surahNumber: 112,
        verseNumber: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: modal),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(PronunciationCheckerModal));

      // User makes a mistake
      // ignore: invalid_use_of_protected_member
      (state as dynamic).simulateRealtimeTranscript('قل هو الرحمن');
      await tester.pump();

      expect(find.text('Recitation Paused: Practice Word'), findsOneWidget);

      // User taps "Skip Word" in the pinned sticky top bar
      await tester.tap(find.text('Skip Word'));
      await tester.pump();

      // Paused state cleared, resumed listening
      expect(find.text('Recitation Paused: Practice Word'), findsNothing);
      expect(find.textContaining('Listening'), findsWidgets);
    });

    testWidgets('Auto-stop detection completes recitation automatically upon finishing Ayah', (tester) async {
      final modal = PronunciationCheckerModal(
        title: 'Al-Ikhlas • Ayah 1',
        arabicText: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
        transliteration: 'Qul Huwa Allahu Ahad',
        surahNumber: 112,
        verseNumber: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: modal),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(PronunciationCheckerModal));

      // Recite the complete Ayah accurately
      // ignore: invalid_use_of_protected_member
      (state as dynamic).simulateRealtimeTranscript('قل هو الله احد');
      await tester.pump();

      // Fast-forward past the 900ms silence auto-stop timer
      await tester.pump(const Duration(milliseconds: 1000));
      // Fast-forward past analyzing delay
      await tester.pump(const Duration(milliseconds: 200));

      // Completed state is reached automatically without tapping Stop!
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Next Ayah'), findsOneWidget);
    });
  });
}
