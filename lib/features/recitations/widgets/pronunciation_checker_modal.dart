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
import '../providers/recitation_audio_provider.dart';
import '../services/pronunciation_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/whisper_speech_service.dart';
import 'audio_visualizer_widget.dart';

enum RecordingState { idle, recording, analyzing, completed }

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
  VocalizedWordFeedback? _selectedWordDetail;
  bool _isBangla = false;

  @override
  void initState() {
    super.initState();
    _verseNumber = widget.verseNumber;
    _title = widget.title;
    _arabicText = widget.arabicText;
    _transliteration = widget.transliteration;
    _translation = widget.translation;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    // Ensure microphone and audio resources are cleanly released
    WhisperSpeechService.instance.cancel();
    SpeechRecognitionService.instance.cancel();
    super.dispose();
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
    });

    // 1. Begin audio capture for Whisper
    final startResult = await WhisperSpeechService.instance.startRecording(
      onSoundLevel: (level) {
        if (mounted && _recordingState == RecordingState.recording) {
          setState(() => _soundLevel = level);
        }
      },
    );

    if (startResult != RecordingStartResult.success) {
      if (mounted) {
        setState(() {
          _recordingStartResult = startResult;
          _permissionDenied = true;
        });
      }
      return;
    }

    // 2. Start on-device STT in parallel for live streaming words on screen
    SpeechRecognitionService.instance.startListening(
      onResult: (words) {
        if (mounted && _recordingState == RecordingState.recording) {
          setState(() => _liveSpokenWords = words);
        }
      },
      onSoundLevel: (level) {
        if (mounted && _recordingState == RecordingState.recording && _soundLevel == 0.0) {
          setState(() => _soundLevel = level);
        }
      },
    );

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
    _timer?.cancel();
    setState(() => _recordingState = RecordingState.analyzing);

    // Stop audio recording and native recognizer
    final audioPath = await WhisperSpeechService.instance.stopRecording();
    final fallbackText = await SpeechRecognitionService.instance.stopListening();

    final actualSpoken = fallbackText.isNotEmpty ? fallbackText : _liveSpokenWords;

    PronunciationResult result;
    if (audioPath != null) {
      result = await PronunciationService.instance.evaluateAudioFile(
        audioPath: audioPath,
        targetArabic: _arabicText,
        fallbackSpokenText: actualSpoken,
        transliteration: _transliteration,
        recordedDuration: Duration(seconds: _elapsedSeconds),
      );
    } else {
      result = PronunciationService.instance.evaluateRecitation(
        arabicText: _arabicText,
        transliteration: _transliteration,
        spokenArabic: actualSpoken,
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
    WhisperSpeechService.instance.cancel();
    SpeechRecognitionService.instance.cancel();
    setState(() {
      _recordingState = RecordingState.idle;
      _elapsedSeconds = 0;
      _soundLevel = 0.0;
      _liveSpokenWords = '';
      _result = null;
      _selectedWordDetail = null;
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
        ? '${quran.getSurahName(widget.surahNumber!)} • আয়াত $newNum'
        : '${quran.getSurahName(widget.surahNumber!)} • Ayah $newNum';
    final nextTrans = QuranVerseHelper.getVerseTranslation(widget.surahNumber!, newNum, translationLang);

    setState(() {
      _verseNumber = newNum;
      _arabicText = nextArabic;
      _title = nextTitle;
      _transliteration = null;
      _translation = nextTrans;
      _recordingState = RecordingState.idle;
      _elapsedSeconds = 0;
      _result = null;
      _selectedWordDetail = null;
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
        if (mounted && text != null && _verseNumber == ayah) {
          setState(() => _transliteration = text);
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

  String _computeDisplayTitle() {
    if (!_isBangla) {
      return _title;
    }
    if (widget.surahNumber != null && _verseNumber != null) {
      return '${quran.getSurahName(widget.surahNumber!)} • আয়াত $_verseNumber';
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
                          ? (_isBangla
                              ? 'আয়াত $_verseNumber / ${quran.getVerseCount(widget.surahNumber!)}'
                              : 'Ayah $_verseNumber of ${quran.getVerseCount(widget.surahNumber!)}')
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

                // Master Reciter Audio Button
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
                          : (isBengali ? 'শুনুন' : 'Master Reciter'),
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
                Text(
                  '${isBengali ? 'রেকর্ডিং হচ্ছে' : 'Recording'}: ${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _stopAndEvaluate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: Text(
                    isBengali ? 'সমাপ্ত করুন' : 'Finish & Evaluate',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                          : (isBengali ? 'তেলাওয়াত শুনুন' : 'Master Reciter'),
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
          // Arabic Text in Calligraphy Font with colored words if completed
          if (_recordingState == RecordingState.completed && _result != null) ...[
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
                  final isSelected = _selectedWordDetail == w;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedWordDetail = isSelected ? null : w;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? wordColor.withValues(alpha: 0.25) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected ? Border.all(color: wordColor, width: 1.5) : null,
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

          if (displayPhonetic != null && displayPhonetic.isNotEmpty) ...[
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

          if (displayTrans != null && displayTrans.isNotEmpty) ...[
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

        const SizedBox(height: 24),
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
                          result.qualityTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isHighScore ? NekiColors.emeraldLight : NekiColors.goldLight,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.feedbackSummary,
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
                      Text(
                        result.isOfflineFallback
                            ? (isBengali ? 'অন-ডিভাইস স্পিচ ইঞ্জিন (অফলাইন)' : 'On-Device Speech Engine (Offline)')
                            : 'Groq Whisper Large-v3 (Wispr Flow Accuracy)',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Recognized Text Comparison Card
        if (result.spokenText.isNotEmpty) ...[
          const SizedBox(height: 14),
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
                Text(
                  isBengali ? 'আপনার কণ্ঠে যা শোনা গেছে:' : 'What was heard from your voice:',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                ),
                const SizedBox(height: 4),
                Text(
                  result.spokenText,
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    color: const Color(0xFFFFF9E6),
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // DEDICATED MISTAKES & HOW TO FIX SECTION
        _buildMistakesAndCorrectionsSection(result, isBengali),

        const SizedBox(height: 18),

        // Word-by-word colored breakdown
        Text(
          isBengali
              ? 'প্রতিটি শব্দের উচ্চারণ বিশ্লেষণ (পরামর্শের জন্য চাপুন)'
              : 'Word-by-Word Pronunciation Feedback (Tap for Tips)',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          direction: Axis.horizontal,
          children: result.words.map((w) {
            Color pillColor;
            Color textColor;
            IconData icon;

            switch (w.status) {
              case WordPronunciationStatus.perfect:
                pillColor = const Color(0xFF2E7D52).withValues(alpha: 0.25);
                textColor = const Color(0xFF81C784);
                icon = Icons.check_circle_rounded;
                break;
              case WordPronunciationStatus.good:
                pillColor = const Color(0xFFFFB300).withValues(alpha: 0.22);
                textColor = const Color(0xFFFFD54F);
                icon = Icons.info_rounded;
                break;
              case WordPronunciationStatus.needsPractice:
                pillColor = const Color(0xFFE53935).withValues(alpha: 0.22);
                textColor = const Color(0xFFEF9A9A);
                icon = Icons.priority_high_rounded;
                break;
            }

            final isSelected = _selectedWordDetail == w;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedWordDetail = isSelected ? null : w;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? textColor.withValues(alpha: 0.25) : pillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: textColor.withValues(alpha: isSelected ? 0.9 : 0.4),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: textColor),
                    const SizedBox(width: 6),
                    Text(
                      w.arabicWord,
                      style: GoogleFonts.amiri(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Selected Word Feedback Detail Card
        if (_selectedWordDetail != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF142B20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _selectedWordDetail!.arabicWord,
                      style: GoogleFonts.amiri(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: NekiColors.goldLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_selectedWordDetail!.spokenWord != null)
                      Text(
                        '(${isBengali ? 'শোনা গেছে' : 'Heard'}: ${_selectedWordDetail!.spokenWord})',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white60),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _selectedWordDetail = null),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedWordDetail!.correctionAction ??
                      _selectedWordDetail!.makhrajTip ??
                      (isBengali ? 'স্পষ্ট ও নির্ভুলভাবে উচ্চারিত।' : 'Pronounced clearly.'),
                  style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.3),
                ),
              ],
            ),
          ),
        ],

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
            result.encouragement,
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
            Text(
              isBengali ? 'ভুল উচ্চারণ ও সংশোধনের উপায়' : 'Where You Went Wrong & How to Fix',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: NekiColors.goldLight,
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

          return Container(
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
                // Top row: Authentic Word vs What was heard + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Authentic Scripture Word
                    Text(
                      w.arabicWord,
                      style: GoogleFonts.amiri(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFF9E6),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(width: 10),
                    // Phonetic transliteration and heard preview
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (w.transliteration.isNotEmpty)
                            Text(
                              isBengali
                                  ? BengaliPhoneticHelper.toBengaliPronunciation(w.transliteration)
                                  : w.transliteration,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: NekiColors.goldLight.withValues(alpha: 0.85),
                              ),
                            ),
                          if (w.spokenWord != null && w.spokenWord!.isNotEmpty)
                            Text(
                              isBengali ? 'শোনা গেছে: ${w.spokenWord}' : 'Heard: ${w.spokenWord}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.white60,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status tag pill
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
                  ],
                ),

                // Issue Description / What went wrong
                if (w.issueDescription != null && w.issueDescription!.isNotEmpty) ...[
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
                            w.issueDescription!,
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
                if (w.correctionAction != null && w.correctionAction!.isNotEmpty) ...[
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
                                  text: w.correctionAction!,
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
          );
        }),
      ],
    );
  }
}
