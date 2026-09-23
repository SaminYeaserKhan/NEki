import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/core/widgets/animated_gradient_bg.dart';
import 'package:neki/core/widgets/celestial_body_widget.dart';
import 'package:neki/core/widgets/recitation_background.dart';
import 'package:neki/features/dua/dua_detail_screen.dart';
import 'package:neki/features/dua/dua_list_screen.dart';
import 'package:neki/features/dua/dua_provider.dart';
import 'package:neki/features/dua/dua_screen.dart';
import 'package:neki/features/hadith/data/bukhari_sections_data.dart';
import 'package:neki/features/hadith/hadith_detail_screen.dart';
import 'package:neki/features/hadith/hadith_provider.dart';
import 'package:neki/features/hadith/hadith_screen.dart';
import 'package:neki/features/quran/surah_reader_screen.dart';
import 'package:neki/features/recitations/widgets/global_reading_control_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dua Enhancements & Repetitions Tests', () {
    test('recommendedRepetitions correctly extracts repetition count from English text', () {
      const dua = Dua(
        id: 4,
        category: 'morning',
        title: 'Protection from All Harm',
        arabic: 'بِسْمِ اللَّهِ الَّذِي لاَ يَضُرُّ',
        transliteration: 'Bismillahilladhi la yadurru...',
        description: 'In the name of Allah with whose Name nothing can cause harm. (Recite 3 times)',
      );
      expect(dua.recommendedRepetitions, equals(3));
    });

    test('recommendedRepetitions correctly extracts repetition count from Bengali text', () {
      const dua = Dua(
        id: 5,
        category: 'morning',
        title: 'Affirmation',
        arabic: 'رَضِيتُ بِاللَّهِ رَبًّا',
        transliteration: 'Radheetu billahi Rabba...',
        description: 'I am pleased with Allah as my Lord.',
        bengali: 'আমি সন্তুষ্টচিত্তে আল্লাহকে রব হিসেবে গ্রহণ করেছি। (৩ বার পাঠ্য)',
      );
      expect(dua.recommendedRepetitions, equals(3));
    });

    test('recommendedRepetitions defaults to 1 when no count is stated', () {
      const dua = Dua(
        id: 1,
        category: 'morning',
        title: 'Morning Supplication',
        arabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
        transliteration: 'Asbahna wa asbahal mulku lillah...',
        description: 'We have reached the morning and all sovereignty belongs to Allah.',
      );
      expect(dua.recommendedRepetitions, equals(1));
    });

    test('DuaBookmarkNotifier toggles bookmarks correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(duaBookmarkProvider.notifier);
      expect(container.read(duaBookmarkProvider).contains(42), isFalse);

      await notifier.toggle(42);
      expect(container.read(duaBookmarkProvider).contains(42), isTrue);

      await notifier.toggle(42);
      expect(container.read(duaBookmarkProvider).contains(42), isFalse);
    });
  });

  group('RecitationBackground & AnimatedGradientBackground Flags', () {
    testWidgets('RecitationBackground renders tranquil canvas with sacred geometry and child', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RecitationBackground(
              child: Text('Bismillahir-Rahmanir-Rahim'),
            ),
          ),
        ),
      );

      expect(find.text('Bismillahir-Rahmanir-Rahim'), findsOneWidget);
      expect(find.byType(RecitationBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('AnimatedGradientBackground can suppress celestial body and clouds', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AnimatedGradientBackground(
              showCelestialBody: false,
              showClouds: false,
              showBirds: false,
              showMosque: false,
              showStars: false,
              child: Text('Quiet Gradient'),
            ),
          ),
        ),
      );

      expect(find.text('Quiet Gradient'), findsOneWidget);
      // CelestialBodyWidget must not be rendered when showCelestialBody is false
      expect(find.byType(CelestialBodyWidget), findsNothing);
    });
  });

  group('DuaDetailScreen UI & Elements Tests', () {
    testWidgets('DuaDetailScreen renders RecitationBackground, quick pill, and cards', (tester) async {
      const testDuas = [
        Dua(
          id: 1,
          category: 'morning',
          title: 'Morning Dua 1',
          arabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
          transliteration: 'Asbahna wa asbahal mulku lillah',
          description: 'We have reached the morning.',
        ),
        Dua(
          id: 2,
          category: 'morning',
          title: 'Morning Dua 2',
          arabic: 'اللَّهُمَّ بِكَ أَصْبَحْنَا',
          transliteration: 'Allahumma bika asbahna',
          description: 'O Allah, by You we enter the morning.',
        ),
      ];

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DuaDetailScreen(
              duas: testDuas,
              initialIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // RecitationBackground is used instead of clashing AnimatedGradientBackground
      expect(find.byType(RecitationBackground), findsOneWidget);
      expect(find.byType(AnimatedGradientBackground), findsNothing);

      // Verify category title and supplication counts
      expect(find.text('MORNING'), findsOneWidget);
      expect(find.text('Morning Dua 1'), findsWidgets);

      // Verify Typography / Display Settings button is present
      expect(find.byTooltip('Typography & Display Settings'), findsOneWidget);

      // Verify Recite & Check action button is present (Bangla default)
      expect(find.text('উচ্চারণ যাচাই'), findsWidgets);
    });

    testWidgets('DuaDetailScreen bottom panning component scrolls and navigates between multiple duas', (tester) async {
      const testDuas = [
        Dua(
          id: 1,
          category: 'morning',
          title: 'Morning Dua 1',
          arabic: 'الحَمْدُ لِلَّهِ',
          transliteration: 'Alhamdu lillah',
          description: 'Praise be to Allah 1.',
        ),
        Dua(
          id: 2,
          category: 'morning',
          title: 'Morning Dua 2',
          arabic: 'اللَّهُمَّ بِكَ أَصْبَحْنَا',
          transliteration: 'Allahumma bika asbahna',
          description: 'O Allah, by You we enter the morning 2.',
        ),
        Dua(
          id: 3,
          category: 'morning',
          title: 'Morning Dua 3',
          arabic: 'أَصْبَحْنَا وَأَصْبَحَ المُلْكُ لِلَّهِ',
          transliteration: 'Asbahna wa-asbahal-mulku lillah',
          description: 'We have entered the morning 3.',
        ),
        Dua(
          id: 4,
          category: 'morning',
          title: 'Morning Dua 4',
          arabic: 'اللَّهُمَّ عَافِنِي فِي بَدَنِي',
          transliteration: 'Allahumma afini fi badani',
          description: 'O Allah, grant me health in my body 4.',
        ),
      ];

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DuaDetailScreen(
              duas: testDuas,
              initialIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom panning pill buttons are rendered (#1, #2, #3, #4)
      expect(find.text('#1'), findsWidgets);
      expect(find.text('#2'), findsWidgets);
      expect(find.text('#3'), findsWidgets);
      expect(find.text('#4'), findsWidgets);

      // Verify stepper buttons
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Tap on #3 pill
      await tester.tap(find.text('#3').last);
      await tester.pumpAndSettle();

      // Verify Morning Dua 3 is in view
      expect(find.text('Morning Dua 3'), findsOneWidget);

      // Tap on #4 pill
      await tester.tap(find.text('#4').last);
      await tester.pumpAndSettle();

      // Verify Morning Dua 4 is in view
      expect(find.text('Morning Dua 4'), findsOneWidget);
    });
  });

  group('HadithDetailScreen UI & Elements Tests', () {
    testWidgets('HadithDetailScreen renders RecitationBackground, reading modes, and translation-first card', (tester) async {
      const testSection = HadithSection(
        sectionNumber: 1,
        name: 'Revelation',
        firstHadith: 1,
        lastHadith: 1,
      );

      final mockHadiths = [
        const HadithEntry(
          id: 1,
          number: 1,
          bookId: 'bukhari',
          chapter: 'Revelation',
          arabic: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
          text: 'Deeds are according to intentions.',
          english: 'Actions are judged by intentions.',
          bengali: '‘উমার ইবনুল খাত্তাব (রাঃ) হতে বর্ণিত। সমস্ত কাজ নিয়তের উপর নির্ভরশীল।',
          narrator: '‘উমার ইবনুল খাত্তাব (রাঃ)',
          reference: 'Sahih al-Bukhari 1',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hadithBySectionProvider((bookId: 'bukhari', sectionNumber: 1))
                .overrideWith((ref) => mockHadiths),
          ],
          child: const MaterialApp(
            home: HadithDetailScreen(
              bookId: 'bukhari',
              section: testSection,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // RecitationBackground is used
      expect(find.byType(RecitationBackground), findsOneWidget);
      expect(find.byType(AnimatedGradientBackground), findsNothing);

      // Section header is present
      expect(find.text('Revelation'), findsOneWidget);
      // Global Reading Control Bar is present with element toggles & track switcher
      expect(find.byType(GlobalReadingControlBar), findsOneWidget);
      expect(find.text('বাং'), findsOneWidget);

      // Translation is displayed prominently at the top
      expect(find.textContaining('সমস্ত কাজ নিয়তের উপর নির্ভরশীল'), findsOneWidget);

      // Collapsible Arabic Accordion is present
      expect(find.textContaining('মূল আরবী পাঠ'), findsOneWidget);

      // Action buttons are present (Bangla default locale)
      expect(find.text('উচ্চারণ যাচাই'), findsOneWidget);
    });

    testWidgets('HadithDetailScreen bottom panning component scrolls and navigates between multiple hadiths', (tester) async {
      const testSection = HadithSection(
        sectionNumber: 1,
        name: 'Revelation',
        firstHadith: 1,
        lastHadith: 4,
      );

      final mockHadiths = List.generate(
        4,
        (i) => HadithEntry(
          id: i + 1,
          number: i + 1,
          bookId: 'bukhari',
          chapter: 'Revelation',
          arabic: 'عَنْ عَلْقَمَةَ بْنِ وَقَّاصٍ اللَّيْثِيِّ ... $i',
          text: 'Text for hadith ${i + 1}',
          english: 'English text for hadith ${i + 1}',
          bengali: 'হাদিস নং ${i + 1}-এর বাংলা অর্থ ও ব্যাখ্যা।',
          narrator: 'বর্ণনাকারী $i',
          reference: 'Sahih al-Bukhari ${i + 1}',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hadithBySectionProvider((bookId: 'bukhari', sectionNumber: 1))
                .overrideWith((ref) => mockHadiths),
          ],
          child: const MaterialApp(
            home: HadithDetailScreen(
              bookId: 'bukhari',
              section: testSection,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom panning pill buttons are rendered (#1, #2, #3, #4)
      expect(find.text('#1'), findsWidgets);
      expect(find.text('#2'), findsWidgets);
      expect(find.text('#3'), findsWidgets);
      expect(find.text('#4'), findsWidgets);

      // Verify previous and next stepper chevron icons are rendered
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Tap on #3 pill
      await tester.tap(find.text('#3').last);
      await tester.pumpAndSettle();

      // Verify hadith 3 text is scrolled into view
      expect(find.textContaining('হাদিস নং 3-এর বাংলা অর্থ'), findsOneWidget);

      // Tap on #4 pill
      await tester.tap(find.text('#4').last);
      await tester.pumpAndSettle();

      // Verify hadith 4 text is scrolled into view
      expect(find.textContaining('হাদিস নং 4-এর বাংলা অর্থ'), findsOneWidget);
    });
  });

  group('Sahih al-Bukhari Full 97 Chapters Integration Tests', () {
    test('allBukhariSections contains all 97 authentic chapters covering hadiths 1 to 7563', () {
      expect(allBukhariSections.length, equals(97));

      // Section 1: Revelation
      final firstSection = allBukhariSections.first;
      expect(firstSection.sectionNumber, equals(1));
      expect(firstSection.nameEn, equals('Revelation'));
      expect(firstSection.nameBn, equals('ওহীর সূচনা'));
      expect(firstSection.firstHadith, equals(1));
      expect(firstSection.lastHadith, equals(7));

      // Section 97: Tawheed
      final lastSection = allBukhariSections.last;
      expect(lastSection.sectionNumber, equals(97));
      expect(lastSection.nameEn, equals('Oneness, Uniqueness of Allah (Tawheed)'));
      expect(lastSection.nameBn, equals('তাওহীদ (আল্লাহর একত্ববাদ)'));
      expect(lastSection.firstHadith, equals(7371));
      expect(lastSection.lastHadith, equals(7563));
    });

    test('hadithSectionsProvider loads all 97 chapters of Bukhari instantly offline', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sections = await container.read(hadithSectionsProvider('bukhari').future);
      expect(sections.length, equals(97));
      expect(sections.first.sectionNumber, equals(1));
      expect(sections.last.sectionNumber, equals(97));
      expect(sections.last.lastHadith, equals(7563));
    });
  });

  group('Dua Navigation & Emotion Engine Tests', () {
    test('Dua.resolvedEmotions properly classifies duas based on content', () {
      const anxiousDua = Dua(
        id: 10,
        category: 'hardship',
        title: 'For Anxiety and Sorrow',
        arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ',
        transliteration: 'Allahumma inni a\'udhu bika...',
        description: 'O Allah, I take refuge in You from anxiety and grief.',
      );
      expect(anxiousDua.resolvedEmotions, contains('anxious'));
      expect(anxiousDua.resolvedEmotions, contains('hardship'));

      const forgivenessDua = Dua(
        id: 11,
        category: 'forgiveness',
        title: 'Sayyidul Istighfar',
        arabic: 'اللَّهُمَّ أَنْتَ رَبِّي',
        transliteration: 'Allahumma anta Rabbi...',
        description: 'O Allah, You are my Lord. I seek repentance and pardon.',
      );
      expect(forgivenessDua.resolvedEmotions, contains('forgiveness'));
    });

    testWidgets('DuaScreen renders search bar and navigation pills', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DuaScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Search bar and Segment pills are visible (default: Bangla)
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('আপনার জন্য'), findsOneWidget);
      expect(find.text('বিষয়সমূহ'), findsOneWidget);
      expect(find.text('ছোট দো‘আ'), findsOneWidget);
      expect(find.text('সংরক্ষিত'), findsOneWidget);

      // Verify Recommended Dua component is removed
      expect(find.textContaining('Recommended Duas'), findsNothing);
      expect(find.textContaining('বিশেষ দো‘আ'), findsNothing);
    });

    testWidgets('Tapping ছোট দো‘আ navigation pill opens Short Duas view', (tester) async {
      const testDua = Dua(
        id: 19,
        category: 'daily',
        title: 'Before Eating',
        arabic: 'بِسْمِ اللَّهِ',
        transliteration: 'Bismillah',
        description: 'In the name of Allah',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            popularShortDuasProvider.overrideWith((ref) => Future.value([testDua])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DuaScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the 'ছোট দো‘আ' navigation pill
      await tester.tap(find.text('ছোট দো‘আ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify header card and filter chips are displayed
      expect(find.text('মুখস্থ করার মতো ছোট দো‘আ'), findsOneWidget);
      expect(find.text('দৈনন্দিন জীবন'), findsOneWidget);
      expect(find.text('সালাত ও যিকির'), findsOneWidget);
      expect(find.text('কুরআনের দো‘আ'), findsOneWidget);
      expect(find.text('সুরক্ষা ও বিপদ'), findsOneWidget);
      expect(find.text('Before Eating'), findsOneWidget);
    });
  });

  group('HadithScreen UI & Segmented Navigation Tests', () {
    testWidgets('HadithScreen renders search bar and segmented navigation pills', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HadithScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Search bar and navigation pills are visible (default: Bangla)
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('দৈনিক হেদায়েত'), findsOneWidget);
      expect(find.text('বুখারী ও গ্রন্থসমূহ'), findsOneWidget);
      expect(find.text('বিষয়ভিত্তিক'), findsOneWidget);
      expect(find.text('সংরক্ষিত'), findsOneWidget);
    });
  });

  group('DuaListScreen Category Cards UI & Full Sentences Tests', () {
    testWidgets('DuaListScreen displays full sentences without truncation and clean action strip', (tester) async {
      const testDuas = [
        Dua(
          id: 101,
          category: 'daily',
          title: 'সকাল ও সন্ধ্যার দো‘আ এবং সমস্ত ক্ষতি থেকে নিরাপত্তা',
          arabic: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
          transliteration: "Bismillahilladhi la yadurru ma'asmihi shay'un fil-ardi wa la fis-sama'i wa huwas-Sami'ul-'Alim",
          transliterationBn: 'বিসমিল্লাহিল্লাজি লা ইয়াদুররু মাআসমিহি শাইউন ফিল আরদ্বি ওয়ালা ফিস সামায়ি ওয়া হুয়াস সামিউল আলিম',
          description: 'In the name of Allah with whose Name nothing can cause harm in the earth nor in the heavens, and He is the All-Hearing, the All-Knowing.',
          bengali: 'আল্লাহর নামে, যাঁর নামের বরকতে আসমান ও জমিনের কোনো কিছুই কোনো ক্ষতি করতে পারে না, আর তিনিই সর্বশ্রোতা, সর্বজ্ঞাতা।',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            duasByCategoryProvider('daily').overrideWith((ref) => Future.value(testDuas)),
          ],
          child: const MaterialApp(
            home: DuaListScreen(categoryId: 'daily'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // RecitationBackground is used
      expect(find.byType(RecitationBackground), findsOneWidget);

      // Verify complete title without ellipsis
      expect(find.text('সকাল ও সন্ধ্যার দো‘আ এবং সমস্ত ক্ষতি থেকে নিরাপত্তা'), findsOneWidget);

      // Verify complete Arabic sentence without truncation
      expect(
        find.text('بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ'),
        findsOneWidget,
      );

      // Verify complete Bengali translation sentence without truncation
      expect(
        find.text('আল্লাহর নামে, যাঁর নামের বরকতে আসমান ও জমিনের কোনো কিছুই কোনো ক্ষতি করতে পারে না, আর তিনিই সর্বশ্রোতা, সর্বজ্ঞাতা।'),
        findsOneWidget,
      );

      // Verify Bengali pronunciation guide is visible
      expect(find.textContaining('বিসমিল্লাহিল্লাজি লা ইয়াদুররু'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('উচ্চারণ যাচাই'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'তিলাওয়াত'), findsOneWidget);

      // Verify Copy and Bookmark buttons are present
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    });

    testWidgets('DuaListScreen bottom panning bar renders for multiple duas and navigates', (tester) async {
      const testDuas = [
        Dua(
          id: 1,
          category: 'daily',
          title: 'Dua Item One',
          arabic: 'بِسْمِ اللَّهِ',
          transliteration: 'Bismillah',
          description: 'In the name of Allah 1.',
          bengali: 'আল্লাহর নামে ১।',
        ),
        Dua(
          id: 2,
          category: 'daily',
          title: 'Dua Item Two',
          arabic: 'الْحَمْدُ لِلَّهِ',
          transliteration: 'Alhamdulillah',
          description: 'Praise to Allah 2.',
          bengali: 'সকল প্রশংসা আল্লাহর ২।',
        ),
        Dua(
          id: 3,
          category: 'daily',
          title: 'Dua Item Three',
          arabic: 'سُبْحَانَ اللَّهِ',
          transliteration: 'Subhanallah',
          description: 'Glory be to Allah 3.',
          bengali: 'পবিত্র আল্লাহর মহিমা ৩।',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            duasByCategoryProvider('daily').overrideWith((ref) => Future.value(testDuas)),
          ],
          child: const MaterialApp(
            home: DuaListScreen(categoryId: 'daily'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom panning pill buttons are rendered (#1, #2, #3)
      expect(find.text('#1'), findsWidgets);
      expect(find.text('#2'), findsWidgets);
      expect(find.text('#3'), findsWidgets);

      // Tap on #3 pill
      await tester.tap(find.text('#3').last);
      await tester.pumpAndSettle();

      expect(find.text('Dua Item Three'), findsOneWidget);
    });
  });

  group('SurahReaderScreen Bottom Panning Ayah Navigation Tests', () {
    testWidgets('SurahReaderScreen renders bottom panning bar and navigates to Ayah line on pill tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SurahReaderScreen(
              surahNumber: 1, // Al-Fatiha (7 ayahs)
              initialVerse: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom panning pill buttons are rendered (#1, #2, #3, #4, #5, #6, #7)
      expect(find.text('#1'), findsWidgets);
      expect(find.text('#2'), findsWidgets);
      expect(find.text('#3'), findsWidgets);
      expect(find.text('#7'), findsWidgets);

      // Verify stepper buttons
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Tap on #5 pill
      await tester.tap(find.text('#5').last);
      await tester.pumpAndSettle();

      // Check Ayah indicator updated to Ayah 5
      expect(find.text('Ayah 5 of 7'), findsOneWidget);
    });
  });
}

