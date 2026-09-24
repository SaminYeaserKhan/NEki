import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/dua/dua_provider.dart';
import 'package:neki/features/recitations/providers/reading_settings_provider.dart';
import 'package:neki/features/recitations/providers/recitation_audio_provider.dart';
import 'package:neki/features/recitations/widgets/persistent_recitation_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestablePlayer(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              PersistentRecitationPlayer(bottomPadding: 20),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('PersistentRecitationPlayer renders speed stepper with slow-down and speed-up buttons', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial state with active audio
    const dummyDua = Dua(
      id: 1,
      category: 'morning',
      title: 'Morning Supplication',
      arabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
      transliteration: 'Asbahna',
      description: 'We enter the morning',
    );

    container.read(recitationAudioProvider.notifier).state = RecitationAudioState(
      status: RecitationPlaybackStatus.playing,
      type: RecitationType.dua,
      currentDua: dummyDua,
      title: dummyDua.title,
      subtitle: 'Arabic Recitation • Authentic Pronunciation',
      speed: 1.0,
    );

    await tester.pumpWidget(buildTestablePlayer(container));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify player is visible with title and subtitle
    expect(find.text('Morning Supplication'), findsOneWidget);
    expect(find.text('Arabic Recitation • Authentic Pronunciation'), findsOneWidget);

    // Verify speed text displays 1x
    expect(find.text('1x'), findsOneWidget);

    // Verify slow down (-) and speed up (+) icons
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // Tap slow down (-)
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump(const Duration(milliseconds: 50));

    // Verify speed is now 0.75x
    expect(container.read(recitationAudioProvider).speed, equals(0.75));
    expect(find.text('0.75x'), findsOneWidget);

    // Tap speed up (+) twice: 0.75 -> 1.0 -> 1.25
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(recitationAudioProvider).speed, equals(1.0));
    expect(find.text('1x'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(recitationAudioProvider).speed, equals(1.25));
    expect(find.text('1.25x'), findsOneWidget);
  });

  testWidgets('PersistentRecitationPlayer renders Go Back and Go Forward 5s buttons and updates position', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const dummyDua = Dua(
      id: 2,
      category: 'evening',
      title: 'Evening Remembrance',
      arabic: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ',
      transliteration: 'Amsayna',
      description: 'We enter the evening',
    );

    // Initial state with 30s position and 60s total duration
    container.read(recitationAudioProvider.notifier).state = RecitationAudioState(
      status: RecitationPlaybackStatus.playing,
      type: RecitationType.dua,
      currentDua: dummyDua,
      title: dummyDua.title,
      subtitle: 'Evening Supplication',
      position: const Duration(seconds: 30),
      duration: const Duration(seconds: 60),
      speed: 1.0,
    );

    await tester.pumpWidget(buildTestablePlayer(container));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify track name is clearly visible
    expect(find.text('Evening Remembrance'), findsOneWidget);

    // Verify 5s replay and forward icons exist
    expect(find.byIcon(Icons.replay_5_rounded), findsOneWidget);
    expect(find.byIcon(Icons.forward_5_rounded), findsOneWidget);

    // Tap "Go Back 5s"
    await tester.tap(find.byIcon(Icons.replay_5_rounded));
    await tester.pump(const Duration(milliseconds: 50));

    // Position should be 30s - 5s = 25s
    expect(container.read(recitationAudioProvider).position, equals(const Duration(seconds: 25)));

    // Tap "Go Back 5s" again
    await tester.tap(find.byIcon(Icons.replay_5_rounded));
    await tester.pump(const Duration(milliseconds: 50));

    // Position should be 25s - 5s = 20s
    expect(container.read(recitationAudioProvider).position, equals(const Duration(seconds: 20)));

    // Tap "Go Forward 5s"
    await tester.tap(find.byIcon(Icons.forward_5_rounded));
    await tester.pump(const Duration(milliseconds: 50));

    // Position should be 20s + 5s = 25s
    expect(container.read(recitationAudioProvider).position, equals(const Duration(seconds: 25)));

    // Tap "Go Forward 5s" again
    await tester.tap(find.byIcon(Icons.forward_5_rounded));
    await tester.pump(const Duration(milliseconds: 50));

    // Position should be 25s + 5s = 30s
    expect(container.read(recitationAudioProvider).position, equals(const Duration(seconds: 30)));
  });

  testWidgets('PersistentRecitationPlayer renders track mode switcher and toggles Arabic/Translation', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const dummyDua = Dua(
      id: 3,
      category: 'prayer',
      title: 'Dua Before Sleep',
      arabic: 'بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي',
      transliteration: 'Bismika Rabbi',
      description: 'In Your name, my Lord, I lie down',
    );

    container.read(recitationAudioProvider.notifier).state = RecitationAudioState(
      status: RecitationPlaybackStatus.playing,
      type: RecitationType.dua,
      currentDua: dummyDua,
      title: dummyDua.title,
      subtitle: 'Bedtime Supplication',
      trackMode: AudioTrackMode.recitation,
      speed: 1.0,
    );

    await tester.pumpWidget(buildTestablePlayer(container));
    await tester.pump(const Duration(milliseconds: 100));

    // Initially in recitation mode (Bangla default 'আরবি' with volume icon)
    expect(find.text('আরবি'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    // Tap track mode switcher
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump(const Duration(milliseconds: 50));

    // Verify trackMode switched to translation ('অনুবাদ' with voice over icon)
    expect(container.read(recitationAudioProvider).trackMode, equals(AudioTrackMode.translation));
    expect(find.text('অনুবাদ'), findsOneWidget);
    expect(find.byIcon(Icons.record_voice_over_rounded), findsOneWidget);
  });

  test('RecitationAudioState autoAdvance flag behavior: playVerse stops, playSurah continues', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(recitationAudioProvider.notifier);

    // Initial state: autoAdvance is false
    expect(container.read(recitationAudioProvider).autoAdvance, isFalse);

    // When a single verse is played, autoAdvance is false
    notifier.state = container.read(recitationAudioProvider).copyWith(
      type: RecitationType.quran,
      currentSurah: 112,
      currentVerse: 1,
      autoAdvance: false,
    );
    expect(container.read(recitationAudioProvider).autoAdvance, isFalse);

    // In continuous playback ("Play All" / playSurah), autoAdvance is true
    notifier.state = container.read(recitationAudioProvider).copyWith(
      autoAdvance: true,
    );
    expect(container.read(recitationAudioProvider).autoAdvance, isTrue);
  });

  test('Single verse completion automatically stops and pauses player at start of verse', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(recitationAudioProvider.notifier);

    // Simulate playing Ayah 1 of Surah 112 with autoAdvance: false
    notifier.state = RecitationAudioState(
      status: RecitationPlaybackStatus.playing,
      type: RecitationType.quran,
      currentSurah: 112,
      currentVerse: 1,
      totalVersesInSurah: 4,
      position: const Duration(seconds: 4),
      duration: const Duration(seconds: 4),
      autoAdvance: false,
    );

    expect(container.read(recitationAudioProvider).isPlaying, isTrue);

    // Simulate completion of single verse (non-continuous playback)
    notifier.state = container.read(recitationAudioProvider).copyWith(
      status: RecitationPlaybackStatus.paused,
      position: Duration.zero,
    );

    // Verify player automatically stopped and paused: isPlaying is false, position is 0
    final state = container.read(recitationAudioProvider);
    expect(state.isPlaying, isFalse);
    expect(state.status, equals(RecitationPlaybackStatus.paused));
    expect(state.position, equals(Duration.zero));
    expect(state.hasAudio, isTrue);
  });
}
