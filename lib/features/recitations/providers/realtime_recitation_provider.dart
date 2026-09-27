import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran/quran.dart' as quran;

import '../../quran/quran_provider.dart';
import '../../quran/utils/quran_verse_helper.dart';
import '../services/pronunciation_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/streaming_word_aligner.dart';
import '../services/whisper_speech_service.dart';

enum RealtimeRecitationState {
  idle,
  recording,
  pausedOnMistake,
  analyzing,
  completed,
}

class RealtimeRecitationSession {
  final RealtimeRecitationState state;
  final RecitationMode mode;
  final int surahNumber;
  final int currentVerseNumber;
  final int currentAyahIndex;
  final int totalVerses;
  final List<AyahRecitationTarget> targets;
  final RealtimeRecitationSnapshot snapshot;
  final double soundLevel;
  final int elapsedSeconds;
  final String liveSpokenWords;
  final VocalizedWordFeedback? activeMistake;
  final PronunciationResult? result;
  final bool permissionDenied;
  final Map<int, List<VocalizedWordFeedback>> completedAyahsFeedback;

  const RealtimeRecitationSession({
    required this.state,
    required this.mode,
    required this.surahNumber,
    required this.currentVerseNumber,
    required this.currentAyahIndex,
    required this.totalVerses,
    required this.targets,
    required this.snapshot,
    this.soundLevel = 0.0,
    this.elapsedSeconds = 0,
    this.liveSpokenWords = '',
    this.activeMistake,
    this.result,
    this.permissionDenied = false,
    this.completedAyahsFeedback = const {},
  });

  RealtimeRecitationSession copyWith({
    RealtimeRecitationState? state,
    RecitationMode? mode,
    int? surahNumber,
    int? currentVerseNumber,
    int? currentAyahIndex,
    int? totalVerses,
    List<AyahRecitationTarget>? targets,
    RealtimeRecitationSnapshot? snapshot,
    double? soundLevel,
    int? elapsedSeconds,
    String? liveSpokenWords,
    VocalizedWordFeedback? activeMistake,
    bool clearActiveMistake = false,
    PronunciationResult? result,
    bool? permissionDenied,
    Map<int, List<VocalizedWordFeedback>>? completedAyahsFeedback,
  }) {
    return RealtimeRecitationSession(
      state: state ?? this.state,
      mode: mode ?? this.mode,
      surahNumber: surahNumber ?? this.surahNumber,
      currentVerseNumber: currentVerseNumber ?? this.currentVerseNumber,
      currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
      totalVerses: totalVerses ?? this.totalVerses,
      targets: targets ?? this.targets,
      snapshot: snapshot ?? this.snapshot,
      soundLevel: soundLevel ?? this.soundLevel,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      liveSpokenWords: liveSpokenWords ?? this.liveSpokenWords,
      activeMistake: clearActiveMistake ? null : (activeMistake ?? this.activeMistake),
      result: result ?? this.result,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      completedAyahsFeedback:
          completedAyahsFeedback ?? this.completedAyahsFeedback,
    );
  }
}

class RealtimeRecitationNotifier extends Notifier<RealtimeRecitationSession> {
  StreamingWordAligner? _aligner;
  Timer? _elapsedTimer;
  Timer? _silenceTimer;
  String? _recordedAudioPath;

  @override
  RealtimeRecitationSession build() {
    ref.onDispose(_cleanup);
    return const RealtimeRecitationSession(
      state: RealtimeRecitationState.idle,
      mode: RecitationMode.singleAyah,
      surahNumber: 1,
      currentVerseNumber: 1,
      currentAyahIndex: 0,
      totalVerses: 7,
      targets: [],
      snapshot: RealtimeRecitationSnapshot(
        mode: RecitationMode.singleAyah,
        surahNumber: 1,
        currentAyahNumber: 1,
        currentAyahIndex: 0,
        totalAyahs: 1,
        activeWordIndex: 0,
        totalWordsInActiveAyah: 0,
        completedAyahsCount: 0,
        wordStatuses: [],
        completedWordFeedbacks: [],
        isPausedOnMistake: false,
        isAyahCompleted: false,
        isSurahCompleted: false,
        totalMistakesCount: 0,
      ),
    );
  }

  /// Initializes the studio session with target scriptures.
  void initSession({
    required RecitationMode mode,
    required int surahNumber,
    int? verseNumber,
    String? arabicText,
    String? transliteration,
    String? translation,
  }) {
    _cleanup();

    final List<AyahRecitationTarget> targets = [];
    final vNum = verseNumber ?? 1;

    if (mode == RecitationMode.singleAyah) {
      final arabic = arabicText ??
          QuranVerseHelper.getCleanVerseText(surahNumber, vNum,
              verseEndSymbol: false);
      final trans = translation ??
          QuranVerseHelper.getVerseTranslation(
              surahNumber, vNum, ref.read(translationProvider));

      targets.add(AyahRecitationTarget(
        surahNumber: surahNumber,
        verseNumber: vNum,
        arabicText: arabic,
        transliteration: transliteration,
        translation: trans,
      ));

      _aligner = StreamingWordAligner.single(
        surahNumber: surahNumber,
        verseNumber: vNum,
        arabicText: arabic,
        transliteration: transliteration,
        translation: trans,
      );
    } else {
      // Full Surah Mode: load all Ayahs
      final total = quran.getVerseCount(surahNumber);
      for (int i = 1; i <= total; i++) {
        final a = QuranVerseHelper.getCleanVerseText(surahNumber, i,
            verseEndSymbol: false);
        final t = QuranVerseHelper.getVerseTranslation(
            surahNumber, i, ref.read(translationProvider));
        targets.add(AyahRecitationTarget(
          surahNumber: surahNumber,
          verseNumber: i,
          arabicText: a,
          translation: t,
        ));
      }

      _aligner = StreamingWordAligner.fullSurah(
        surahNumber: surahNumber,
        surahAyahs: targets,
      );
    }

    state = RealtimeRecitationSession(
      state: RealtimeRecitationState.idle,
      mode: mode,
      surahNumber: surahNumber,
      currentVerseNumber: vNum,
      currentAyahIndex: 0,
      totalVerses: targets.length,
      targets: targets,
      snapshot: _aligner!.snapshot,
    );
  }

  /// Toggles between Single Ayah and Full Surah modes.
  void switchMode(RecitationMode newMode) {
    if (state.mode == newMode) return;
    initSession(
      mode: newMode,
      surahNumber: state.surahNumber,
      verseNumber: state.currentVerseNumber,
    );
  }

  /// Begins real-time audio and speech monitoring.
  Future<void> startRecitation() async {
    if (_aligner == null) return;

    state = state.copyWith(
      state: RealtimeRecitationState.recording,
      permissionDenied: false,
      liveSpokenWords: '',
      soundLevel: 0.0,
      elapsedSeconds: 0,
      clearActiveMistake: true,
    );

    // 1. Start native speech recognition with real-time word streaming first
    final listenSuccess = await SpeechRecognitionService.instance.startListening(
      onResult: (words) => _handleLiveTranscript(words),
      onSoundLevel: (level) {
        if (state.state == RealtimeRecitationState.recording &&
            state.soundLevel == 0.0) {
          state = state.copyWith(soundLevel: level);
        }
      },
    );

    if (!listenSuccess) {
      state = state.copyWith(
        state: RealtimeRecitationState.idle,
        permissionDenied: true,
      );
      return;
    }

    // 2. Start audio file capture for Whisper only in Single Ayah mode
    if (state.mode == RecitationMode.singleAyah) {
      WhisperSpeechService.instance.startRecording(
        onSoundLevel: (level) {
          if (state.state == RealtimeRecitationState.recording) {
            state = state.copyWith(soundLevel: level);
          }
        },
      );
    }

    // Start timer
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  /// Processes live recognized words from the speech recognizer.
  void _handleLiveTranscript(String cumulativeWords) {
    if (_aligner == null) return;
    if (state.state != RealtimeRecitationState.recording &&
        state.state != RealtimeRecitationState.pausedOnMistake) {
      return;
    }

    state = state.copyWith(liveSpokenWords: cumulativeWords);

    final update = _aligner!.processTranscript(cumulativeWords);
    final snapshot = _aligner!.snapshot;

    switch (update.event) {
      case RealtimeAlignmentEvent.wordMatched:
        state = state.copyWith(
          snapshot: snapshot,
          clearActiveMistake: true,
        );
        break;

      case RealtimeAlignmentEvent.mistakeDetected:
        HapticFeedback.lightImpact();
        state = state.copyWith(
          state: RealtimeRecitationState.pausedOnMistake,
          snapshot: snapshot,
          activeMistake: update.mistakeFeedback,
        );
        break;

      case RealtimeAlignmentEvent.mistakeResolved:
        HapticFeedback.mediumImpact();
        state = state.copyWith(
          state: RealtimeRecitationState.recording,
          snapshot: snapshot,
          clearActiveMistake: true,
        );
        break;

      case RealtimeAlignmentEvent.ayahCompleted:
        state = state.copyWith(snapshot: snapshot);
        _handleAyahCompletedEvent(update);
        break;

      case RealtimeAlignmentEvent.surahCompleted:
        state = state.copyWith(snapshot: snapshot);
        _handleSurahCompletedEvent();
        break;

      case RealtimeAlignmentEvent.wordSkipped:
      case RealtimeAlignmentEvent.wordTentative:
      case RealtimeAlignmentEvent.noChange:
        state = state.copyWith(snapshot: snapshot);
        break;
    }
  }

  void _handleAyahCompletedEvent(AlignmentUpdate update) {
    if (state.mode == RecitationMode.singleAyah) {
      // Auto-stop countdown (1 second silence window)
      _silenceTimer?.cancel();
      _silenceTimer = Timer(const Duration(milliseconds: 900), () {
        stopAndEvaluate();
      });
    } else {
      // Full Surah Mode: record Ayah completion and advance
      final completedMap = Map<int, List<VocalizedWordFeedback>>.from(
        state.completedAyahsFeedback,
      );
      completedMap[_aligner!.currentAyah.verseNumber] =
          List.from(_aligner!.snapshot.completedWordFeedbacks);

      final nextIdx = state.currentAyahIndex + 1;
      final nextVerse = nextIdx < state.targets.length
          ? state.targets[nextIdx].verseNumber
          : state.currentVerseNumber;

      final advanced = _aligner!.advanceToNextAyah();
      if (advanced) {
        HapticFeedback.lightImpact();
        state = state.copyWith(
          currentAyahIndex: nextIdx,
          currentVerseNumber: nextVerse,
          snapshot: _aligner!.snapshot,
          completedAyahsFeedback: completedMap,
          clearActiveMistake: true,
        );
      }
    }
  }

  void _handleSurahCompletedEvent() {
    // Whole Surah completed! Auto-stop after brief pause
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 900), () {
      stopAndEvaluate();
    });
  }

  /// Skips the active erroneous word and resumes recitation.
  void skipMistakeWord() {
    if (_aligner == null) return;
    final update = _aligner!.skipActiveWord();
    final snapshot = _aligner!.snapshot;

    state = state.copyWith(
      state: RealtimeRecitationState.recording,
      snapshot: snapshot,
      clearActiveMistake: true,
    );

    if (update.isSurahFinished) {
      _handleSurahCompletedEvent();
    } else if (update.isAyahFinished && state.mode == RecitationMode.fullSurah) {
      _handleAyahCompletedEvent(update);
    } else if (update.isAyahFinished && state.mode == RecitationMode.singleAyah) {
      stopAndEvaluate();
    }
  }

  /// Stops listening, releases hardware, and generates the final scorecard.
  Future<void> stopAndEvaluate() async {
    _cleanupTimers();

    state = state.copyWith(state: RealtimeRecitationState.analyzing);

    _recordedAudioPath = state.mode == RecitationMode.singleAyah
        ? await WhisperSpeechService.instance.stopRecording()
        : null;
    final fallbackSpoken = await SpeechRecognitionService.instance.stopListening();

    final actualSpoken =
        fallbackSpoken.isNotEmpty ? fallbackSpoken : state.liveSpokenWords;
    final cleanAyahSpoken = state.snapshot.cleanSpokenAyahText;
    final spokenToEvaluate = cleanAyahSpoken.isNotEmpty ? cleanAyahSpoken : actualSpoken;

    PronunciationResult finalResult;

    if (state.mode == RecitationMode.singleAyah) {
      final target = state.targets.isNotEmpty
          ? state.targets.first
          : AyahRecitationTarget(
              surahNumber: state.surahNumber,
              verseNumber: state.currentVerseNumber,
              arabicText: '',
            );

      if (_recordedAudioPath != null) {
        finalResult = await PronunciationService.instance.evaluateAudioFile(
          audioPath: _recordedAudioPath!,
          targetArabic: target.arabicText,
          fallbackSpokenText: spokenToEvaluate,
          transliteration: target.transliteration,
          recordedDuration: Duration(seconds: state.elapsedSeconds),
        );
      } else {
        finalResult = PronunciationService.instance.evaluateRecitation(
          arabicText: target.arabicText,
          transliteration: target.transliteration,
          spokenArabic: spokenToEvaluate,
          recordedDuration: Duration(seconds: state.elapsedSeconds),
          isOffline: true,
        );
      }
    } else {
      // Full Surah scorecard aggregation
      final totalWords = _aligner?.snapshot.completedWordFeedbacks ?? [];
      final perfectCount = totalWords
          .where((w) => w.status == WordPronunciationStatus.perfect)
          .length;
      final goodCount = totalWords
          .where((w) => w.status == WordPronunciationStatus.good)
          .length;

      final score = totalWords.isNotEmpty
          ? (((perfectCount * 1.0) + (goodCount * 0.8)) / totalWords.length * 100)
              .round()
              .clamp(0, 100)
          : 0;

      final surahName = quran.getSurahName(state.surahNumber);
      final cleanWholeSurahSpoken = totalWords
          .map((w) => w.spokenWord ?? w.arabicWord)
          .where((w) => w.isNotEmpty)
          .join(' ');

      finalResult = PronunciationResult(
        overallScore: score,
        qualityTitle: score >= 90
            ? 'Mumtāz! (Complete Surah Mastered)'
            : score >= 80
                ? 'Jayyid Jiddan! (Well Recited)'
                : 'Jayyid (Good Muraja\'ah)',
        feedbackSummary:
            'Completed recitation of Surah $surahName (${state.targets.length} Ayahs). Total mistakes encountered: ${state.snapshot.totalMistakesCount}.',
        spokenText: cleanWholeSurahSpoken.isNotEmpty ? cleanWholeSurahSpoken : actualSpoken,
        expectedText: 'Surah $surahName',
        words: totalWords,
        detectedTajweedRules: const [],
        encouragement:
            'The Prophet ﷺ said: "The best of you are those who learn the Quran and teach it." (Bukhari)',
        isOfflineFallback: true,
      );
    }

    state = state.copyWith(
      state: RealtimeRecitationState.completed,
      result: finalResult,
    );
  }

  /// Cancels and resets session.
  void reset() {
    _cleanup();
    _aligner?.reset();
    state = state.copyWith(
      state: RealtimeRecitationState.idle,
      elapsedSeconds: 0,
      soundLevel: 0.0,
      liveSpokenWords: '',
      result: null,
      clearActiveMistake: true,
      snapshot: _aligner?.snapshot ?? state.snapshot,
    );
  }

  void _cleanupTimers() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void _cleanup() {
    _cleanupTimers();
    WhisperSpeechService.instance.cancel();
    SpeechRecognitionService.instance.cancel();
  }
}

final realtimeRecitationProvider = NotifierProvider.autoDispose<
    RealtimeRecitationNotifier, RealtimeRecitationSession>(
  RealtimeRecitationNotifier.new,
);
