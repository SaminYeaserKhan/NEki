import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/quran/surah_reader_screen.dart';
import 'package:neki/features/quran/widgets/ayah_navigation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AyahNavigationSheet Widget Tests (Simplified UI)', () {
    testWidgets('stepper increment/decrement and direct typing work with validation', (tester) async {
      int? selectedAyah;
      bool? isPlay;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AyahNavigationSheet(
              surahNumber: 2,
              totalVerses: 286,
              currentVerse: 1,
              onAyahSelected: (ayah, play) {
                selectedAyah = ayah;
                isPlay = play;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & info
      expect(find.text('Go to Ayah'), findsOneWidget);
      expect(find.byIcon(Icons.format_list_numbered_rounded), findsOneWidget);

      // Increment using plus button
      final plusButton = find.byTooltip('Next Ayah');
      await tester.tap(plusButton);
      await tester.pump();
      expect(find.text('Navigate to Ayah 2'), findsOneWidget);

      // Decrement using minus button
      final minusButton = find.byTooltip('Previous Ayah');
      await tester.tap(minusButton);
      await tester.pump();
      expect(find.text('Navigate to Ayah 1'), findsOneWidget);

      // Enter an invalid number: 300
      final textField = find.byType(TextField);
      await tester.enterText(textField, '300');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Enter an Ayah between 1 and 286'), findsOneWidget);
      expect(selectedAyah, isNull);

      // Enter valid number: 255
      await tester.enterText(textField, '255');
      await tester.pump();
      expect(find.text('Navigate to Ayah 255'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(selectedAyah, equals(255));
      expect(isPlay, isFalse);
    });

    testWidgets('landmark chip Ayat al-Kursi directly selects Ayah 255', (tester) async {
      int? selectedAyah;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AyahNavigationSheet(
              surahNumber: 2,
              totalVerses: 286,
              currentVerse: 1,
              onAyahSelected: (ayah, _) => selectedAyah = ayah,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Ayat al-Kursi (255) landmark chip
      final chip = find.text('Ayat al-Kursi (255)');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pump();

      // Verify button updates to Navigate to Ayah 255
      expect(find.text('Navigate to Ayah 255'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(selectedAyah, equals(255));
    });
  });

  group('SurahReaderScreen Ayah Navigation Tests', () {
    testWidgets('top button with format_list_numbered icon opens simplified jump modal', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SurahReaderScreen(
              surahNumber: 2,
              initialVerse: 1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check top toolbar Ayah indicator text
      expect(find.text('Ayah 1 of 286'), findsOneWidget);

      // Verify the toolbar jump button has format_list_numbered_rounded icon (not explore/compass)
      expect(find.byTooltip('Go to Ayah'), findsOneWidget);
      expect(find.byIcon(Icons.format_list_numbered_rounded), findsWidgets);

      // Tap toolbar jump button to open modal
      await tester.tap(find.byTooltip('Go to Ayah'));
      await tester.pumpAndSettle();

      // Tap Ayat al-Kursi chip
      await tester.tap(find.text('Ayat al-Kursi (255)'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Navigate to Ayah 255'));
      await tester.pumpAndSettle();

      // Verify top bar updated to Ayah 255
      expect(find.text('Ayah 255 of 286'), findsOneWidget);
    });

    testWidgets('initializes to initialVerse when passed', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SurahReaderScreen(
              surahNumber: 2,
              initialVerse: 153,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ayah 153 of 286'), findsOneWidget);
    });

    testWidgets('navigates from Ayah 1 to Ayah 95 on first attempt and highlights card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SurahReaderScreen(
              surahNumber: 2,
              initialVerse: 1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially at Ayah 1
      expect(find.text('Ayah 1 of 286'), findsOneWidget);
      expect(find.text('2:95'), findsNothing);

      // Open jump sheet
      await tester.tap(find.byTooltip('Go to Ayah'));
      await tester.pumpAndSettle();

      // Type 95 in the text field
      final textField = find.byType(TextField);
      await tester.enterText(textField, '95');
      await tester.pump();

      // Click "Navigate to Ayah 95"
      final navigateButton = find.widgetWithText(ElevatedButton, 'Navigate to Ayah 95');
      expect(navigateButton, findsOneWidget);
      await tester.tap(navigateButton);
      await tester.pumpAndSettle();

      // Verify on first attempt:
      // 1. Ayah 95 card is now visible on screen
      expect(find.text('2:95'), findsOneWidget);

      // 2. Top bar updated to Ayah 95
      expect(find.text('Ayah 95 of 286'), findsOneWidget);
    });
  });
}

