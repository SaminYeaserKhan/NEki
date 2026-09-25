import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/core/locale/locale_provider.dart';
import 'package:neki/features/namaz/screens/namaz_screen.dart';
import 'package:neki/features/namaz/widgets/location_selector_sheet.dart';
import 'package:neki/features/namaz/widgets/namaz_home_card.dart';

void main() {
  group('NamazScreen Widget Tests', () {
    testWidgets('renders NamazScreen with 4 tabs and title in English',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _EnglishLocaleNotifier()),
          ],
          child: const MaterialApp(
            home: NamazScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify tabs exist
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Tracker'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify Today tab content renders
      expect(find.text('Fajr'), findsWidgets);
      expect(find.text('Dhuhr'), findsWidgets);
      expect(find.text('Asr'), findsWidgets);
      expect(find.text('Maghrib'), findsWidgets);
      expect(find.text('Isha'), findsWidgets);
      expect(find.text('Qibla Direction'), findsOneWidget);

      // Verify audio volume button is NOT in today prayer rows
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      expect(find.byIcon(Icons.stop_circle_rounded), findsNothing);
    });

    testWidgets('switching to Tracker tab renders daily checklist and qaza deck',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _EnglishLocaleNotifier()),
          ],
          child: const MaterialApp(
            home: NamazScreen(initialTabIndex: 2),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Obligatory (Farz) Prayers'), findsOneWidget);
      expect(find.text('Fajr (2 Farz)'), findsOneWidget);
      expect(find.text('Dhuhr (4 Farz)'), findsOneWidget);
      expect(find.text('Qaza-e-Umri Tracker'), findsOneWidget);
    });

    testWidgets('switching to Settings tab renders juristic method options and info modals',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _EnglishLocaleNotifier()),
          ],
          child: const MaterialApp(
            home: NamazScreen(initialTabIndex: 3),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('App Language'), findsOneWidget);
      expect(find.text('Juristic Method (Madhab)'), findsOneWidget);
      expect(find.text('Hanafi (Standard in South Asia)'), findsOneWidget);
      expect(find.text("Shafi'i, Maliki, Hanbali (Earlier Asr)"), findsOneWidget);
      expect(find.text('Calculation Method Convention'), findsOneWidget);
      expect(find.text('Azan Audio & Tones'), findsOneWidget);

      // Verify small info 'i' icons exist next to sections
      final infoIcons = find.byIcon(Icons.info_outline_rounded);
      expect(infoIcons, findsWidgets);

      // Tap the first info icon (App Language info)
      await tester.tap(infoIcons.first);
      await tester.pumpAndSettle();

      // Verify info modal sheet opened
      expect(find.text('App Language Selection'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      // Dismiss the modal using close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('App Language Selection'), findsNothing);
    });
  });

  group('LocationSelectorSheet Widget Tests', () {
    testWidgets('renders GPS button and list of cities in English',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _EnglishLocaleNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LocationSelectorSheet(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Select Location'), findsOneWidget);
      expect(find.text('Use Device GPS Location'), findsOneWidget);
      expect(find.text('Popular & Major Cities'), findsOneWidget);
      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Chittagong'), findsOneWidget);
    });
  });

  group('NamazHomeCard Widget Tests', () {
    testWidgets('renders on home page with 5 prayer pills in English',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith(() => _EnglishLocaleNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: NamazHomeCard(hour: 12),
              ),
            ),
          ),
        ),
      );

      // Advance stream by 1 second to emit initial WaqtData
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("Today's Prayer Times"), findsOneWidget);
      expect(find.text('Fajr'), findsWidgets);
      expect(find.text('Dhuhr'), findsWidgets);
      expect(find.text('Asr'), findsWidgets);
      expect(find.text('Maghrib'), findsWidgets);
      expect(find.text('Isha'), findsWidgets);
      expect(find.text('Full Schedule & Tracker ➔'), findsOneWidget);
    });
  });
}

class _EnglishLocaleNotifier extends LocaleNotifier {
  @override
  AppLocale build() => AppLocale.english;
}
