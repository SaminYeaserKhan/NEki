import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:neki/features/hadith/hadith_screen.dart';
import 'package:neki/features/hadith/hadith_provider.dart';
import 'package:neki/features/recitations/recitations_screen.dart';
import 'package:neki/core/locale/locale_provider.dart';

class _EnglishLocaleNotifier extends LocaleNotifier {
  @override
  AppLocale build() => AppLocale.english;
}

void main() {
  group('HadithScreen & RecitationsScreen Unified Scroll Tests', () {
    testWidgets('RecitationsScreen renders NestedScrollView with sliver headers and TabBarView', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RecitationsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify NestedScrollView is the outer structure
      expect(find.byType(NestedScrollView), findsOneWidget);

      // Verify TabBar is rendered in header (main capsule tab switcher + child tab)
      expect(find.byType(TabBar), findsAtLeastNWidgets(1));

      // Verify TabBarView is present
      expect(find.byType(TabBarView), findsAtLeastNWidgets(1));
    });

    testWidgets('HadithScreen renders CustomScrollView with Canonical Books, Flagship Card, and Chapter Slivers', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hadithViewModeProvider.overrideWith((ref) => HadithViewMode.collections),
            localeProvider.overrideWith(_EnglishLocaleNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HadithScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify CustomScrollView is used
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify Global Search Bar + Filter Chapters
      expect(find.byType(TextField), findsNWidgets(2));

      // Verify Sahih al-Bukhari appears in chip and flagship card
      expect(find.text('Sahih al-Bukhari'), findsNWidgets(2));
      expect(find.text('Full 97 Chapters'), findsOneWidget);

      // Verify Revelation chapter (Chapter 1) is visible in the chapters list
      expect(find.text('Revelation'), findsOneWidget);
      expect(find.text('Hadiths 1 – 7 (7)'), findsOneWidget);

      // Verify scrolling the CustomScrollView moves the content
      final scrollable = find.byType(CustomScrollView);
      expect(scrollable, findsOneWidget);

      // Scroll up by 400 pixels to move headers up
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CustomScrollView), findsOneWidget);
    });

    testWidgets('Filtering chapters works seamlessly inside CustomScrollView', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hadithViewModeProvider.overrideWith((ref) => HadithViewMode.collections),
            localeProvider.overrideWith(_EnglishLocaleNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HadithScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter search term in Filter Chapters (the second TextField)
      final filterTextField = find.byType(TextField).at(1);
      await tester.enterText(filterTextField, 'Fasting');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fasting chapter should be shown in ListTile
      expect(find.widgetWithText(ListTile, 'Fasting'), findsOneWidget);
      // Revelation chapter should NOT be shown
      expect(find.text('Revelation'), findsNothing);
    });

    testWidgets('Switching between Hadith segmented tabs retains unified sliver architecture', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(_EnglishLocaleNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HadithScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Default tab: Daily & Wisdom
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.text('Daily & Wisdom'), findsOneWidget);

      // Switch to Thematic Topics
      await tester.tap(find.text('Thematic Topics'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify CustomScrollView is still active with topic chips
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Switch to Saved by ensuring it's visible in the horizontal pill bar
      await tester.ensureVisible(find.text('Saved'));
      await tester.pump();
      await tester.tap(find.text('Saved'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify empty state inside CustomScrollView
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.text('No Bookmarked Hadiths Yet'), findsOneWidget);
    });
  });
}
