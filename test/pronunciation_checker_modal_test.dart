import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/recitations/widgets/pronunciation_checker_modal.dart';

void main() {
  testWidgets('PronunciationCheckerModal renders scripture card and recording controls', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 300));

    // Verify modal title and scripture
    expect(find.text('Pronunciation & Tajweed Studio'), findsOneWidget);
    expect(find.text('Al-Fatihah • Ayah 1'), findsOneWidget);
    expect(find.text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'), findsOneWidget);
    expect(find.text('Bismillahir-Rahmanir-Rahim'), findsOneWidget);

    // Verify idle state controls
    expect(find.text('Tap to Begin Recitation'), findsOneWidget);
    expect(find.text('Listen to Authentic Pronunciation'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    // Verify pinned top action bar elements
    expect(find.text('Ayah 1 of 7'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('Start Reciting'), findsOneWidget);
    expect(find.text('Master Reciter'), findsOneWidget);
  });

  testWidgets('PronunciationCheckerModal language toggle switches text from English to Bangla', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 300));

    // Initially in English
    expect(find.text('Bismillahir-Rahmanir-Rahim'), findsOneWidget);
    expect(find.text('Ayah 1 of 7'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);

    // Tap the [বাং / EN] toggle button
    await tester.tap(find.text('EN'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify toggled to Bangla
    expect(find.text('বাং'), findsOneWidget);
    expect(find.text('আয়াত 1 / 7'), findsOneWidget);
    expect(find.text('Bismillahir-Rahmanir-Rahim'), findsNothing);

    // Tap back to English
    await tester.tap(find.text('বাং'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify back to English
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('Ayah 1 of 7'), findsOneWidget);
    expect(find.text('Bismillahir-Rahmanir-Rahim'), findsOneWidget);
  });

  testWidgets('PronunciationCheckerModal displays sticky top action bar with Try Again and Next Ayah in completed state', (tester) async {
    final modal = PronunciationCheckerModal(
      title: 'Al-Fatihah • Ayah 1',
      arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      transliteration: 'Bismillahir-Rahmanir-Rahim',
      translation: 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
      surahNumber: 1,
      verseNumber: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: modal,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Access state and trigger simulation
    final state = tester.state(find.byType(PronunciationCheckerModal));
    // Invoke recitation simulation
    // ignore: invalid_use_of_protected_member
    (state as dynamic).simulateRecitation();

    // Fast-forward past analyzing delay
    await tester.pump(const Duration(milliseconds: 900));

    // Verify completed state renders sticky top action buttons
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Next Ayah'), findsOneWidget);
    expect(find.text('Master Reciter'), findsOneWidget);

    // Verify celebratory flawless banner when all words are correct
    expect(find.text('MashaAllah! Flawless Pronunciation'), findsOneWidget);
  });

  testWidgets('PronunciationCheckerModal displays actionable mistake diagnosis and tongue guidance', (tester) async {
    final modal = PronunciationCheckerModal(
      title: 'Al-Fatihah • Ayah 6',
      arabicText: 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
      transliteration: 'Ihdinas-Siraatal-Mustaqeem',
      translation: 'Guide us to the straight path',
      surahNumber: 1,
      verseNumber: 6,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: modal,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final state = tester.state(find.byType(PronunciationCheckerModal));
    // Simulate speech where user said 'سراط' instead of heavy 'صراط'
    // ignore: invalid_use_of_protected_member
    (state as dynamic).simulateRecitation(spokenOverride: 'اهدنا سراط المستقيم');

    await tester.pump(const Duration(milliseconds: 900));

    // Verify "Where You Went Wrong & How to Fix" section appears
    expect(find.text('Where You Went Wrong & How to Fix'), findsOneWidget);
    expect(find.text('Heard: سراط'), findsOneWidget);

    // Verify actionable "How to Fix: " guidance is rendered
    expect(find.textContaining('How to Fix:'), findsWidgets);

    // Verify sticky action bar is readily available at the top without scrolling
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Next Ayah'), findsOneWidget);
  });
}
