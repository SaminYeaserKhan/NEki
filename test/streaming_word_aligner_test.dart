import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/recitations/services/arabic_pronunciation_matcher.dart';
import 'package:neki/features/recitations/services/streaming_word_aligner.dart';

void main() {
  group('StreamingWordAligner - Single Ayah Mode Tests', () {
    test('incremental tokens correctly advance active word index to completion', () {
      final aligner = StreamingWordAligner.single(
        surahNumber: 1,
        verseNumber: 1,
        arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        transliteration: 'Bismillahir-Rahmanir-Rahim',
      );

      expect(aligner.activeWordIndex, equals(0));
      expect(aligner.isPausedOnMistake, isFalse);
      expect(aligner.currentAyah.normWords.length, equals(4));

      // 1. First word arrives: "بسم"
      var update = aligner.processTranscript('بسم');
      expect(update.event, equals(RealtimeAlignmentEvent.wordMatched));
      expect(aligner.activeWordIndex, equals(1));
      expect(aligner.snapshot.wordStatuses[0], equals(WordPronunciationStatus.perfect));

      // 2. Second word arrives: "بسم الله"
      update = aligner.processTranscript('بسم الله');
      expect(update.event, equals(RealtimeAlignmentEvent.wordMatched));
      expect(aligner.activeWordIndex, equals(2));
      expect(aligner.snapshot.wordStatuses[1], equals(WordPronunciationStatus.perfect));

      // 3. Third word arrives: "بسم الله الرحمن"
      update = aligner.processTranscript('بسم الله الرحمن');
      expect(update.event, equals(RealtimeAlignmentEvent.wordMatched));
      expect(aligner.activeWordIndex, equals(3));

      // 4. Fourth word arrives: "بسم الله الرحمن الرحيم"
      update = aligner.processTranscript('بسم الله الرحمن الرحيم');
      expect(update.event, equals(RealtimeAlignmentEvent.ayahCompleted));
      expect(update.isAyahFinished, isTrue);
      expect(aligner.snapshot.isAyahCompleted, isTrue);
      expect(aligner.snapshot.wordStatuses.every((s) => s != null), isTrue);
    });

    test('detects mistake in middle, pauses recitation, and provides Makhraj feedback', () {
      final aligner = StreamingWordAligner.single(
        surahNumber: 112,
        verseNumber: 1,
        arabicText: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
        transliteration: 'Qul Huwa Allahu Ahad',
      );

      // User says: "قل هو"
      aligner.processTranscript('قل');
      aligner.processTranscript('قل هو');
      expect(aligner.activeWordIndex, equals(2));

      // User makes a mistake on word 2 ("الله"): says "الرحمن" instead
      final update = aligner.processTranscript('قل هو الرحمن');

      expect(update.event, equals(RealtimeAlignmentEvent.mistakeDetected));
      expect(aligner.isPausedOnMistake, isTrue);
      expect(aligner.activeMistake, isNotNull);
      expect(aligner.activeWordIndex, equals(2)); // Did not advance past error!
      expect(aligner.snapshot.wordStatuses[2], equals(WordPronunciationStatus.needsPractice));
      expect(aligner.activeMistake?.arabicWord, equals('اللَّهُ'));

      // New unrelated words do not advance while paused on mistake
      final idleUpdate = aligner.processTranscript('قل هو الرحمن الرحيم');
      expect(idleUpdate.event, equals(RealtimeAlignmentEvent.noChange));
      expect(aligner.activeWordIndex, equals(2));

      // User retries the word correctly: "الله"
      final retryUpdate = aligner.processTranscript('قل هو الرحمن الله');
      expect(retryUpdate.event, equals(RealtimeAlignmentEvent.mistakeResolved));
      expect(aligner.isPausedOnMistake, isFalse);
      expect(aligner.activeMistake, isNull);
      expect(aligner.activeWordIndex, equals(3)); // Advanced!

      // Final word: "احد"
      final finishUpdate = aligner.processTranscript('قل هو الرحمن الله احد');
      expect(finishUpdate.event, equals(RealtimeAlignmentEvent.ayahCompleted));
      expect(finishUpdate.isAyahFinished, isTrue);
    });

    test('detects skipped word when user jumps ahead to subsequent word', () {
      final aligner = StreamingWordAligner.single(
        surahNumber: 1,
        verseNumber: 2,
        arabicText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
      );

      // Target norm: ['الحمد', 'لله', 'رب', 'العالمين']
      // User says: "الحمد"
      aligner.processTranscript('الحمد');
      expect(aligner.activeWordIndex, equals(1));

      // User skips "لله" and jumps directly to "رب"
      final update = aligner.processTranscript('الحمد رب');
      expect(update.event, equals(RealtimeAlignmentEvent.mistakeDetected));
      expect(aligner.isPausedOnMistake, isTrue);
      expect(aligner.activeWordIndex, equals(1));
      expect(aligner.activeMistake?.issueDescription, contains('skipped'));
    });

    test('allows user to manually skip current word and resume', () {
      final aligner = StreamingWordAligner.single(
        surahNumber: 1,
        verseNumber: 1,
        arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      );

      aligner.processTranscript('بسم');
      expect(aligner.activeWordIndex, equals(1));

      // User taps skip on word 1 ("الله")
      final update = aligner.skipActiveWord();
      expect(update.event, equals(RealtimeAlignmentEvent.wordSkipped));
      expect(aligner.activeWordIndex, equals(2));
      expect(aligner.snapshot.wordStatuses[1], equals(WordPronunciationStatus.needsPractice));
      expect(aligner.isPausedOnMistake, isFalse);

      // Can continue reciting rest of verse (skipping word 1 'الله')
      aligner.processTranscript('بسم الرحمن الرحيم');
      expect(aligner.snapshot.isAyahCompleted, isTrue);
    });
  });

  group('StreamingWordAligner - Full Surah Mode Tests', () {
    test('seamlessly completes Ayah 1 and transitions to Ayah 2 in multi-verse Surah', () {
      // Surah Al-Ikhlas (Ayah 1 & 2)
      final surahTargets = [
        AyahRecitationTarget(
          surahNumber: 112,
          verseNumber: 1,
          arabicText: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
        ),
        AyahRecitationTarget(
          surahNumber: 112,
          verseNumber: 2,
          arabicText: 'اللَّهُ الصَّمَدُ',
        ),
      ];

      final aligner = StreamingWordAligner.fullSurah(
        surahNumber: 112,
        surahAyahs: surahTargets,
      );

      expect(aligner.mode, equals(RecitationMode.fullSurah));
      expect(aligner.currentAyah.verseNumber, equals(1));
      expect(aligner.snapshot.totalAyahs, equals(2));
      expect(aligner.snapshot.completedAyahsCount, equals(0));

      // Recite Ayah 1 completely
      final finishAyah1 = aligner.processTranscript('قل هو الله احد');
      expect(finishAyah1.event, equals(RealtimeAlignmentEvent.ayahCompleted));
      expect(finishAyah1.isAyahFinished, isTrue);
      expect(finishAyah1.isSurahFinished, isFalse);

      // Advance to Ayah 2
      final advanced = aligner.advanceToNextAyah();
      expect(advanced, isTrue);
      expect(aligner.currentAyah.verseNumber, equals(2));
      expect(aligner.activeWordIndex, equals(0));
      expect(aligner.snapshot.completedAyahsCount, equals(1));

      // Recite Ayah 2: "الله الصمد"
      final finishAyah2 = aligner.processTranscript('الله الصمد');
      expect(finishAyah2.event, equals(RealtimeAlignmentEvent.surahCompleted));
      expect(finishAyah2.isSurahFinished, isTrue);
      expect(aligner.snapshot.isSurahCompleted, isTrue);
      expect(aligner.hasMoreAyahs, isFalse);
    });

    test('handles cumulative multi-verse continuous transcript without resetting tokens', () {
      final fatihaAyahs = [
        AyahRecitationTarget(
          surahNumber: 1,
          verseNumber: 1,
          arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        ),
        AyahRecitationTarget(
          surahNumber: 1,
          verseNumber: 2,
          arabicText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
        ),
      ];

      final aligner = StreamingWordAligner.fullSurah(
        surahNumber: 1,
        surahAyahs: fatihaAyahs,
      );

      // Cumulative speech stream from live speech recognition:
      // Ayah 1 finishes
      var u = aligner.processTranscript('بسم الله الرحمن الرحيم');
      expect(u.event, equals(RealtimeAlignmentEvent.ayahCompleted));

      // Advance to Ayah 2
      expect(aligner.advanceToNextAyah(), isTrue);
      expect(aligner.currentAyah.verseNumber, equals(2));

      // Cumulative stream continues: "بسم الله الرحمن الرحيم الحمد لله رب العالمين"
      u = aligner.processTranscript('بسم الله الرحمن الرحيم الحمد لله رب العالمين');
      expect(u.event, equals(RealtimeAlignmentEvent.surahCompleted));
      expect(aligner.activeWordIndex, equals(4)); // all 4 words matched
      expect(aligner.snapshot.wordStatuses.every((s) => s == WordPronunciationStatus.perfect), isTrue);
    });
  });
}
