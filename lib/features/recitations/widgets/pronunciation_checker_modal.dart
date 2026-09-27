import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:quran/quran.dart' as quran;

import '../../../core/config/api_keys.dart';
import '../../../core/theme/neki_colors.dart';
import '../../../core/utils/bengali_phonetic_helper.dart';
import '../../dua/dua_provider.dart';
import '../../hadith/hadith_provider.dart';
import '../../quran/quran_provider.dart';
import '../../quran/utils/quran_verse_helper.dart';
import '../../quran/services/quran_transliteration_service.dart';
import '../providers/recitation_audio_provider.dart';
import '../services/pronunciation_service.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../services/neural_tts_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/streaming_word_aligner.dart';
import '../services/whisper_speech_service.dart';
import 'audio_visualizer_widget.dart';

enum RecordingState { idle, recording, pausedOnMistake, analyzing, completed }

/// Interactive vocalization and pronunciation evaluation studio modal.
/// Powered by a Dual-Engine Architecture: Groq Whisper Large-v3 (Wispr Flow accuracy)
/// with Scripture Prompt Conditioning, and On-Device Native Speech Recognition fallback.
class PronunciationCheckerModal extends ConsumerStatefulWidget {
  final String title;
  final String arabicText;
  final String? transliteration;
  final String? translation;
  final int? surahNumber;
  final int? verseNumber;
  final Dua? dua;
  final HadithEntry? hadith;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const PronunciationCheckerModal({
    super.key,
    required this.title,
    required this.arabicText,
    this.transliteration,
    this.translation,
    this.surahNumber,
    this.verseNumber,
    this.dua,
    this.hadith,
    this.onNext,
    this.onPrevious,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String arabicText,
    String? transliteration,
    String? translation,
    int? surahNumber,
    int? verseNumber,
    Dua? dua,
    HadithEntry? hadith,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PronunciationCheckerModal(
        title: title,
        arabicText: arabicText,
        transliteration: transliteration,
        translation: translation,
        surahNumber: surahNumber,
        verseNumber: verseNumber,
        dua: dua,
        hadith: hadith,
        onNext: onNext,
        onPrevious: onPrevious,
      ),
    );
  }

  @override
  ConsumerState<PronunciationCheckerModal> createState() =>
      _PronunciationCheckerModalState();
}

class _PronunciationCheckerModalState
    extends ConsumerState<PronunciationCheckerModal>
    with SingleTickerProviderStateMixin {
  RecordingState _recordingState = RecordingState.idle;
  int _elapsedSeconds = 0;
  Timer? _timer;
  PronunciationResult? _result;
  late AnimationController _pulseController;

  int? _verseNumber;
  late String _title;
  late String _arabicText;
  String? _transliteration;
  String? _translation;

  // Real-time audio and speech capture state
  double _soundLevel = 0.0;
  String _liveSpokenWords = '';
  bool _permissionDenied = false;
  RecordingStartResult? _recordingStartResult;
  bool _isBangla = false;

  // Real-time interactive recitation state
  RecitationMode _recitationMode = RecitationMode.singleAyah;
  StreamingWordAligner? _aligner;
  RealtimeRecitationSnapshot? _alignerSnapshot;
  VocalizedWordFeedback? _activeMistake;
  Timer? _silenceTimer;
  List<AyahRecitationTarget> _surahTargets = [];
  int _currentSurahAyahIndex = 0;

  // Single word TTS evaluation player & state
  AudioPlayer? _wordTtsPlayer;
  String? _activeTtsKey;
  bool _isWordTtsLoading = false;

  @override
  void initState() {
    super.initState();
    _verseNumber = widget.verseNumber;
    _title = widget.title;
    _arabicText = widget.arabicText;
    _transliteration = widget.transliteration;
    _translation = widget.translation;

    _wordTtsPlayer = AudioPlayer();
    _wordTtsPlayer?.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _activeTtsKey = null;
            _isWordTtsLoading = false;
          });
        }
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 1. Pre-warm on-device speech recognition to eliminate initial capture delay
    SpeechRecognitionService.instance.initialize();

    // 2. Pre-fetch whole Surah transliterations asynchronously if viewing a Surah
    if (widget.surahNumber != null) {
      QuranTransliterationService.instance
          .getSurahTransliteration(widget.surahNumber!)
          .then((map) {
        if (mounted && (_transliteration == null || _transliteration!.isEmpty)) {
          final t = map[_verseNumber ?? 1];
          if (t != null && t.isNotEmpty) {
            setState(() {
              _transliteration = t;
              _initAligner();
            });
          }
        }
      });
    }

    _initAligner();
  }

  @override
  void dispose() {
    _cleanupTimers();
    _pulseController.dispose();
    _wordTtsPlayer?.stop();
    _wordTtsPlayer?.dispose();
    // Ensure microphone and audio resources are cleanly released
    WhisperSpeechService.instance.cancel();
    SpeechRecognitionService.instance.cancel();
    super.dispose();
  }

  void _cleanupTimers() {
    _timer?.cancel();
    _timer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void _initAligner() {
    if (_recitationMode == RecitationMode.singleAyah || widget.surahNumber == null) {
      final effectiveTrans = (_transliteration != null && _transliteration!.isNotEmpty)
          ? _transliteration
          : (widget.surahNumber != null
              ? QuranTransliterationService.instance.getVerseTransliteration(
                  widget.surahNumber!,
                  _verseNumber ?? 1,
                  arabicText: _arabicText,
                )
              : null);
      _transliteration = effectiveTrans;

      _aligner = StreamingWordAligner.single(
        surahNumber: widget.surahNumber ?? 1,
        verseNumber: _verseNumber ?? 1,
        arabicText: _arabicText,
        transliteration: effectiveTrans,
        translation: _translation,
        enableLiveHalting: true,
      );
    } else {
      final total = quran.getVerseCount(widget.surahNumber!);
      _surahTargets = [];
      for (int i = 1; i <= total; i++) {
        final cleanArabic = QuranVerseHelper.getCleanVerseText(
          widget.surahNumber!,
          i,
          verseEndSymbol: false,
        );
        final ayahTransliteration = QuranTransliterationService.instance
            .getVerseTransliteration(
          widget.surahNumber!,
          i,
          arabicText: cleanArabic,
        );
        _surahTargets.add(AyahRecitationTarget(
          surahNumber: widget.surahNumber!,
          verseNumber: i,
          arabicText: cleanArabic,
          transliteration: ayahTransliteration,
          translation: QuranVerseHelper.getVerseTranslation(
            widget.surahNumber!,
            i,
            ref.read(translationProvider),
          ),
        ));
      }
      _aligner = StreamingWordAligner.fullSurah(
        surahNumber: widget.surahNumber!,
        surahAyahs: _surahTargets,
      );
      _currentSurahAyahIndex = 0;
      if (_surahTargets.isNotEmpty) {
        _transliteration = _surahTargets.first.transliteration;
      }
    }
    _alignerSnapshot = _aligner!.snapshot;
    _activeMistake = null;
  }

  void _switchMode(RecitationMode newMode) {
    if (_recitationMode == newMode) return;
    setState(() {
      _recitationMode = newMode;
      _initAligner();
      _reset();
    });
  }

  void _handleLiveTranscript(String words) {
    if (_aligner == null) return;
    var update = _aligner!.processTranscript(words);

    while (update.event == RealtimeAlignmentEvent.ayahCompleted &&
        _recitationMode == RecitationMode.fullSurah &&
        _aligner!.hasMoreAyahs) {
      _advanceToNextSurahAyah();
      update = _aligner!.processTranscript(words);
    }

    setState(() {
      _liveSpokenWords = words;
      _alignerSnapshot = _aligner!.snapshot;

      if (update.event == RealtimeAlignmentEvent.mistakeDetected) {
        _recordingState = RecordingState.pausedOnMistake;
        _activeMistake = update.mistakeFeedback;
        HapticFeedback.lightImpact();
      } else if (update.event == RealtimeAlignmentEvent.mistakeResolved) {
        _recordingState = RecordingState.recording;
        _activeMistake = null;
        HapticFeedback.mediumImpact();
      } else if (update.event == RealtimeAlignmentEvent.ayahCompleted) {
        if (_recitationMode == RecitationMode.singleAyah) {
          // Auto-stop countdown on single Ayah completion
          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(milliseconds: 900), () {
            if (mounted && _recordingState == RecordingState.recording) {
              _stopAndEvaluate();
            }
          });
        } else {
          _advanceToNextSurahAyah();
        }
      } else if (update.event == RealtimeAlignmentEvent.surahCompleted) {
        // Auto-stop on whole Surah completion
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 900), () {
          if (mounted && _recordingState == RecordingState.recording) {
            _stopAndEvaluate();
          }
        });
      }
    });
  }

  void _advanceToNextSurahAyah() {
    if (_aligner == null || !_aligner!.hasMoreAyahs) return;

    final advanced = _aligner!.advanceToNextAyah();
    if (advanced) {
      _currentSurahAyahIndex++;
      final nextAyah = _aligner!.currentAyah;
      _verseNumber = nextAyah.verseNumber;
      _arabicText = nextAyah.arabicText;
      _translation = nextAyah.translation;
      _transliteration = nextAyah.transliteration;
      _alignerSnapshot = _aligner!.snapshot;
      HapticFeedback.lightImpact();
    }
  }

  void _skipActiveMistake() {
    if (_aligner == null) return;
    final update = _aligner!.skipActiveWord();
    setState(() {
      _alignerSnapshot = _aligner!.snapshot;
      _recordingState = RecordingState.recording;
      _activeMistake = null;
      if (update.isSurahFinished) {
        _stopAndEvaluate();
      } else if (update.isAyahFinished && _recitationMode == RecitationMode.fullSurah) {
        _advanceToNextSurahAyah();
      } else if (update.isAyahFinished && _recitationMode == RecitationMode.singleAyah) {
        _stopAndEvaluate();
      }
    });
  }

  @visibleForTesting
  void simulateRealtimeTranscript(String transcript) {
    if (_aligner == null) {
      _initAligner();
    }
    setState(() {
      _recordingState = RecordingState.recording;
    });
    _handleLiveTranscript(transcript);
  }

  @visibleForTesting
  void simulateRecitation({String? spokenOverride}) {
    setState(() {
      _recordingState = RecordingState.analyzing;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final result = PronunciationService.instance.evaluateRecitation(
        arabicText: _arabicText,
        transliteration: _transliteration,
        spokenArabic: spokenOverride ?? _arabicText,
        recordedDuration: const Duration(seconds: 4),
        isOffline: true,
      );
      setState(() {
        _result = result;
        _recordingState = RecordingState.completed;
      });
    });
  }

  Future<void> _startRecording() async {
    setState(() {
      _permissionDenied = false;
      _recordingStartResult = null;
      _liveSpokenWords = '';
      _soundLevel = 0.0;
      _activeMistake = null;
      _initAligner();
    });

    final hasGroq = ApiKeys.hasGroqKey();

    if (hasGroq) {
      // 1. Live Groq Whisper Micro-Streaming:
      // High-precision Quranic speech recognition without microphone contention
      final targetPrompt = _recitationMode == RecitationMode.fullSurah
          ? _surahTargets.map((t) => t.arabicText).join(' ')
          : _arabicText;

      final startResult = await WhisperSpeechService.instance.startLiveStreaming(
        prompt: targetPrompt,
        onTranscript: (liveTranscript) {
          if (mounted &&
              (_recordingState == RecordingState.recording ||
                  _recordingState == RecordingState.pausedOnMistake)) {
            _handleLiveTranscript(liveTranscript);
          }
        },
        onSoundLevel: (level) {
          if (mounted &&
              (_recordingState == RecordingState.recording ||
                  _recordingState == RecordingState.pausedOnMistake)) {
            setState(() => _soundLevel = level);
          }
        },
      );

      if (startResult == RecordingStartResult.permissionDenied) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
    } else {
      // 2. Fallback to on-device SpeechRecognitionService if offline / no Groq API key
      final listenSuccess = await SpeechRecognitionService.instance.startListening(
        onResult: (words) {
          if (mounted &&
              (_recordingState == RecordingState.recording ||
                  _recordingState == RecordingState.pausedOnMistake)) {
            _handleLiveTranscript(words);
          }
        },
        onSoundLevel: (level) {
          if (mounted && _recordingState == RecordingState.recording && _soundLevel == 0.0) {
            setState(() => _soundLevel = level);
          }
        },
      );

      if (!listenSuccess) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
          });
        }
        return;
      }

      // Also record audio in background for post-recitation scoring if possible
      WhisperSpeechService.instance.startRecording(
        onSoundLevel: (level) {
          if (mounted &&
              (_recordingState == RecordingState.recording ||
                  _recordingState == RecordingState.pausedOnMistake)) {
            setState(() => _soundLevel = level);
          }
        },
      );
    }

    setState(() {
      _recordingState = RecordingState.recording;
      _elapsedSeconds = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  Future<void> _stopAndEvaluate() async {
    _cleanupTimers();
    setState(() => _recordingState = RecordingState.analyzing);

    // Stop audio recording and native recognizer
    final audioPath = await WhisperSpeechService.instance.stopRecording();
    String fallbackText = '';
    if (!ApiKeys.hasGroqKey() || SpeechRecognitionService.instance.isListening) {
      fallbackText = await SpeechRecognitionService.instance.stopListening();
    }

    final actualSpoken = fallbackText.isNotEmpty ? fallbackText : _liveSpokenWords;
    final cleanAyahSpoken = _alignerSnapshot?.cleanSpokenAyahText;
    final spokenToEvaluate = (cleanAyahSpoken != null && cleanAyahSpoken.trim().isNotEmpty)
        ? cleanAyahSpoken
        : actualSpoken;

    PronunciationResult result;
    if (_recitationMode == RecitationMode.fullSurah && widget.surahNumber != null) {
      final surahName = quran.getSurahName(widget.surahNumber!);
      final isBengali = _isBangla;

      // 1. Attempt Groq Whisper Large-v3 evaluation of the entire Surah audio
      String? whisperFullSurahSpoken;
      if (audioPath != null) {
        final fullSurahPrompt = _surahTargets.map((t) => t.arabicText).join(' ');
        whisperFullSurahSpoken = await WhisperSpeechService.instance.transcribeWithWhisper(
          audioPath: audioPath,
          targetArabicPrompt: fullSurahPrompt,
        );
      }

      if (whisperFullSurahSpoken != null && whisperFullSurahSpoken.trim().isNotEmpty) {
        final fullSurahArabic = _surahTargets.map((t) => t.arabicText).join(' ');
        final fullSurahTrans = _surahTargets
            .map((t) => t.transliteration ?? '')
            .where((t) => t.isNotEmpty)
            .join(' ');

        final evaluated = ArabicPronunciationMatcher.instance.evaluate(
          targetArabic: fullSurahArabic,
          spokenArabic: whisperFullSurahSpoken,
          transliteration: fullSurahTrans,
          recordedDuration: Duration(seconds: _elapsedSeconds),
          isOffline: false,
        );

        result = PronunciationResult(
          overallScore: evaluated.overallScore,
          qualityTitle: evaluated.qualityTitle,
          feedbackSummary: isBengali
              ? 'সূরা $surahName (${_surahTargets.length} আয়াত) গ্রোক হুইস্পার লার্জ-ভি৩ দ্বারা যাচাইকৃত।'
              : 'Surah $surahName (${_surahTargets.length} Ayahs) verified with Groq Whisper Large-v3.',
          spokenText: evaluated.spokenText,
          expectedText: isBengali ? 'সূরা $surahName' : 'Surah $surahName',
          words: evaluated.words,
          detectedTajweedRules: evaluated.detectedTajweedRules,
          encouragement: evaluated.encouragement,
          encouragementBn: evaluated.encouragementBn,
          isOfflineFallback: false,
        );
      } else {
        // Fallback to real-time word aligner feedbacks
        final allWords = <VocalizedWordFeedback>[];
        final alignerFeedbacks = _aligner?.snapshot.completedWordFeedbacks ?? const [];
        int feedbackIdx = 0;

        for (final ayahTarget in _surahTargets) {
          for (int wIdx = 0; wIdx < ayahTarget.displayWords.length; wIdx++) {
            final displayWord = ayahTarget.displayWords[wIdx];
            final transWord = wIdx < ayahTarget.transliterationWords.length
                ? ayahTarget.transliterationWords[wIdx]
                : '';

            if (feedbackIdx < alignerFeedbacks.length) {
              allWords.add(alignerFeedbacks[feedbackIdx]);
              feedbackIdx++;
            } else {
              allWords.add(VocalizedWordFeedback(
                arabicWord: displayWord,
                spokenWord: null,
                transliteration: transWord,
                score: 0.20,
                status: WordPronunciationStatus.needsPractice,
                issueDescription: 'This word was not recited.',
                issueDescriptionBn: 'এই শব্দটি তেলাওয়াত করা হয়নি।',
                correctionAction: 'Recite all verses of the Surah sequentially.',
                correctionActionBn: 'সুরার সকল আয়াত ধারাবাহিকভাবে তেলাওয়াত করুন।',
              ));
            }
          }
        }

        final perfectCount = allWords.where((w) => w.status == WordPronunciationStatus.perfect).length;
        final goodCount = allWords.where((w) => w.status == WordPronunciationStatus.good).length;
        final score = allWords.isNotEmpty
            ? (((perfectCount * 1.0) + (goodCount * 0.8)) / allWords.length * 100).round().clamp(0, 100)
            : 0;

        final mistakes = _aligner?.snapshot.totalMistakesCount ?? 0;

        final cleanWholeSurahSpoken = ArabicPronunciationMatcher.deduplicateSpokenText(
          allWords
              .map((w) => w.spokenWord ?? '')
              .where((w) => w.isNotEmpty)
              .join(' '),
        );
        final finalSpoken = cleanWholeSurahSpoken.isNotEmpty
            ? cleanWholeSurahSpoken
            : ArabicPronunciationMatcher.deduplicateSpokenText(actualSpoken);

        result = PronunciationResult(
          overallScore: score,
          qualityTitle: score >= 90
              ? (isBengali ? 'মুমতাজ! (অসাধারণ তিলাওয়াত)' : 'Mumtaz! (Complete Surah Mastered)')
              : score >= 80
                  ? (isBengali ? 'জাইয়্যিদ জিদ্দান! (চমৎকার তিলাওয়াত)' : 'Jayyid Jiddan! (Well Recited)')
                  : (isBengali ? 'জাইয়্যিদ (উন্নতি সম্ভব)' : 'Jayyid (Good Muraja\'ah)'),
          feedbackSummary: isBengali
              ? 'সূরা $surahName (${_surahTargets.length} আয়াত) তিলাওয়াত সম্পন্ন হয়েছে। মোট ভুল শনাক্ত হয়েছে: $mistakes টি।'
              : 'Completed recitation of Surah $surahName (${_surahTargets.length} Ayahs). Total mistakes encountered: $mistakes.',
          spokenText: finalSpoken,
          expectedText: isBengali ? 'সূরা $surahName' : 'Surah $surahName',
          words: allWords,
          detectedTajweedRules: const [],
          encouragement: 'The Prophet (pbuh) said: "The best of you are those who learn the Quran and teach it." (Bukhari)',
          encouragementBn: 'রাসূলুল্লাহ (সা.) বলেছেন: "তোমাদের মধ্যে সর্বোত্তম সেই ব্যক্তি, যে নিজে কুরআন শিখে এবং অন্যকে শিক্ষা দেয়।" (সহীহ বুখারী)',
          isOfflineFallback: true,
        );
      }
    } else if (audioPath != null) {
      result = await PronunciationService.instance.evaluateAudioFile(
        audioPath: audioPath,
        targetArabic: _arabicText,
        fallbackSpokenText: spokenToEvaluate,
        transliteration: _transliteration,
        recordedDuration: Duration(seconds: _elapsedSeconds),
      );
    } else {
      result = PronunciationService.instance.evaluateRecitation(
        arabicText: _arabicText,
        transliteration: _transliteration,
        spokenArabic: spokenToEvaluate,
        recordedDuration: Duration(seconds: _elapsedSeconds),
        isOffline: true,
      );
    }

    if (mounted) {
      setState(() {
        _result = result;
        _recordingState = RecordingState.completed;
      });
    }
  }

  void _reset() {
    _cleanupTimers();
    WhisperSpeechService.instance.cancel();
    SpeechRecognitionService.instance.cancel();
    _aligner?.reset();
    setState(() {
      _recordingState = RecordingState.idle;
      _elapsedSeconds = 0;
      _soundLevel = 0.0;
      _liveSpokenWords = '';
      _result = null;
      _activeMistake = null;
      _alignerSnapshot = _aligner?.snapshot;
    });
  }

  bool get _hasPrev {
    if (widget.surahNumber != null && _verseNumber != null) {
      return _verseNumber! > 1;
    }
    return widget.onPrevious != null;
  }

  bool get _hasNext {
    if (widget.surahNumber != null && _verseNumber != null) {
      return _verseNumber! < quran.getVerseCount(widget.surahNumber!);
    }
    return widget.onNext != null;
  }

  void _prevAyah() {
    if (widget.surahNumber != null && _verseNumber != null && _verseNumber! > 1) {
      _updateAyah(_verseNumber! - 1);
    } else if (widget.onPrevious != null) {
      widget.onPrevious!();
    }
  }

  void _nextAyah() {
    if (widget.surahNumber != null && _verseNumber != null) {
      final total = quran.getVerseCount(widget.surahNumber!);
      if (_verseNumber! < total) {
        _updateAyah(_verseNumber! + 1);
      }
    } else if (widget.onNext != null) {
      widget.onNext!();
    }
  }

  Future<void> _updateAyah(int newNum) async {
    final translationLang = ref.read(translationProvider);
    final nextArabic = QuranVerseHelper.getCleanVerseText(widget.surahNumber!, newNum, verseEndSymbol: false);
    final isBengali = translationLang == TranslationLang.bengali;
    final nextTitle = isBengali
        ? '${quran.getSurahName(widget.surahNumber!)}: আয়াত $newNum'
        : '${quran.getSurahName(widget.surahNumber!)}: Ayah $newNum';
    final nextTrans = QuranVerseHelper.getVerseTranslation(widget.surahNumber!, newNum, translationLang);
    final nextPhonetic = QuranTransliterationService.instance.getVerseTransliteration(
      widget.surahNumber!,
      newNum,
      arabicText: nextArabic,
    );

    setState(() {
      _verseNumber = newNum;
      _arabicText = nextArabic;
      _title = nextTitle;
      _transliteration = nextPhonetic;
      _translation = nextTrans;
      _recordingState = RecordingState.idle;
      _elapsedSeconds = 0;
      _result = null;
    });

    _fetchTransliterationForAyah(widget.surahNumber!, newNum);
  }

  Future<void> _fetchTransliterationForAyah(int surah, int ayah) async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.alquran.cloud/v1/ayah/$surah:$ayah/en.transliteration',
      )).timeout(const Duration(milliseconds: 2000));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['data']?['text'] as String?;
        if (mounted && text != null && text.isNotEmpty && _verseNumber == ayah) {
          setState(() => _transliteration = text.trim());
        }
      }
    } catch (_) {}
  }

  void _playAuthenticAudio() {
    final audioNotifier = ref.read(recitationAudioProvider.notifier);
    final audioState = ref.read(recitationAudioProvider);

    if (audioState.isPlaying) {
      audioNotifier.pause();
      return;
    }

    // If currently reciting or paused on a mistake, pause microphone listening
    // so reference recitation plays cleanly without speech recognizer interference
    if (_recordingState == RecordingState.recording ||
        _recordingState == RecordingState.pausedOnMistake) {
      SpeechRecognitionService.instance.stopListening();
      _silenceTimer?.cancel();
    }

    if (widget.dua != null) {
      audioNotifier.playDua(widget.dua!);
    } else if (widget.hadith != null) {
      audioNotifier.playHadith(widget.hadith!);
    } else if (widget.surahNumber != null && _verseNumber != null) {
      audioNotifier.playVerse(widget.surahNumber!, _verseNumber!, autoAdvance: false);
    } else {
      audioNotifier.playArabicPronunciation(
        title: _title,
        subtitle: 'Authentic Vocalization',
        arabicText: _arabicText,
        surahNumber: widget.surahNumber,
        verseNumber: _verseNumber,
      );
    }
  }

  /// Resolves the authentic phonetic pronunciation for any Arabic word
  /// in English or Bengali, tailored to the active language mode.
  String _getPronunciationForWord(
    String? arabicWord,
    bool isBengali, {
    String? fallbackTransliteration,
  }) {
    if (arabicWord == null || arabicWord.trim().isEmpty) return '';

    if (fallbackTransliteration != null && fallbackTransliteration.trim().isNotEmpty) {
      if (isBengali) {
        final bn = BengaliPhoneticHelper.toBengaliPronunciation(fallbackTransliteration);
        if (bn.isNotEmpty) return bn;
      }
      return fallbackTransliteration;
    }

    final en = QuranTransliterationService.transliterateArabic(arabicWord);
    if (isBengali) {
      final bn = BengaliPhoneticHelper.toBengaliPronunciation(en);
      return bn.isNotEmpty ? bn : en;
    }
    return en;
  }

  /// Synthesizes and articulates the given Arabic word via Neural/TTS.
  Future<void> _playWordTts({
    required String text,
    required String buttonKey,
  }) async {
    final cleanText = text.replaceAll(RegExp(r'[0-9\(\)]'), '').trim();
    if (cleanText.isEmpty) return;

    if (_activeTtsKey == buttonKey) {
      await _wordTtsPlayer?.stop();
      if (mounted) {
        setState(() {
          _activeTtsKey = null;
          _isWordTtsLoading = false;
        });
      }
      return;
    }

    await _wordTtsPlayer?.stop();

    // Pause global recitation audio if playing
    final audioNotifier = ref.read(recitationAudioProvider.notifier);
    final audioState = ref.read(recitationAudioProvider);
    if (audioState.isPlaying) {
      audioNotifier.pause();
    }

    // Temporarily pause speech recognition while word TTS is playing
    if (_recordingState == RecordingState.recording ||
        _recordingState == RecordingState.pausedOnMistake) {
      SpeechRecognitionService.instance.stopListening();
      _silenceTimer?.cancel();
    }

    if (mounted) {
      setState(() {
        _activeTtsKey = buttonKey;
        _isWordTtsLoading = true;
      });
    }

    try {
      String? audioPath;
      try {
        audioPath = await NeuralTtsService.instance.getOrSynthesizeAudio(
          text: cleanText,
          langCode: 'ar',
          gender: TtsVoiceGender.male,
        );
      } catch (_) {
        audioPath = null;
      }

      if (!mounted) return;

      if (audioPath != null && audioPath.isNotEmpty) {
        await _wordTtsPlayer?.setFilePath(audioPath);
      } else {
        final encoded = Uri.encodeComponent(cleanText);
        final fallbackUrl =
            'https://translate.google.com/translate_tts?ie=UTF-8&q=$encoded&tl=ar&client=tw-ob';
        await _wordTtsPlayer?.setUrl(fallbackUrl);
      }

      if (mounted) {
        setState(() {
          _isWordTtsLoading = false;
        });
      }

      await _wordTtsPlayer?.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeTtsKey = null;
          _isWordTtsLoading = false;
        });
      }
    }
  }

  /// Compact interactive pill button to vocalize a word via TTS.
  Widget _buildWordTtsPillButton({
    required String textToSpeak,
    required String buttonKey,
    required bool isBengali,
    required Color accentColor,
  }) {
    final isPlaying = _activeTtsKey == buttonKey && !_isWordTtsLoading;
    final isLoading = _activeTtsKey == buttonKey && _isWordTtsLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _playWordTts(text: textToSpeak, buttonKey: buttonKey),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isPlaying ? 0.3 : 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: isPlaying ? 0.9 : 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                )
              else
                Icon(
                  isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                  size: 13,
                  color: accentColor,
                ),
              const SizedBox(width: 4),
              Text(
                isPlaying
                    ? (isBengali ? 'থামুন' : 'Stop')
                    : (isBengali ? 'উচ্চারণ' : 'Listen'),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _computeDisplayTitle() {
    if (!_isBangla) {
      return _title;
    }
    if (widget.surahNumber != null && _verseNumber != null) {
      return '${quran.getSurahName(widget.surahNumber!)}: আয়াত $_verseNumber';
    }
    if (widget.dua != null) {
      return widget.dua!.title;
    }
    if (widget.hadith != null) {
      return 'হাদিস নং ${widget.hadith!.number}';
    }
    return _title;
  }

  String? _computeDisplayTranslation() {
    if (_isBangla) {
      if (widget.surahNumber != null && _verseNumber != null) {
        return QuranVerseHelper.getVerseTranslation(widget.surahNumber!, _verseNumber!, TranslationLang.bengali);
      }
      if (widget.dua != null) {
        return widget.dua!.bengali ?? widget.dua!.description;
      }
      if (widget.hadith != null) {
        return widget.hadith!.bengali ?? widget.hadith!.text;
      }
      return _translation;
    } else {
      if (widget.surahNumber != null && _verseNumber != null) {
        return QuranVerseHelper.getVerseTranslation(widget.surahNumber!, _verseNumber!, TranslationLang.english);
      }
      if (widget.dua != null) {
        return widget.dua!.description;
      }
      if (widget.hadith != null) {
        return widget.hadith!.english ?? widget.hadith!.text;
      }
      return _translation;
    }
  }

  String? _computeDisplayTransliteration() {
    if (_isBangla) {
      if (widget.dua != null) {
        return widget.dua!.transliterationBn ??
            (widget.dua!.transliteration.isNotEmpty
                ? BengaliPhoneticHelper.toBengaliPronunciation(widget.dua!.transliteration)
                : null);
      }
      if (widget.hadith != null) {
        return widget.hadith!.transliterationBn ??
            (widget.hadith!.transliteration != null
                ? BengaliPhoneticHelper.toBengaliPronunciation(widget.hadith!.transliteration!)
                : null);
      }
      if (widget.surahNumber != null && _verseNumber != null) {
        return QuranTransliterationService.instance.getBengaliPronunciation(
          widget.surahNumber!,
          _verseNumber!,
          transliteration: _transliteration,
          arabicText: _arabicText,
        );
      }
      if (_transliteration != null && _transliteration!.isNotEmpty) {
        return BengaliPhoneticHelper.toBengaliPronunciation(_transliteration!);
      }
      return null;
    } else {
      if (widget.dua != null) {
        return widget.dua!.transliteration;
      }
      if (widget.hadith != null) {
        return widget.hadith!.transliteration;
      }
      if (widget.surahNumber != null && _verseNumber != null) {
        final t = (_transliteration != null && _transliteration!.isNotEmpty)
            ? _transliteration!
            : QuranTransliterationService.instance.getVerseTransliteration(
                widget.surahNumber!,
                _verseNumber!,
                arabicText: _arabicText,
              );
        return t.isNotEmpty ? t : null;
      }
      return _transliteration;
    }
  }

  Future<void> _showEngineSettingsDialog() async {
    final currentKey = await ApiKeys.getGroqApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);
    bool strictAcousticMode = !(await ApiKeys.isPromptBiasEnabled());

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF142B20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: NekiColors.emeraldLight, width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: NekiColors.goldLight, size: 22),
              SizedBox(width: 8),
              Text(
                'AI Speech Engine',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Neki uses Groq Whisper Large-v3 for Wispr Flow-grade accuracy with zero cost (Free Tier, 2,000 recitations/day).',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Groq Free API Key',
                    labelStyle: const TextStyle(color: NekiColors.emeraldLight),
                    hintText: 'gsk_...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: NekiColors.emeraldLight),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Strict Acoustic Mode',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              strictAcousticMode
                                  ? 'Active: Disables auto-correction to catch subtle Makhraj errors (e.g. Qaf vs Kaf).'
                                  : 'Off: Biases Whisper toward scripture words, auto-correcting slight mispronunciations.',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: strictAcousticMode,
                        activeThumbColor: NekiColors.emeraldLight,
                        onChanged: (val) {
                          setDialogState(() {
                            strictAcousticMode = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Get a free API key at console.groq.com. If left blank, Neki seamlessly uses on-device speech recognition.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ApiKeys.setGroqApiKey('');
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Clear Key', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () async {
                await ApiKeys.setGroqApiKey(controller.text);
                await ApiKeys.setPromptBiasEnabled(!strictAcousticMode);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: NekiColors.emeraldPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save & Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBengali = _isBangla;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2018).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: NekiColors.emeraldLight.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_external_on_rounded,
                      color: NekiColors.emeraldLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBengali ? 'উচ্চারণ ও তাজবীদ স্টুডিও' : 'Pronunciation & Tajweed Studio',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          _computeDisplayTitle(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // AI Engine Settings Button
                  IconButton(
                    icon: const Icon(Icons.settings_voice_rounded, color: NekiColors.goldLight, size: 20),
                    tooltip: 'AI Engine Settings',
                    onPressed: _showEngineSettingsDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Pinned Sticky Action Bar (Directly below header - Zero scrolling required)
            _buildPinnedTopActionBar(context, isBengali),

            const Divider(color: Colors.white10, height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arabic Scripture Display Card with live word highlights
                    _buildScriptureCard(isBengali),

                    const SizedBox(height: 18),

                    // Dynamic Studio Section
                    if (_recordingState == RecordingState.idle)
                      _buildIdleSection(isBengali),
                    if (_recordingState == RecordingState.recording)
                      _buildRecordingSection(isBengali),
                    if (_recordingState == RecordingState.pausedOnMistake)
                      _buildPausedOnMistakeSection(isBengali),
                    if (_recordingState == RecordingState.analyzing)
                      _buildAnalyzingSection(isBengali),
                    if (_recordingState == RecordingState.completed && _result != null)
                      _buildResultsSection(_result!, isBengali),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedTopActionBar(BuildContext context, bool isBengali) {
    final audioState = ref.watch(recitationAudioProvider);
    final isAudioPlaying = audioState.isPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1B14),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Ayah Navigation Controls + Language Toggle
          Row(
            children: [
              // Prev Ayah Button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: _hasPrev ? NekiColors.emeraldLight : Colors.white24,
                tooltip: isBengali ? 'পূর্ববর্তী আয়াত' : 'Previous Ayah',
                onPressed: _hasPrev ? _prevAyah : null,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),

              // Title / Ayah Counter Badge
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      widget.surahNumber != null && _verseNumber != null
                          ? (_recitationMode == RecitationMode.fullSurah &&
                                  _recordingState == RecordingState.completed
                              ? (_isBangla ? 'সম্পূর্ণ সূরা' : 'Complete Surah')
                              : (_isBangla
                                  ? 'আয়াত $_verseNumber / ${quran.getVerseCount(widget.surahNumber!)}'
                                  : 'Ayah $_verseNumber of ${quran.getVerseCount(widget.surahNumber!)}'))
                          : (_isBangla ? 'উচ্চারণ অনুশীলন' : 'Recitation Practice'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Next Ayah Button
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: _hasNext ? NekiColors.emeraldLight : Colors.white24,
                tooltip: isBengali ? 'পরবর্তী আয়াত' : 'Next Ayah',
                onPressed: _hasNext ? _nextAyah : null,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),

              const SizedBox(width: 10),

              // Language Switcher [বাং / EN] Button
              InkWell(
                onTap: () {
                  setState(() {
                    _isBangla = !_isBangla;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isBangla
                        ? NekiColors.gold.withValues(alpha: 0.22)
                        : NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isBangla ? NekiColors.goldLight : NekiColors.emeraldLight,
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 13,
                        color: _isBangla ? NekiColors.goldLight : NekiColors.emeraldLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isBangla ? 'বাং' : 'EN',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _isBangla ? NekiColors.goldLight : NekiColors.emeraldLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Mode Selector Capsule (Single Ayah vs Whole Surah)
          if (widget.surahNumber != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModePill(
                    title: isBengali ? 'একক আয়াত' : 'Single Ayah',
                    icon: Icons.article_rounded,
                    isSelected: _recitationMode == RecitationMode.singleAyah,
                    onTap: _recordingState == RecordingState.idle
                        ? () => _switchMode(RecitationMode.singleAyah)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  _buildModePill(
                    title: isBengali ? 'পুরো সূরা' : 'Whole Surah',
                    icon: Icons.auto_stories_rounded,
                    isSelected: _recitationMode == RecitationMode.fullSurah,
                    onTap: _recordingState == RecordingState.idle
                        ? () => _switchMode(RecitationMode.fullSurah)
                        : null,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Row 2: Instant Action Bar (Try Again, Master Reciter, Next Ayah, or Recording controls)
          if (_recordingState == RecordingState.completed) ...[
            Row(
              children: [
                // Try Again (Primary Button)
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _reset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NekiColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(
                      isBengali ? 'পুনরায় চেষ্টা' : 'Try Again',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Listen Again Audio Button
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: _playAuthenticAudio,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                      side: BorderSide(
                        color: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                      ),
                      backgroundColor: isAudioPlaying
                          ? NekiColors.gold.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isAudioPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                      size: 17,
                    ),
                    label: Text(
                      isAudioPlaying
                          ? (isBengali ? 'বিরতি' : 'Pause')
                          : (isBengali ? 'আবার শুনুন' : 'Listen Again'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                if (_hasNext) ...[
                  const SizedBox(width: 8),
                  // Next Ayah Button
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _nextAyah,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(
                        isBengali ? 'পরের আয়াত' : 'Next Ayah',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (_recordingState == RecordingState.recording) ...[
            Row(
              children: [
                // Pulse recording indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${isBengali ? 'রেকর্ডিং' : 'Recording'}: ${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Listen Button while recording (pauses mic to hear authentic recitation)
                OutlinedButton.icon(
                  onPressed: _playAuthenticAudio,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                    side: BorderSide(
                      color: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                    ),
                    backgroundColor: isAudioPlaying
                        ? NekiColors.gold.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(isAudioPlaying ? Icons.pause_rounded : Icons.volume_up_rounded, size: 15),
                  label: Text(
                    isAudioPlaying
                        ? (isBengali ? 'বিরতি' : 'Pause')
                        : (isBengali ? 'শুনুন' : 'Listen'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _stopAndEvaluate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: Text(
                    isBengali ? 'সমাপ্ত' : 'Finish',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ] else if (_recordingState == RecordingState.pausedOnMistake) ...[
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBengali ? 'ভুল: পুনরায় বলুন' : 'Mistake: Say Word',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Listen Again button during mistake pause
                OutlinedButton.icon(
                  onPressed: _playAuthenticAudio,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                    side: BorderSide(
                      color: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                    ),
                    backgroundColor: isAudioPlaying
                        ? NekiColors.gold.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(isAudioPlaying ? Icons.pause_rounded : Icons.volume_up_rounded, size: 14),
                  label: Text(
                    isAudioPlaying
                        ? (isBengali ? 'বিরতি' : 'Pause')
                        : (isBengali ? 'আবার শুনুন' : 'Listen Again'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: _skipActiveMistake,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 16, color: Colors.white70),
                  label: Text(
                    isBengali ? 'এড়িয়ে যান' : 'Skip Word',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ] else if (_recordingState == RecordingState.analyzing) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: NekiColors.emeraldLight),
                ),
                const SizedBox(width: 10),
                Text(
                  isBengali ? 'AI দ্বারা মূল্যায়ন করা হচ্ছে...' : 'AI Evaluating Pronunciation...',
                  style: const TextStyle(fontSize: 12.5, color: NekiColors.emeraldLight, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ] else ...[
            // Idle state: Quick top actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NekiColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.record_voice_over_rounded, size: 16),
                    label: Text(
                      isBengali ? 'তেলাওয়াত শুরু করুন' : 'Start Reciting',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _playAuthenticAudio,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                      side: BorderSide(
                        color: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(isAudioPlaying ? Icons.pause_rounded : Icons.volume_up_rounded, size: 16),
                    label: Text(
                      isAudioPlaying
                          ? (isBengali ? 'বিরতি' : 'Pause')
                          : (isBengali ? 'শুনুন' : 'Listen'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScriptureCard(bool isBengali) {
    final displayTrans = _computeDisplayTranslation();
    final displayPhonetic = _computeDisplayTransliteration();
    final isFullSurahFinished = _recitationMode == RecitationMode.fullSurah &&
        _recordingState == RecordingState.completed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Arabic Text in Calligraphy Font with live karaoke words during recording or colored words if completed
          if ((_recordingState == RecordingState.recording ||
                  _recordingState == RecordingState.pausedOnMistake) &&
              _aligner != null &&
              _alignerSnapshot != null) ...[
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: List.generate(_aligner!.currentAyah.displayWords.length, (idx) {
                  final word = _aligner!.currentAyah.displayWords[idx];
                  final activeIdx = _alignerSnapshot!.activeWordIndex;
                  final isPast = idx < activeIdx;
                  final isActive = idx == activeIdx;
                  final isPausedError = isActive && _recordingState == RecordingState.pausedOnMistake;

                  Color wordColor;
                  Color bgColor = Colors.transparent;
                  Border? border;

                  if (isPast) {
                    final status = idx < _alignerSnapshot!.wordStatuses.length
                        ? _alignerSnapshot!.wordStatuses[idx]
                        : null;
                    if (status == WordPronunciationStatus.perfect) {
                      wordColor = const Color(0xFF81C784);
                      bgColor = const Color(0xFF81C784).withValues(alpha: 0.15);
                    } else if (status == WordPronunciationStatus.good) {
                      wordColor = const Color(0xFFFFD54F);
                      bgColor = const Color(0xFFFFD54F).withValues(alpha: 0.15);
                    } else {
                      wordColor = const Color(0xFFEF9A9A);
                      bgColor = const Color(0xFFEF9A9A).withValues(alpha: 0.15);
                    }
                  } else if (isActive) {
                    if (isPausedError) {
                      wordColor = const Color(0xFFFF7043);
                      bgColor = const Color(0xFFFF7043).withValues(alpha: 0.25);
                      border = Border.all(color: const Color(0xFFFF7043), width: 2.0);
                    } else {
                      wordColor = const Color(0xFFFFD54F);
                      bgColor = const Color(0xFFFFD54F).withValues(alpha: 0.18 + 0.15 * _pulseController.value);
                      border = Border.all(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.6 + 0.4 * _pulseController.value),
                        width: 1.5,
                      );
                    }
                  } else {
                    wordColor = const Color(0xFFFFF9E6).withValues(alpha: 0.55);
                  }

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: border,
                    ),
                    child: Text(
                      word,
                      style: GoogleFonts.amiri(
                        fontSize: 26,
                        height: 1.9,
                        fontWeight: FontWeight.bold,
                        color: wordColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ] else if (_recordingState == RecordingState.completed && _result != null) ...[
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                spacing: 6,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: _result!.words.map((w) {
                  Color wordColor;
                  switch (w.status) {
                    case WordPronunciationStatus.perfect:
                      wordColor = const Color(0xFF81C784);
                      break;
                    case WordPronunciationStatus.good:
                      wordColor = const Color(0xFFFFD54F);
                      break;
                    case WordPronunciationStatus.needsPractice:
                      wordColor = const Color(0xFFEF9A9A);
                      break;
                  }
                  return GestureDetector(
                    onTap: () {
                      _showWordPronunciationDetailModal(context, w, isBengali);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: wordColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: wordColor.withValues(alpha: 0.5), width: 1.0),
                      ),
                      child: Text(
                        w.arabicWord,
                        style: GoogleFonts.amiri(
                          fontSize: 26,
                          height: 1.9,
                          fontWeight: FontWeight.bold,
                          color: wordColor,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            Text(
              _arabicText,
              style: GoogleFonts.amiri(
                fontSize: 26,
                height: 2.0,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFF9E6),
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ],
          if (!isFullSurahFinished && displayPhonetic != null && displayPhonetic.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Text(
              displayPhonetic,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: NekiColors.goldLight.withValues(alpha: 0.9),
                height: 1.4,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.left,
            ),
          ],

          if (!isFullSurahFinished && displayTrans != null && displayTrans.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              displayTrans,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
                decoration: TextDecoration.none,
              ),
            ),
          ],

          if (!isFullSurahFinished &&
              _recitationMode == RecitationMode.fullSurah &&
              widget.surahNumber != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_rounded, size: 14, color: NekiColors.emeraldLight),
                  const SizedBox(width: 8),
                  Text(
                    '${isBengali ? 'সূরা অগ্রগতি' : 'Surah Progress'}: ${_currentSurahAyahIndex + 1} / ${quran.getVerseCount(widget.surahNumber!)}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${(((_alignerSnapshot?.overallSurahProgress ?? 0.0) * 100).toInt())}%',
                    style: const TextStyle(fontSize: 11.5, color: NekiColors.emeraldLight, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdleSection(bool isBengali) {
    return Column(
      children: [
        if (_permissionDenied) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: (_recordingStartResult == RecordingStartResult.pluginNotLoaded
                      ? Colors.amber
                      : Colors.redAccent)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (_recordingStartResult == RecordingStartResult.pluginNotLoaded
                        ? Colors.amber
                        : Colors.redAccent)
                    .withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _recordingStartResult == RecordingStartResult.pluginNotLoaded
                          ? Icons.restart_alt_rounded
                          : Icons.mic_off_rounded,
                      color: _recordingStartResult == RecordingStartResult.pluginNotLoaded
                          ? Colors.amber
                          : Colors.redAccent,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _recordingStartResult == RecordingStartResult.pluginNotLoaded
                            ? 'App Restart Required: Newly added native audio packages require a full app restart. In your terminal running flutter, press "q" and run "flutter run" again to compile native microphone support.'
                            : (isBengali
                                ? 'আপনার আরবি উচ্চারণ যাচাই করতে মাইক্রোফোনের অনুমতি প্রয়োজন। অনুগ্রহ করে ডিভাইস সেটিংসে অনুমতি দিন।'
                                : 'Microphone access is required to check your Arabic pronunciation. Please allow access in device settings.'),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: simulateRecitation,
                    icon: const Icon(Icons.science_rounded, size: 16, color: NekiColors.goldLight),
                    label: Text(
                      isBengali ? 'প্রদর্শন মোড (ডেমো)' : 'Preview Pronunciation Studio (Demo Mode)',
                      style: const TextStyle(fontSize: 12, color: NekiColors.goldLight, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: NekiColors.goldLight.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),
        Text(
          isBengali
              ? 'আরবিতে সুস্পষ্ট কণ্ঠে আপনার মাইক্রোফোনে পাঠ করুন'
              : 'Recite aloud clearly into your microphone in Arabic',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _startRecording,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [NekiColors.emeraldPrimary, Color(0xFF13452B)],
                  ),
                  border: Border.all(
                    color: NekiColors.emeraldLight.withValues(alpha: 0.6 + 0.4 * _pulseController.value),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.4 * _pulseController.value),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isBengali ? 'তেলাওয়াত শুরু করতে চাপুন' : 'Tap to Begin Recitation',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: NekiColors.emeraldLight,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 18),

        // In-Modal Authentic Audio Preview Button
        Consumer(
          builder: (context, ref, _) {
            final audioState = ref.watch(recitationAudioProvider);
            final isAudioPlaying = audioState.isPlaying;

            return OutlinedButton.icon(
              onPressed: _playAuthenticAudio,
              icon: Icon(
                isAudioPlaying ? Icons.pause_circle_filled_rounded : Icons.volume_up_rounded,
                size: 19,
                color: NekiColors.emeraldLight,
              ),
              label: Text(
                isAudioPlaying
                    ? (isBengali ? 'প্রকৃত তেলাওয়াত বিরতি দিন' : 'Pause Authentic Recitation')
                    : (isBengali ? 'প্রকৃত উচ্চারণ শুনুন' : 'Listen to Authentic Pronunciation'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.emeraldLight,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: NekiColors.emeraldLight.withValues(alpha: isAudioPlaying ? 0.9 : 0.45),
                  width: 1.3,
                ),
                backgroundColor: isAudioPlaying
                    ? NekiColors.emeraldPrimary.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.04),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordingSection(bool isBengali) {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isBengali ? 'শুনছি' : 'Listening'}: $minutes:$seconds',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Live Audio Visualizer driven by microphone amplitude
        AudioVisualizerWidget(
          isPlaying: true,
          barCount: 16,
          height: 38 + (_soundLevel * 14),
          barWidth: 3.5,
          color: NekiColors.emeraldLight,
        ),

        // Live recognized Arabic text stream
        if (_liveSpokenWords.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  isBengali ? 'শুনছি (সরাসরি):' : 'Hearing (Live):',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Text(
                  _liveSpokenWords,
                  style: GoogleFonts.amiri(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFF9E6),
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Auto-stop indicator hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: NekiColors.emeraldPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: NekiColors.emeraldLight),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isBengali
                      ? 'তিলাওয়াত শেষ হলে স্বয়ংক্রিয়ভাবে সমাপ্ত হবে'
                      : 'Auto-stops when recitation is complete',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: NekiColors.emeraldLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _stopAndEvaluate,
          style: ElevatedButton.styleFrom(
            backgroundColor: NekiColors.emeraldPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.stop_rounded),
          label: Text(
            isBengali ? 'সমাপ্ত করুন ও যাচাই করুন' : 'Finish & Evaluate Pronunciation',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPausedOnMistakeSection(bool isBengali) {
    final audioState = ref.watch(recitationAudioProvider);
    final isAudioPlaying = audioState.isPlaying;
    final mistake = _activeMistake;
    final expectedWord = mistake?.arabicWord ??
        (_aligner != null &&
                _aligner!.activeWordIndex <
                    _aligner!.currentAyah.displayWords.length
            ? _aligner!.currentAyah.displayWords[_aligner!.activeWordIndex]
            : '');
    final spokenWord = mistake?.spokenWord;
    final issueDesc = mistake?.issueDescription ??
        (isBengali
            ? 'উচ্চারণে গরমিল শনাক্ত হয়েছে।'
            : 'Pronunciation divergence detected.');
    final makhrajTip = mistake?.makhrajTip ??
        mistake?.correctionAction ??
        (isBengali
            ? 'হরফের সঠিক মাখরাজ থেকে ধীরে ধীরে পাঠ করুন।'
            : 'Articulate cleanly from the letter Makhraj.');

    final expectedPronunciation = _getPronunciationForWord(
      expectedWord,
      isBengali,
      fallbackTransliteration: mistake?.transliteration,
    );
    final spokenPronunciation = spokenWord != null && spokenWord.isNotEmpty
        ? _getPronunciationForWord(spokenWord, isBengali)
        : (isBengali ? '(অনুপস্থিত)' : '(Omitted)');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1408),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.amberAccent.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_circle_filled_rounded,
                  color: Colors.amberAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBengali
                          ? 'তিলাওয়াত স্থগিত: সংশোধন প্রয়োজন'
                          : 'Recitation Paused: Practice Word',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                    Text(
                      isBengali
                          ? 'সঠিকভাবে উচ্চারণ করুন, স্বয়ংক্রিয়ভাবে পুনরায় শুরু হবে'
                          : 'Say the word accurately to resume recitation automatically',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Word comparison row: What Was Heard vs Expected Word
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // What was heard
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        isBengali ? 'যা শোনা গেছে' : 'What Was Heard',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF9A9A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spokenWord ?? (isBengali ? 'বাদ পড়েছে' : 'Skipped'),
                        style: GoogleFonts.amiri(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEF9A9A),
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spokenPronunciation,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontStyle: isBengali ? FontStyle.normal : FontStyle.italic,
                          color: const Color(0xFFFFD54F),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (spokenWord != null && spokenWord.isNotEmpty)
                        _buildWordTtsPillButton(
                          textToSpeak: spokenWord,
                          buttonKey: 'live_spoken',
                          isBengali: isBengali,
                          accentColor: const Color(0xFFEF9A9A),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: Colors.white12,
                ),
                // Expected word (what it should have been)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        isBengali ? 'প্রত্যাশিত শব্দ' : 'Expected Word',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF81C784),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expectedWord,
                        style: GoogleFonts.amiri(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF81C784),
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        expectedPronunciation,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontStyle: isBengali ? FontStyle.normal : FontStyle.italic,
                          color: const Color(0xFF81C784),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (expectedWord.isNotEmpty)
                        _buildWordTtsPillButton(
                          textToSpeak: expectedWord,
                          buttonKey: 'live_expected',
                          isBengali: isBengali,
                          accentColor: const Color(0xFF81C784),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Makhraj & Diagnostic Advice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.amberAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issueDesc,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        makhrajTip,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Live Listening Pulse Pill (Full width, centered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amberAccent.withValues(
                        alpha: 0.4 + 0.6 * _pulseController.value,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isBengali
                        ? 'পুনরায় বলার অপেক্ষায়...'
                        : 'Listening for correction...',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action buttons: Listen Again & Skip Word
          Row(
            children: [
              // Listen Again Audio Button inside Mistake Card
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _playAuthenticAudio,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                    side: BorderSide(
                      color: isAudioPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                    ),
                    backgroundColor: isAudioPlaying
                        ? NekiColors.gold.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isAudioPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                    size: 15,
                  ),
                  label: Text(
                    isAudioPlaying
                        ? (isBengali ? 'বিরতি' : 'Pause')
                        : (isBengali ? 'আবার শুনুন' : 'Listen Again'),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Skip Word Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _skipActiveMistake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 16),
                  label: Text(
                    isBengali ? 'এড়িয়ে যান' : 'Skip',
                    style: const TextStyle(fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModePill({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? NekiColors.emeraldPrimary.withValues(alpha: 0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: NekiColors.emeraldLight, width: 1.2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingSection(bool isBengali) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const CircularProgressIndicator(color: NekiColors.emeraldLight),
          const SizedBox(height: 18),
          Text(
            isBengali
                ? 'AI স্পিচ রিকগনিশন দ্বারা তেলাওয়াত মূল্যায়ন করা হচ্ছে...'
                : 'Evaluating pronunciation with AI speech recognition...',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isBengali
                ? 'হরফের মাখরাজ, টান ও তাজবীদের বিশুদ্ধতা বিশ্লেষণ চলছে'
                : 'Analyzing letter articulation, elongation & Makhraj accuracy',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(PronunciationResult result, bool isBengali) {
    final isHighScore = result.overallScore >= 85;
    final englishPhonetics = QuranTransliterationService.transliterateArabic(result.spokenText);
    final bengaliPhonetics = BengaliPhoneticHelper.toBengaliPronunciation(englishPhonetics);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Score Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (isHighScore ? NekiColors.emeraldPrimary : const Color(0xFFC78B1E))
                    .withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isHighScore ? NekiColors.emeraldLight : NekiColors.goldLight)
                  .withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isHighScore
                          ? NekiColors.emeraldPrimary.withValues(alpha: 0.3)
                          : NekiColors.gold.withValues(alpha: 0.3),
                      border: Border.all(
                        color: isHighScore ? NekiColors.emeraldLight : NekiColors.goldLight,
                        width: 2.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${result.overallScore}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isHighScore ? NekiColors.emeraldLight : NekiColors.goldLight,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBengali
                              ? (result.overallScore >= 90
                                  ? 'মুমতাজ! (অসাধারণ তিলাওয়াত)'
                                  : result.overallScore >= 80
                                      ? 'জাইয়্যিদ জিদ্দান! (চমৎকার তিলাওয়াত)'
                                      : result.overallScore >= 70
                                          ? 'জাইয়্যিদ (ভালো তিলাওয়াত)'
                                          : result.overallScore >= 50
                                              ? 'মাকবুল (গ্রহণযোগ্য)'
                                              : 'অনুশীলন প্রয়োজন')
                              : result.qualityTitle.replaceAll('Mumtāz', 'Mumtaz'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isHighScore ? NekiColors.emeraldLight : NekiColors.goldLight,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isBengali
                              ? (result.overallScore >= 90
                                  ? 'মাশাআল্লাহ! অত্যন্ত নিখুঁত উচ্চারণ ও ছন্দময় সুন্দর তিলাওয়াত।'
                                  : result.overallScore >= 80
                                      ? 'উচ্চারণ বেশ স্পষ্ট এবং চমৎকার। চিহ্নিত শব্দগুলো আরেকবার দেখে নিন।'
                                      : result.overallScore >= 65
                                          ? 'ভালো প্রচেষ্টা! ভারী হরফ ও মাখরাজে আরেকটু মনোযোগ দিন।'
                                          : 'প্রতিটি প্রচেষ্টা সওয়াবপূর্ণ! লাল চিহ্নিত শব্দগুলোতে ট্যাপ করে নির্দেশিকা দেখুন।')
                              : result.feedbackSummary,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                            decoration: TextDecoration.none,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Engine Badge
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        result.isOfflineFallback
                            ? Icons.offline_bolt_rounded
                            : Icons.auto_awesome_rounded,
                        size: 13,
                        color: result.isOfflineFallback ? NekiColors.goldLight : NekiColors.emeraldLight,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          result.isOfflineFallback
                              ? (isBengali ? 'অন-ডিভাইস স্পিচ ইঞ্জিন (অফলাইন)' : 'On-Device Speech Engine (Offline)')
                              : 'Groq Whisper Large-v3 (Wispr Flow Accuracy)',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Recognized Text Comparison Card ("What was heard from your voice")
        if (result.spokenText.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.record_voice_over_rounded,
                      size: 16,
                      color: NekiColors.goldLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isBengali ? 'আপনার কণ্ঠে যা শোনা গেছে:' : 'What was heard from your voice:',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.goldLight,
                        ),
                      ),
                    ),
                    _buildWordTtsPillButton(
                      textToSpeak: result.spokenText,
                      buttonKey: 'results_spoken_all',
                      isBengali: isBengali,
                      accentColor: NekiColors.goldLight,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Prominent Arabic Recognized Text
                Text(
                  result.spokenText,
                  style: GoogleFonts.amiri(
                    fontSize: 24,
                    height: 1.8,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFF9E6),
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                // Pronunciation representation for learners (single active language mode)
                if (isBengali && bengaliPhonetics.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'উচ্চারণ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: NekiColors.emeraldLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bengaliPhonetics,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFD54F),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (!isBengali && englishPhonetics.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Phonetic',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          englishPhonetics,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF81C784),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // MERGED: WHERE YOU WENT WRONG & HOW TO FIX IT (with small ℹ️ icon for trilingual popup guidance)
        _buildMistakesAndCorrectionsSection(result, isBengali),

        const SizedBox(height: 18),

        // Detected Tajweed Rules
        if (result.detectedTajweedRules.isNotEmpty) ...[
          Text(
            isBengali ? 'লক্ষণীয় তাজবীদ নিয়মসমূহ' : 'Tajweed Rules to Observe',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          ...result.detectedTajweedRules.map((rule) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book_rounded,
                          size: 16, color: NekiColors.goldLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: NekiColors.goldLight,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          rule.letters,
                          style: GoogleFonts.amiri(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rule.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 16),

        // Encouragement note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isBengali
                ? (result.encouragementBn ?? 'রাসূলুল্লাহ (সা.) বলেছেন: "তোমাদের মধ্যে সর্বোত্তম সেই ব্যক্তি, যে নিজে কুরআন শিখে এবং অন্যকে শিক্ষা দেয়।" (সহীহ বুখারী)')
                : result.encouragement.replaceAll('ﷺ', '(pbuh)'),
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.3,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// High-contrast, actionable breakdown showing where mistakes occurred and exactly how to fix them.
  Widget _buildMistakesAndCorrectionsSection(PronunciationResult result, bool isBengali) {
    final mistakes = result.words
        .where((w) => w.status != WordPronunciationStatus.perfect)
        .toList();

    if (mistakes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: NekiColors.goldLight, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBengali ? 'মাশাআল্লাহ! নির্ভুল উচ্চারণ' : 'MashaAllah! Flawless Pronunciation',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.emeraldLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isBengali
                        ? 'প্রতিটি শব্দ ও হরফের মাখরাজ নির্ভুলভাবে উচ্চারিত হয়েছে।'
                        : 'Every word and letter articulation matched the authentic recitation perfectly.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_rounded, size: 18, color: NekiColors.goldLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isBengali ? 'ভুল উচ্চারণ ও সংশোধনের উপায়' : 'Where You Went Wrong & How to Fix',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.goldLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isBengali
              ? 'নিচের শব্দগুলোতে বিশেষ মনোযোগ দিন এবং মুখের ভঙ্গি সংশোধন করুন:'
              : 'Pay close attention to these words and follow the mouth/tongue guidance:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        ...mistakes.map((w) {
          final isNeedsPractice = w.status == WordPronunciationStatus.needsPractice;
          final accentColor = isNeedsPractice ? Colors.redAccent : const Color(0xFFFFB300);

          final issueText = (isBengali && w.issueDescriptionBn != null && w.issueDescriptionBn!.isNotEmpty)
              ? w.issueDescriptionBn!
              : (w.issueDescription ?? '');

          final actionText = (isBengali && w.correctionActionBn != null && w.correctionActionBn!.isNotEmpty)
              ? w.correctionActionBn!
              : (w.correctionAction ?? '');

          final expectedPronunciation = _getPronunciationForWord(
            w.arabicWord,
            isBengali,
            fallbackTransliteration: w.transliteration,
          );

          final hasSpokenWord = w.spokenWord != null && w.spokenWord!.trim().isNotEmpty;
          final spokenPronunciation = hasSpokenWord
              ? _getPronunciationForWord(w.spokenWord!, isBengali)
              : (isBengali ? '(অনুপস্থিত)' : '(Omitted)');

          final mistakeId = '${w.arabicWord}_${w.spokenWord ?? "none"}';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showWordPronunciationDetailModal(context, w, isBengali),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Status Tag Pill + Info Guidance Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isNeedsPractice
                                ? (isBengali ? 'অনুশীলন প্রয়োজন' : 'Needs Practice')
                                : (isBengali ? 'উন্নতি সম্ভব' : 'Good Attempt'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isNeedsPractice
                                  ? const Color(0xFFEF9A9A)
                                  : const Color(0xFFFFD54F),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Small Info Icon button for full popup guidance
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 19,
                            color: NekiColors.goldLight,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: isBengali ? 'বিস্তারিত উচ্চারণ নির্দেশিকা' : 'Detailed Pronunciation Guide',
                          onPressed: () => _showWordPronunciationDetailModal(context, w, isBengali),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Side-by-Side Comparison: What Was Heard vs What It Should Have Been
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // What was heard
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  isBengali ? 'যা শোনা গেছে' : 'What Was Heard',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEF9A9A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasSpokenWord ? w.spokenWord! : (isBengali ? 'বাদ পড়েছে' : 'Skipped'),
                                  style: GoogleFonts.amiri(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEF9A9A),
                                  ),
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  spokenPronunciation,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: isBengali ? FontStyle.normal : FontStyle.italic,
                                    color: const Color(0xFFFFD54F),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                if (hasSpokenWord)
                                  _buildWordTtsPillButton(
                                    textToSpeak: w.spokenWord!,
                                    buttonKey: 'mistake_heard_$mistakeId',
                                    isBengali: isBengali,
                                    accentColor: const Color(0xFFEF9A9A),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 90,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            color: Colors.white12,
                          ),
                          // What it should have been
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  isBengali ? 'প্রত্যাশিত শব্দ' : 'Expected Word',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF81C784),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  w.arabicWord,
                                  style: GoogleFonts.amiri(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF81C784),
                                  ),
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  expectedPronunciation,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: isBengali ? FontStyle.normal : FontStyle.italic,
                                    color: const Color(0xFF81C784),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                _buildWordTtsPillButton(
                                  textToSpeak: w.arabicWord,
                                  buttonKey: 'mistake_expected_$mistakeId',
                                  isBengali: isBengali,
                                  accentColor: const Color(0xFF81C784),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Issue Description / What went wrong
                    if (issueText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 15, color: Colors.redAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                issueText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFCDD2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Actionable Physical Makhraj & Mouth/Tongue Guidance
                    if (actionText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: NekiColors.emeraldLight.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.record_voice_over_rounded, size: 15, color: NekiColors.emeraldLight),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: isBengali ? 'সংশোধনের উপায়: ' : 'How to Fix: ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: NekiColors.emeraldLight,
                                      ),
                                    ),
                                    TextSpan(
                                      text: actionText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Trilingual pop-up guidance modal for word-level pronunciation diagnostics.
  /// Displays the target Arabic word, heard speech, and precise tongue/mouth articulation
  /// guidance in Arabic, English, and Bengali.
  void _showWordPronunciationDetailModal(
    BuildContext context,
    VocalizedWordFeedback word,
    bool isBengali,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final isNeedsPractice = word.status == WordPronunciationStatus.needsPractice;
        final accentColor = isNeedsPractice ? Colors.redAccent : const Color(0xFFFFB300);
        final englishTrans = word.transliteration;
        final bengaliTrans = BengaliPhoneticHelper.toBengaliPronunciation(englishTrans);
        final issueEn = word.issueDescription ?? 'Word articulation divergence detected.';
        final issueBn = word.issueDescriptionBn ?? (isBengali ? 'উচ্চারণে অসংগতি পাওয়া গেছে।' : issueEn);
        final actionEn = word.correctionAction ?? 'Adjust tongue and mouth position according to authentic Tajweed.';
        final actionBn = word.correctionActionBn ?? (isBengali ? 'সহীহ তেলাওয়াতকারীর ন্যায় মাখরাজ অনুযায়ী জিহ্বা ও ঠোঁট নিয়ন্ত্রণ করুন।' : actionEn);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161E1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.3)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: NekiColors.goldLight, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isBengali ? 'উচ্চারণের বিস্তারিত বিশ্লেষণ' : 'Detailed Pronunciation Breakdown',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.goldLight,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                      onPressed: () => Navigator.pop(modalContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Authentic Scripture Word vs Spoken Arabic Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isBengali ? 'উচ্চারণ তুলনা' : 'Pronunciation Comparison',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isNeedsPractice
                                  ? (isBengali ? 'অনুশীলন প্রয়োজন' : 'Needs Practice')
                                  : (isBengali ? 'উন্নতি সম্ভব' : 'Good Attempt'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isNeedsPractice ? const Color(0xFFEF9A9A) : const Color(0xFFFFD54F),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Side-by-side comparison
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // What was heard
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    isBengali ? 'যা শোনা গেছে' : 'What Was Heard',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFEF9A9A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (word.spokenWord != null && word.spokenWord!.isNotEmpty)
                                        ? word.spokenWord!
                                        : (isBengali ? 'বাদ পড়েছে' : 'Skipped'),
                                    style: GoogleFonts.amiri(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFEF9A9A),
                                    ),
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    (word.spokenWord != null && word.spokenWord!.isNotEmpty)
                                        ? _getPronunciationForWord(word.spokenWord!, isBengali)
                                        : (isBengali ? '(অনুপস্থিত)' : '(Omitted)'),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: isBengali ? FontStyle.normal : FontStyle.italic,
                                      color: const Color(0xFFFFD54F),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  if (word.spokenWord != null && word.spokenWord!.isNotEmpty)
                                    _buildWordTtsPillButton(
                                      textToSpeak: word.spokenWord!,
                                      buttonKey: 'detail_spoken_${word.arabicWord}',
                                      isBengali: isBengali,
                                      accentColor: const Color(0xFFEF9A9A),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 100,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              color: Colors.white12,
                            ),
                            // What it should have been
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    isBengali ? 'প্রত্যাশিত শব্দ' : 'Expected Word',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF81C784),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    word.arabicWord,
                                    style: GoogleFonts.amiri(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF81C784),
                                    ),
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _getPronunciationForWord(
                                      word.arabicWord,
                                      isBengali,
                                      fallbackTransliteration: word.transliteration,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: isBengali ? FontStyle.normal : FontStyle.italic,
                                      color: const Color(0xFF81C784),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildWordTtsPillButton(
                                    textToSpeak: word.arabicWord,
                                    buttonKey: 'detail_expected_${word.arabicWord}',
                                    isBengali: isBengali,
                                    accentColor: const Color(0xFF81C784),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (isBengali)
                  // Bangla Pronunciation Guidance
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'বাংলা উচ্চারণ নির্দেশিকা',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: NekiColors.emeraldLight),
                          ),
                        ),
                        if (bengaliTrans.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'উচ্চারণ: $bengaliTrans',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFD54F),
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'ভুল বিশ্লেষণ: $issueBn',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFFFFCDD2), height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'উচ্চারণ সংশোধনের উপায়: ',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: NekiColors.emeraldLight),
                              ),
                              TextSpan(
                                text: actionBn,
                                style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // English Pronunciation Guidance
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'English Pronunciation Guide',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        if (englishTrans.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Pronunciation: $englishTrans',
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: NekiColors.goldLight,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Discrepancy: $issueEn',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFFFFCDD2), height: 1.3),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'How to Fix: ',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: NekiColors.emeraldLight),
                              ),
                              TextSpan(
                                text: actionEn,
                                style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Listen to Authentic Audio Button
                OutlinedButton.icon(
                  onPressed: () {
                    _playAuthenticAudio();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.goldLight,
                    side: const BorderSide(color: NekiColors.goldLight),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: Text(
                    isBengali ? 'আবার শুনুন' : 'Listen Again',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
