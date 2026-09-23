import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/core/locale/locale_provider.dart';
import 'package:neki/features/dua/dua_detail_screen.dart';
import 'package:neki/features/dua/dua_list_screen.dart';
import 'package:neki/features/dua/dua_provider.dart';
import 'package:neki/features/dua/dua_screen.dart';
import 'package:neki/features/quran/quran_provider.dart';
import 'package:neki/features/recitations/providers/reading_settings_provider.dart';
import 'package:neki/features/recitations/utils/translation_speech_helper.dart';
import 'package:neki/features/recitations/widgets/global_reading_control_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ReadingSettingsProvider - Display Presets & Empty Guard', () {
    test('Initial defaults have all elements enabled and recitation track mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(readingSettingsProvider);
      expect(settings.showArabic, isTrue);
      expect(settings.showTransliteration, isTrue);
      expect(settings.showTranslation, isTrue);
      expect(settings.audioTrackMode, equals(AudioTrackMode.recitation));
    });

    test('Presets correctly configure Translation Only, Pronunciation Only, Both, and All Three', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(readingSettingsProvider.notifier);

      // 1. Translation Only
      notifier.setDisplayPreset(arabic: false, transliteration: false, translation: true);
      var state = container.read(readingSettingsProvider);
      expect(state.showArabic, isFalse);
      expect(state.showTransliteration, isFalse);
      expect(state.showTranslation, isTrue);

      // 2. Pronunciation Only
      notifier.setDisplayPreset(arabic: false, transliteration: true, translation: false);
      state = container.read(readingSettingsProvider);
      expect(state.showArabic, isFalse);
      expect(state.showTransliteration, isTrue);
      expect(state.showTranslation, isFalse);

      // 3. Both (Translation + Pronunciation)
      notifier.setDisplayPreset(arabic: false, transliteration: true, translation: true);
      state = container.read(readingSettingsProvider);
      expect(state.showArabic, isFalse);
      expect(state.showTransliteration, isTrue);
      expect(state.showTranslation, isTrue);

      // 4. All Three
      notifier.setDisplayPreset(arabic: true, transliteration: true, translation: true);
      state = container.read(readingSettingsProvider);
      expect(state.showArabic, isTrue);
      expect(state.showTransliteration, isTrue);
      expect(state.showTranslation, isTrue);
    });

    test('Empty-card guard prevents all 3 elements from being turned off simultaneously', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(readingSettingsProvider.notifier);

      // Leave only translation active
      notifier.setDisplayPreset(arabic: false, transliteration: false, translation: true);
      var state = container.read(readingSettingsProvider);
      expect(state.showTranslation, isTrue);

      // Attempt to toggle translation off -> should be blocked by guard!
      notifier.toggleTranslation();
      state = container.read(readingSettingsProvider);
      expect(state.showTranslation, isTrue, reason: 'Guard must prevent all elements from disappearing');

      // Now enable transliteration, then translation can be toggled off
      notifier.toggleTransliteration();
      state = container.read(readingSettingsProvider);
      expect(state.showTransliteration, isTrue);
      expect(state.showTranslation, isTrue);

      notifier.toggleTranslation();
      state = container.read(readingSettingsProvider);
      expect(state.showTranslation, isFalse);
      expect(state.showTransliteration, isTrue);

      // Attempt to toggle transliteration off when it is the sole active element -> blocked!
      notifier.toggleTransliteration();
      state = container.read(readingSettingsProvider);
      expect(state.showTransliteration, isTrue);
    });

    test('AudioTrackMode toggles and sets properly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(readingSettingsProvider.notifier);
      expect(container.read(readingSettingsProvider).audioTrackMode, equals(AudioTrackMode.recitation));

      notifier.setAudioTrackMode(AudioTrackMode.translation);
      expect(container.read(readingSettingsProvider).audioTrackMode, equals(AudioTrackMode.translation));

      notifier.toggleAudioTrackMode();
      expect(container.read(readingSettingsProvider).audioTrackMode, equals(AudioTrackMode.recitation));
    });

    test('FontSizePreset cycling switches through Small, Medium, Large, and Extra Large', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(readingSettingsProvider.notifier);
      // Default is medium (26pt Arabic, 14pt Translation)
      expect(container.read(readingSettingsProvider).currentFontSizePreset, equals(FontSizePreset.medium));

      // 1. Medium -> Large
      await notifier.cycleFontSizePreset();
      var state = container.read(readingSettingsProvider);
      expect(state.currentFontSizePreset, equals(FontSizePreset.large));
      expect(state.arabicFontSize, equals(32.0));
      expect(state.translationFontSize, equals(16.5));

      // 2. Large -> Extra Large
      await notifier.cycleFontSizePreset();
      state = container.read(readingSettingsProvider);
      expect(state.currentFontSizePreset, equals(FontSizePreset.extraLarge));
      expect(state.arabicFontSize, equals(38.0));
      expect(state.translationFontSize, equals(19.5));

      // 3. Extra Large -> Small
      await notifier.cycleFontSizePreset();
      state = container.read(readingSettingsProvider);
      expect(state.currentFontSizePreset, equals(FontSizePreset.small));
      expect(state.arabicFontSize, equals(22.0));
      expect(state.translationFontSize, equals(12.5));

      // 4. Small -> Medium
      await notifier.cycleFontSizePreset();
      state = container.read(readingSettingsProvider);
      expect(state.currentFontSizePreset, equals(FontSizePreset.medium));
      expect(state.arabicFontSize, equals(26.0));
      expect(state.translationFontSize, equals(14.0));
    });

    test('applyFontSizePreset applies direct preset values accurately', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(readingSettingsProvider.notifier);

      await notifier.applyFontSizePreset(FontSizePreset.extraLarge);
      expect(container.read(readingSettingsProvider).arabicFontSize, equals(38.0));
      expect(container.read(readingSettingsProvider).translationFontSize, equals(19.5));
      expect(container.read(readingSettingsProvider).currentFontSizePreset, equals(FontSizePreset.extraLarge));

      await notifier.applyFontSizePreset(FontSizePreset.small);
      expect(container.read(readingSettingsProvider).arabicFontSize, equals(22.0));
      expect(container.read(readingSettingsProvider).translationFontSize, equals(12.5));
      expect(container.read(readingSettingsProvider).currentFontSizePreset, equals(FontSizePreset.small));
    });
  });

  group('TranslationSpeechHelper - Speech Synthesis Utilities', () {
    test('Sanitizes HTML tags, citations, and brackets cleanly', () {
      const rawText = '<b>In the name</b> of Allah [1]. (Recite 3 times)';
      final clean = TranslationSpeechHelper.sanitizeText(rawText);

      expect(clean.contains('<b>'), isFalse);
      expect(clean.contains('</b>'), isFalse);
      expect(clean.contains('[1]'), isFalse);
      expect(clean.startsWith('In the name of Allah'), isTrue);
    });

    test('Splits long text into speakable chunks under max chunk length', () {
      final longBengaliText = 'নিশ্চয়ই সমস্ত প্রশংসা আল্লাহর জন্য। আমরা তাঁরই প্রশংসা করি, তাঁরই কাছে সাহায্য চাই এবং তাঁরই কাছে ক্ষমা প্রার্থনা করি। আর আমরা আমাদের নফসের অনিষ্ট ও মন্দ কাজ থেকে আল্লাহর কাছে আশ্রয় চাই। যাকে আল্লাহ সৎপথ প্রদর্শন করেন তাকে বিভ্রান্তকারী কেউ নেই, আর যাকে তিনি পথভ্রষ্ট করেন তাকে পথপ্রদর্শনকারী কেউ নেই।';

      final chunks = TranslationSpeechHelper.splitIntoSpeakableChunks(longBengaliText, maxLen: 120);

      expect(chunks.isNotEmpty, isTrue);
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(125)); // Within boundary buffer
        expect(chunk.trim().isNotEmpty, isTrue);
      }
    });

    test('Builds valid Google TTS URLs with correct language parameter', () {
      final urlBn = TranslationSpeechHelper.getSpeechUrl('বিসমিল্লাহ', 'bn');
      expect(urlBn, contains('translate.google.com/translate_tts'));
      expect(urlBn, contains('tl=bn'));
      expect(urlBn, contains('client=tw-ob'));

      final urlEn = TranslationSpeechHelper.getSpeechUrl('Praise be to Allah', 'en');
      expect(urlEn, contains('tl=en'));
    });
  });

  group('Global Language Synchronization Tests', () {
    test('Language toggle updates both localeProvider and translationProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default is Bangla
      expect(container.read(localeProvider), equals(AppLocale.bangla));
      expect(container.read(translationProvider), equals(TranslationLang.bengali));

      // Switch to English via localeNotifier
      container.read(localeProvider.notifier).setLocale(AppLocale.english);
      expect(container.read(localeProvider), equals(AppLocale.english));
      expect(container.read(translationProvider), equals(TranslationLang.english));

      // Switch back via translationProvider
      container.read(translationProvider.notifier).setLang(TranslationLang.bengali);
      expect(container.read(translationProvider), equals(TranslationLang.bengali));
      expect(container.read(localeProvider), equals(AppLocale.bangla));
    });
  });

  group('GlobalReadingControlBar Widget Tests', () {
    testWidgets('Renders element chips, track switch, preset dropdown, and language toggle', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GlobalReadingControlBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check element chips
      expect(find.text('ع'), findsOneWidget); // Arabic chip
      expect(find.text('A'), findsOneWidget); // Font size presets switcher
      expect(find.text('বাং'), findsOneWidget); // Language switcher
      expect(find.text('আরবি'), findsOneWidget); // Audio track button (Arabic recitation)

      // Settings icon button exists
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('Tapping language toggle switches locale', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalReadingControlBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(localeProvider), equals(AppLocale.bangla));
      expect(find.text('বাং'), findsOneWidget);

      // Tap language switch
      await tester.tap(find.text('বাং'));
      await tester.pumpAndSettle();

      // State is now English
      expect(container.read(localeProvider), equals(AppLocale.english));
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('Tapping audio track toggle switches between Arabic and Translation in Bangla and English', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalReadingControlBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(readingSettingsProvider).audioTrackMode, equals(AudioTrackMode.recitation));

      // Initially in Bangla: says 'আরবি'
      expect(find.text('আরবি'), findsOneWidget);

      // Tap audio track toggle
      await tester.tap(find.text('আরবি'));
      await tester.pumpAndSettle();

      // State is now translation: says 'অনুবাদ'
      expect(container.read(readingSettingsProvider).audioTrackMode, equals(AudioTrackMode.translation));
      expect(find.text('অনুবাদ'), findsOneWidget);

      // Switch language to English
      await tester.tap(find.text('বাং'));
      await tester.pumpAndSettle();

      // In English, translation mode displays 'Translation'
      expect(find.text('Translation'), findsOneWidget);

      // Tap audio track toggle back to recitation
      await tester.tap(find.text('Translation'));
      await tester.pumpAndSettle();

      // In English, recitation mode displays 'Arabic'
      expect(find.text('Arabic'), findsOneWidget);
      expect(container.read(readingSettingsProvider).audioTrackMode, equals(AudioTrackMode.recitation));
    });

    testWidgets('Tapping settings button opens RecitationSettingsSheet with zero framework exceptions', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalReadingControlBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap tune / settings icon
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears
      expect(find.text('কার্ড উপাদান প্রদর্শন প্রিসেট'), findsOneWidget);
      expect(find.text('আরবি মূলপাঠ প্রদর্শন'), findsOneWidget);
      expect(find.text('উচ্চারণ / ট্রান্সলিটারেশন প্রদর্শন'), findsOneWidget);
      expect(find.text('অনুবাদ প্রদর্শন'), findsOneWidget);

      // Verify toggling switches works smoothly without assertions
      await tester.ensureVisible(find.text('আরবি মূলপাঠ প্রদর্শন'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('আরবি মূলপাঠ প্রদর্শন'));
      await tester.pumpAndSettle();
      expect(container.read(readingSettingsProvider).showArabic, isFalse);

      // Tap All Three preset
      await tester.ensureVisible(find.text('সবগুলো (All Three)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('সবগুলো (All Three)'));
      await tester.pumpAndSettle();
      expect(container.read(readingSettingsProvider).showArabic, isTrue);
    });

    testWidgets('Tapping "A" button cycles font size preset and shows feedback toast', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalReadingControlBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(readingSettingsProvider).currentFontSizePreset, equals(FontSizePreset.medium));
      expect(find.text('A'), findsOneWidget);

      // Tap 'A' button -> should cycle from Medium to Large
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      expect(container.read(readingSettingsProvider).currentFontSizePreset, equals(FontSizePreset.large));
      expect(container.read(readingSettingsProvider).arabicFontSize, equals(32.0));
      expect(find.textContaining('বড়'), findsOneWidget);

      // Tap 'A' button again -> should cycle from Large to Extra Large
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      expect(container.read(readingSettingsProvider).currentFontSizePreset, equals(FontSizePreset.extraLarge));
      expect(container.read(readingSettingsProvider).arabicFontSize, equals(38.0));
      expect(find.textContaining('অনেক বড়'), findsOneWidget);
    });

    testWidgets('Long-pressing "A" button opens font size presets bottom sheet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: GlobalReadingControlBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press 'A' button
      await tester.longPress(find.text('A'));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears with font size options
      expect(find.text('হরফের আকার নির্বাচন'), findsOneWidget);
      expect(find.text('ছোট (Small)'), findsOneWidget);
      expect(find.text('সাধারণ (Medium)'), findsOneWidget);
      expect(find.text('বড় (Large)'), findsOneWidget);
      expect(find.text('অনেক বড় (Extra Large)'), findsOneWidget);

      // Tap Extra Large
      await tester.ensureVisible(find.text('অনেক বড় (Extra Large)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('অনেক বড় (Extra Large)'));
      await tester.pumpAndSettle();

      expect(container.read(readingSettingsProvider).currentFontSizePreset, equals(FontSizePreset.extraLarge));
      expect(container.read(readingSettingsProvider).arabicFontSize, equals(38.0));
    });

    testWidgets('DuaDetailScreen reacts to "A" font size preset button and scales typography', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testDua = Dua(
        id: 1,
        category: 'daily',
        title: 'Morning Prayer',
        arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا',
        transliteration: 'Alhamdu lillahil-ladhi ahyana',
        description: 'All praise is for Allah who gave us life.',
        bengali: 'সমস্ত প্রশংসা আল্লাহর জন্য যিনি আমাদের জীবন দান করেছেন।',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuaDetailScreen(
              duas: [testDua],
              initialIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Arabic text widget and verify initial font size (Medium preset: 26.0pt)
      var arabicWidget = tester.widget<Text>(find.text(testDua.arabic));
      expect(arabicWidget.style?.fontSize, equals(26.0));

      // Tap 'A' button to switch to Large preset (32.0pt)
      expect(find.text('A'), findsOneWidget);
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      // Verify Arabic text updated to 32.0pt
      arabicWidget = tester.widget<Text>(find.text(testDua.arabic));
      expect(arabicWidget.style?.fontSize, equals(32.0));

      // Tap 'A' button again to switch to Extra Large preset (38.0pt)
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      arabicWidget = tester.widget<Text>(find.text(testDua.arabic));
      expect(arabicWidget.style?.fontSize, equals(38.0));
    });

    testWidgets('DuaListScreen card text dynamically scales when "A" button is tapped', (tester) async {
      const testDua = Dua(
        id: 1,
        category: 'daily',
        title: 'Morning Prayer',
        arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا',
        transliteration: 'Alhamdu lillahil-ladhi ahyana',
        description: 'All praise is for Allah who gave us life.',
        bengali: 'সমস্ত প্রশংসা আল্লাহর জন্য যিনি আমাদের জীবন দান করেছেন।',
      );

      final container = ProviderContainer(
        overrides: [
          duasByCategoryProvider('daily').overrideWith((ref) => Future.value([testDua])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DuaListScreen(categoryId: 'daily'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial Arabic text font size is Medium (26.0pt)
      var arabicWidget = tester.widget<Text>(find.text(testDua.arabic));
      expect(arabicWidget.style?.fontSize, equals(26.0));

      // Tap 'A' button to cycle to Large (32.0pt)
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      arabicWidget = tester.widget<Text>(find.text(testDua.arabic));
      expect(arabicWidget.style?.fontSize, equals(32.0));
    });

    testWidgets('DuaScreen embeds GlobalReadingControlBar and scales fonts when "A" button is tapped', (tester) async {
      const testDua = Dua(
        id: 1,
        category: 'daily',
        title: 'Morning Prayer',
        arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا',
        transliteration: 'Alhamdu lillahil-ladhi ahyana',
        description: 'All praise is for Allah who gave us life.',
        bengali: 'সমস্ত প্রশংসা আল্লাহর জন্য যিনি আমাদের জীবন দান করেছেন।',
      );

      final container = ProviderContainer(
        overrides: [
          duaViewModeProvider.overrideWith((ref) => DuaViewMode.shortDuas),
          popularShortDuasProvider.overrideWith((ref) => Future.value([testDua])),
          quranicDuasProvider.overrideWith((ref) => Future.value([testDua])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DuaScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 'A' button is rendered on DuaScreen
      expect(find.text('A'), findsOneWidget);

      var arabicWidget = tester.widget<Text>(find.text(testDua.arabic));
      expect(arabicWidget.style?.fontSize, equals(26.0));

      // Tap 'A' button
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      arabicWidget = tester.widget<Text>(find.text(testDua.arabic));
      expect(arabicWidget.style?.fontSize, equals(32.0));
    });
  });
}
