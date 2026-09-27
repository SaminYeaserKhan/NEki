import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/recitations/services/arabic_pronunciation_matcher.dart';
import 'package:neki/features/recitations/services/streaming_word_aligner.dart';
import 'package:neki/features/recitations/services/whisper_speech_service.dart';

void main() {
  group('WhisperSpeechService - Audio Synthesis & WAV Header Tests', () {
    test('buildWavBytes creates valid 44-byte RIFF WAVE header for 16kHz mono PCM', () {
      // 1 second of 16kHz 16-bit mono audio is 32000 bytes
      final dummyPcm = Uint8List(32000);
      final wav = WhisperSpeechService.buildWavBytes(dummyPcm, sampleRate: 16000, numChannels: 1);

      expect(wav.length, equals(44 + 32000));

      final bd = ByteData.sublistView(wav);

      // 'RIFF' tag
      expect(String.fromCharCode(bd.getUint8(0)), equals('R'));
      expect(String.fromCharCode(bd.getUint8(1)), equals('I'));
      expect(String.fromCharCode(bd.getUint8(2)), equals('F'));
      expect(String.fromCharCode(bd.getUint8(3)), equals('F'));

      // Total audio length (file size - 8) = 32000 + 36
      expect(bd.getUint32(4, Endian.little), equals(32036));

      // 'WAVE' tag
      expect(String.fromCharCode(bd.getUint8(8)), equals('W'));
      expect(String.fromCharCode(bd.getUint8(9)), equals('A'));
      expect(String.fromCharCode(bd.getUint8(10)), equals('V'));
      expect(String.fromCharCode(bd.getUint8(11)), equals('E'));

      // 'fmt ' chunk
      expect(String.fromCharCode(bd.getUint8(12)), equals('f'));
      expect(String.fromCharCode(bd.getUint8(13)), equals('m'));
      expect(String.fromCharCode(bd.getUint8(14)), equals('t'));
      expect(String.fromCharCode(bd.getUint8(15)), equals(' '));

      expect(bd.getUint32(16, Endian.little), equals(16)); // Chunk size 16 for PCM
      expect(bd.getUint16(20, Endian.little), equals(1)); // Audio format 1 (PCM)
      expect(bd.getUint16(22, Endian.little), equals(1)); // 1 channel (mono)
      expect(bd.getUint32(24, Endian.little), equals(16000)); // Sample rate 16000 Hz
      expect(bd.getUint32(28, Endian.little), equals(32000)); // Byte rate: 16000 * 1 * 2
      expect(bd.getUint16(32, Endian.little), equals(2)); // Block align: 2 bytes
      expect(bd.getUint16(34, Endian.little), equals(16)); // 16 bits per sample

      // 'data' chunk
      expect(String.fromCharCode(bd.getUint8(36)), equals('d'));
      expect(String.fromCharCode(bd.getUint8(37)), equals('a'));
      expect(String.fromCharCode(bd.getUint8(38)), equals('t'));
      expect(String.fromCharCode(bd.getUint8(39)), equals('a'));
      expect(bd.getUint32(40, Endian.little), equals(32000)); // PCM data length
    });
  });

  group('StreamingWordAligner - Fluid Non-Halting Mode Tests', () {
    test('fluid mode tracks forward through skipped words without halting recitation', () {
      final aligner = StreamingWordAligner.single(
        surahNumber: 1,
        verseNumber: 2,
        arabicText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
        enableLiveHalting: false, // Fluid follower
      );

      // Target norm: ['الحمد', 'لله', 'رب', 'العالمين']
      // User says: "الحمد"
      var update = aligner.processTranscript('الحمد');
      expect(update.event, equals(RealtimeAlignmentEvent.wordMatched));
      expect(aligner.activeWordIndex, equals(1));
      expect(aligner.isPausedOnMistake, isFalse);

      // User skips "لله" and directly recites "رب العالمين"
      update = aligner.processTranscript('الحمد رب العالمين');
      expect(aligner.isPausedOnMistake, isFalse);
      expect(aligner.activeMistake, isNull); // Not paused
      expect(aligner.snapshot.isAyahCompleted, isTrue);

      // Skipped word ("لله") was marked needsPractice
      expect(aligner.snapshot.wordStatuses[1], equals(WordPronunciationStatus.needsPractice));
      // "رب" and "العالمين" were matched
      expect(aligner.snapshot.wordStatuses[2], equals(WordPronunciationStatus.perfect));
      expect(aligner.snapshot.wordStatuses[3], equals(WordPronunciationStatus.perfect));
    });

    test('fluid mode tracks forward through mispronounced words without freezing', () {
      final aligner = StreamingWordAligner.single(
        surahNumber: 112,
        verseNumber: 1,
        arabicText: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
        enableLiveHalting: false, // Fluid follower
      );

      // Recites: "قل هو الرحمن احد" ("الرحمن" instead of "الله")
      aligner.processTranscript('قل هو');
      expect(aligner.activeWordIndex, equals(2));

      // Now "قل هو الرحمن احد"
      aligner.processTranscript('قل هو الرحمن احد');
      expect(aligner.isPausedOnMistake, isFalse);
      expect(aligner.snapshot.isAyahCompleted, isTrue);
      // Word 2 ("الله") marked needsPractice
      expect(aligner.snapshot.wordStatuses[2], equals(WordPronunciationStatus.needsPractice));
      // Word 3 ("أحد") matched
      expect(aligner.snapshot.wordStatuses[3], isNotNull);
    });

    test('full surah mode defaults to fluid non-halting mode', () {
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

      expect(aligner.enableLiveHalting, isFalse);
    });

    test('token count does not reset when transcript has no new tokens', () {
      final aligner = StreamingWordAligner.single(
        surahNumber: 1,
        verseNumber: 1,
        arabicText: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      );

      aligner.processTranscript('بسم الله');
      expect(aligner.activeWordIndex, equals(2));

      // Same transcript received again (no new tokens)
      final idleUpdate = aligner.processTranscript('بسم الله');
      expect(idleUpdate.event, equals(RealtimeAlignmentEvent.noChange));
      expect(aligner.activeWordIndex, equals(2)); // Did not reset or re-match!

      // New token arrives
      final nextUpdate = aligner.processTranscript('بسم الله الرحمن');
      expect(nextUpdate.event, equals(RealtimeAlignmentEvent.wordMatched));
      expect(aligner.activeWordIndex, equals(3));
    });
  });
}
