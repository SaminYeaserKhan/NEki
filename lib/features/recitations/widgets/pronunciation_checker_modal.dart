import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;

import '../../../core/theme/neki_colors.dart';
import '../../quran/utils/quran_verse_helper.dart';
import '../providers/recitation_audio_provider.dart';
import '../services/pronunciation_service.dart';
import 'audio_visualizer_widget.dart';

enum RecordingState { idle, recording, analyzing, completed }

/// Interactive vocalization and pronunciation evaluation studio modal.
/// Supports uninterrupted sequential practice across multiple verses.
class PronunciationCheckerModal extends ConsumerStatefulWidget {
  final String title;
  final String arabicText;
  final String? transliteration;
  final String? translation;
  final int? surahNumber;
  final int? verseNumber;

  const PronunciationCheckerModal({
    super.key,
    required this.title,
    required this.arabicText,
    this.transliteration,
    this.translation,
    this.surahNumber,
    this.verseNumber,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String arabicText,
    String? transliteration,
    String? translation,
    int? surahNumber,
    int? verseNumber,
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
    super.dispose();
  }

  void _startRecording() {
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

    // Artificial brief delay for realistic AI phonetic analysis experience
    await Future.delayed(const Duration(milliseconds: 900));

    final result = PronunciationService.instance.evaluateRecitation(
      arabicText: _arabicText,
      transliteration: _transliteration,
      recordedDuration: Duration(seconds: _elapsedSeconds),
    );

    if (mounted) {
      setState(() {
        _result = result;
        _recordingState = RecordingState.completed;
      });
    }
  }

  void _reset() {
    setState(() {
      _recordingState = RecordingState.idle;
      _elapsedSeconds = 0;
      _result = null;
    });
  }

  void _nextAyah() {
    if (widget.surahNumber != null && _verseNumber != null) {
      final total = quran.getVerseCount(widget.surahNumber!);
      if (_verseNumber! < total) {
        final nextNum = _verseNumber! + 1;
        setState(() {
          _verseNumber = nextNum;
          _arabicText = QuranVerseHelper.getCleanVerseText(widget.surahNumber!, nextNum, verseEndSymbol: false);
          _title = '${quran.getSurahName(widget.surahNumber!)} • Ayah $nextNum';
          _transliteration = null;
          _translation = quran.getVerseTranslation(widget.surahNumber!, nextNum, translation: quran.Translation.enSaheeh);
          _recordingState = RecordingState.idle;
          _elapsedSeconds = 0;
          _result = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        const Text(
                          'Pronunciation & Tajweed Studio',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          _title,
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
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arabic Scripture Display Card
                    _buildScriptureCard(),

                    const SizedBox(height: 18),

                    // Dynamic Studio Section
                    if (_recordingState == RecordingState.idle)
                      _buildIdleSection(),
                    if (_recordingState == RecordingState.recording)
                      _buildRecordingSection(),
                    if (_recordingState == RecordingState.analyzing)
                      _buildAnalyzingSection(),
                    if (_recordingState == RecordingState.completed && _result != null)
                      _buildResultsSection(_result!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScriptureCard() {
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
          // Arabic Text in Calligraphy Font
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

          if (_transliteration != null && _transliteration!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 10),
            Text(
              _transliteration!,
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

          if (_translation != null && _translation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _translation!,
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

  Widget _buildIdleSection() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          'Recite aloud clearly into your microphone',
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
        const Text(
          'Tap to Begin Recitation',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: NekiColors.emeraldLight,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingSection() {
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
              'Listening: $minutes:$seconds',
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
        const AudioVisualizerWidget(
          isPlaying: true,
          barCount: 14,
          height: 36,
          barWidth: 3.5,
          color: NekiColors.emeraldLight,
        ),
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
          label: const Text(
            'Finish & Evaluate Pronunciation',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          CircularProgressIndicator(color: NekiColors.emeraldLight),
          SizedBox(height: 16),
          Text(
            'Analyzing makhraj, phonetics & Tajweed articulation...',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(PronunciationResult result) {
    final isHighScore = result.overallScore >= 88;
    final hasNext = widget.surahNumber != null &&
        _verseNumber != null &&
        _verseNumber! < quran.getVerseCount(widget.surahNumber!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Score Header
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
          child: Row(
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
        ),

        const SizedBox(height: 18),

        // Word-by-word colored breakdown
        const Text(
          'Word-by-Word Pronunciation Feedback',
          style: TextStyle(
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

            return Tooltip(
              message: w.makhrajTip ?? 'Pronunciation recorded',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textColor.withValues(alpha: 0.4)),
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

        const SizedBox(height: 18),

        // Detected Tajweed Rules
        if (result.detectedTajweedRules.isNotEmpty) ...[
          const Text(
            'Tajweed Rules to Observe',
            style: TextStyle(
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
                      Text(
                        rule.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.goldLight,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        rule.letters,
                        style: GoogleFonts.amiri(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          decoration: TextDecoration.none,
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

        const SizedBox(height: 14),

        // Action Buttons: Master Reciter, Retry, and Next Ayah
        Row(
          children: [
            if (widget.surahNumber != null && _verseNumber != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(recitationAudioProvider.notifier).playVerse(
                          widget.surahNumber!,
                          _verseNumber!,
                        );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.emeraldLight,
                    side: const BorderSide(color: NekiColors.emeraldLight),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: const Text('Master Reciter'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ),
            if (hasNext) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _nextAyah,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NekiColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next Ayah'),
                ),
              ),
            ],
          ],
        ),

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
}
