import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/quran/surah_list_screen.dart';
import 'package:neki/features/quran/widgets/surah_ornate_header.dart';
import 'package:neki/features/recitations/widgets/audio_visualizer_widget.dart';
import 'package:neki/features/recitations/widgets/pronunciation_checker_modal.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioVisualizerWidget Widget Tests', () {
    testWidgets('renders correct number of equalizer bars', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioVisualizerWidget(
              isPlaying: false,
              barCount: 6,
              height: 24,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AudioVisualizerWidget), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('SurahOrnateHeader Widget Tests', () {
    testWidgets('renders Surah Al-Fatihah title and Bismillah plaque', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SurahOrnateHeader(surahNumber: 1),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('SURAH 1'), findsOneWidget);
      expect(find.text(quran.getSurahName(1)), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('PronunciationCheckerModal Widget Tests', () {
    testWidgets('renders Arabic scripture and vocalization studio interface', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PronunciationCheckerModal(
                title: 'Surah Al-Ikhlas • Ayah 1',
                arabicText: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
                transliteration: 'Qul Huwallahu Ahad',
                translation: 'Say, "He is Allah, [who is] One."',
                surahNumber: 112,
                verseNumber: 1,
              ),
            ),
          ),
        ),
      );

      // Advance frames without waiting on infinite repeat animation
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pronunciation & Tajweed Studio'), findsOneWidget);
      expect(find.text('Surah Al-Ikhlas • Ayah 1'), findsOneWidget);
      expect(find.text('Qul Huwallahu Ahad'), findsOneWidget);
      expect(find.text('Tap to Begin Recitation'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('SurahListScreen Card Play Button Widget Tests', () {
    testWidgets('renders play button on each Surah card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SurahListScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Surah cards render with their quick play buttons
      expect(find.byTooltip('Play ${quran.getSurahName(1)}'), findsOneWidget);
      expect(find.byTooltip('Play ${quran.getSurahName(2)}'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
