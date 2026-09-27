import 'dart:math';

import 'arabic_pronunciation_matcher.dart';

enum RecitationMode {
  singleAyah,
  fullSurah,
}

enum RealtimeAlignmentEvent {
  wordMatched,
  wordTentative,
  mistakeDetected,
  mistakeResolved,
  wordSkipped,
  ayahCompleted,
  surahCompleted,
  noChange,
}

/// Structured target representing one Ayah inside the recitation session.
class AyahRecitationTarget {
  final int surahNumber;
  final int verseNumber;
  final String arabicText;
  final String? transliteration;
  final String? translation;
  final List<String> displayWords;
  final List<String> normWords;
  final List<String> transliterationWords;

  AyahRecitationTarget({
    required this.surahNumber,
    required this.verseNumber,
    required this.arabicText,
    this.transliteration,
    this.translation,
    List<String>? displayWords,
    List<String>? normWords,
    List<String>? transliterationWords,
  })  : displayWords = displayWords ?? _extractDisplayWords(arabicText),
        normWords = normWords ??
            _extractDisplayWords(arabicText)
                .map(ArabicPronunciationMatcher.normalizeArabic)
                .toList(),
        transliterationWords = transliterationWords ??
            _extractTransliterationWords(transliteration);

  static List<String> _extractDisplayWords(String text) {
    return text
        .replaceAll(RegExp(r"""[0-9٠-٩\(\)\[\]«»"\'.,;:!؟]"""), ' ')
        .replaceAll(RegExp(r'[\u06D6-\u06ED\u0600-\u060F\uFD3E\uFD3F\u06DD\u06DE\u06DF\u06E0\u06E1\u06E2\u06E3\u06E4\u06E5\u06E6\u06E7\u06E8\u06E9\u06EA\u06EB\u06EC\u06ED]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  static List<String> _extractTransliterationWords(String? trans) {
    if (trans == null || trans.isEmpty) return const [];
    return trans
        .replaceAll(RegExp(r'[0-9\(\).,;:!?]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }
}

/// Instantaneous update event emitted whenever new spoken audio tokens arrive.
class AlignmentUpdate {
  final RealtimeAlignmentEvent event;
  final int ayahNumber;
  final int activeWordIndex;
  final int totalWordsInAyah;
  final VocalizedWordFeedback? matchedFeedback;
  final VocalizedWordFeedback? mistakeFeedback;
  final String? spokenToken;
  final double similarity;
  final bool isAyahFinished;
  final bool isSurahFinished;

  const AlignmentUpdate({
    required this.event,
    required this.ayahNumber,
    required this.activeWordIndex,
    required this.totalWordsInAyah,
    this.matchedFeedback,
    this.mistakeFeedback,
    this.spokenToken,
    this.similarity = 0.0,
    this.isAyahFinished = false,
    this.isSurahFinished = false,
  });
}

/// Immutable snapshot representing the entire real-time recitation progress.
class RealtimeRecitationSnapshot {
  final RecitationMode mode;
  final int surahNumber;
  final int currentAyahNumber;
  final int currentAyahIndex;
  final int totalAyahs;
  final int activeWordIndex;
  final int totalWordsInActiveAyah;
  final int completedAyahsCount;
  final List<WordPronunciationStatus?> wordStatuses;
  final List<VocalizedWordFeedback> completedWordFeedbacks;
  final VocalizedWordFeedback? activeMistake;
  final bool isPausedOnMistake;
  final bool isAyahCompleted;
  final bool isSurahCompleted;
  final int totalMistakesCount;

  const RealtimeRecitationSnapshot({
    required this.mode,
    required this.surahNumber,
    required this.currentAyahNumber,
    required this.currentAyahIndex,
    required this.totalAyahs,
    required this.activeWordIndex,
    required this.totalWordsInActiveAyah,
    required this.completedAyahsCount,
    required this.wordStatuses,
    required this.completedWordFeedbacks,
    this.activeMistake,
    required this.isPausedOnMistake,
    required this.isAyahCompleted,
    required this.isSurahCompleted,
    required this.totalMistakesCount,
  });

  double get currentAyahProgress {
    if (totalWordsInActiveAyah == 0) return 0.0;
    return (activeWordIndex / totalWordsInActiveAyah).clamp(0.0, 1.0);
  }

  double get overallSurahProgress {
    if (totalAyahs == 0) return 0.0;
    final ayahPart = completedAyahsCount / totalAyahs;
    final activeAyahPart = (currentAyahProgress / totalAyahs);
    return (ayahPart + activeAyahPart).clamp(0.0, 1.0);
  }

  /// Returns a clean, deduplicated reconstructed transcript of successfully recited words
  /// for the active verse (strips stuttered repetition attempts).
  String get cleanSpokenAyahText {
    final words = completedWordFeedbacks
        .map((f) => f.spokenWord ?? f.arabicWord)
        .where((w) => w.isNotEmpty)
        .toList();
    return words.join(' ');
  }
}

/// High-performance incremental word alignment engine for real-time speech streams.
class StreamingWordAligner {
  final RecitationMode mode;
  final List<AyahRecitationTarget> ayahs;

  int _currentAyahIndex = 0;
  int _activeWordIndex = 0;
  int _processedTokenCount = 0;
  int _totalMistakesCount = 0;
  int _consecutiveMismatches = 0;

  bool _isPausedOnMistake = false;
  VocalizedWordFeedback? _activeMistake;

  final bool enableLiveHalting;
  final List<WordPronunciationStatus?> _currentWordStatuses = [];
  final List<VocalizedWordFeedback> _completedWordFeedbacks = [];
  int _completedAyahsCount = 0;

  StreamingWordAligner({
    required this.mode,
    required this.ayahs,
    this.enableLiveHalting = true,
  }) : assert(ayahs.isNotEmpty, 'Ayah targets must not be empty') {
    _initCurrentAyah();
  }

  /// Convenience constructor for single Ayah recitation.
  factory StreamingWordAligner.single({
    required int surahNumber,
    required int verseNumber,
    required String arabicText,
    String? transliteration,
    String? translation,
    bool enableLiveHalting = true,
  }) {
    return StreamingWordAligner(
      mode: RecitationMode.singleAyah,
      enableLiveHalting: enableLiveHalting,
      ayahs: [
        AyahRecitationTarget(
          surahNumber: surahNumber,
          verseNumber: verseNumber,
          arabicText: arabicText,
          transliteration: transliteration,
          translation: translation,
        ),
      ],
    );
  }

  /// Convenience constructor for Full Surah recitation.
  factory StreamingWordAligner.fullSurah({
    required int surahNumber,
    required List<AyahRecitationTarget> surahAyahs,
    bool enableLiveHalting = false,
  }) {
    return StreamingWordAligner(
      mode: RecitationMode.fullSurah,
      enableLiveHalting: enableLiveHalting,
      ayahs: surahAyahs,
    );
  }

  AyahRecitationTarget get currentAyah => ayahs[_currentAyahIndex];
  int get activeWordIndex => _activeWordIndex;
  bool get isPausedOnMistake => _isPausedOnMistake;
  VocalizedWordFeedback? get activeMistake => _activeMistake;
  bool get hasMoreAyahs => _currentAyahIndex < ayahs.length - 1;

  void _initCurrentAyah({bool preserveTokenCount = false}) {
    _activeWordIndex = 0;
    if (!preserveTokenCount) {
      _processedTokenCount = 0;
    }
    _consecutiveMismatches = 0;
    _isPausedOnMistake = false;
    _activeMistake = null;
    _currentWordStatuses.clear();
    _currentWordStatuses.addAll(
      List.filled(currentAyah.displayWords.length, null),
    );
  }

  /// Resets the engine back to the beginning of the current Ayah or Surah.
  void reset() {
    _currentAyahIndex = 0;
    _completedAyahsCount = 0;
    _completedWordFeedbacks.clear();
    _totalMistakesCount = 0;
    _consecutiveMismatches = 0;
    _initCurrentAyah();
  }

  /// Captures current immutable snapshot for UI consumers.
  RealtimeRecitationSnapshot get snapshot => RealtimeRecitationSnapshot(
        mode: mode,
        surahNumber: currentAyah.surahNumber,
        currentAyahNumber: currentAyah.verseNumber,
        currentAyahIndex: _currentAyahIndex,
        totalAyahs: ayahs.length,
        activeWordIndex: _activeWordIndex,
        totalWordsInActiveAyah: currentAyah.displayWords.length,
        completedAyahsCount: _completedAyahsCount,
        wordStatuses: List.unmodifiable(_currentWordStatuses),
        completedWordFeedbacks: List.unmodifiable(_completedWordFeedbacks),
        activeMistake: _activeMistake,
        isPausedOnMistake: _isPausedOnMistake,
        isAyahCompleted: _activeWordIndex >= currentAyah.displayWords.length,
        isSurahCompleted: _activeWordIndex >= currentAyah.displayWords.length &&
            !hasMoreAyahs,
        totalMistakesCount: _totalMistakesCount,
      );

  /// Processes the cumulative live transcript emitted by speech recognition.
  /// Returns an [AlignmentUpdate] notifying whether words matched, paused on mistake, or completed.
  AlignmentUpdate processTranscript(String cumulativeTranscript) {
    if (cumulativeTranscript.trim().isEmpty) {
      return AlignmentUpdate(
        event: RealtimeAlignmentEvent.noChange,
        ayahNumber: currentAyah.verseNumber,
        activeWordIndex: _activeWordIndex,
        totalWordsInAyah: currentAyah.displayWords.length,
      );
    }

    // Tokenize and normalize all spoken words received so far
    final spokenTokens = cumulativeTranscript
        .split(RegExp(r'\s+'))
        .map(ArabicPronunciationMatcher.normalizeArabic)
        .where((t) => t.isNotEmpty)
        .toList();

    if (spokenTokens.isEmpty) {
      return AlignmentUpdate(
        event: RealtimeAlignmentEvent.noChange,
        ayahNumber: currentAyah.verseNumber,
        activeWordIndex: _activeWordIndex,
        totalWordsInAyah: currentAyah.displayWords.length,
      );
    }

    // 1. If currently paused waiting for retry of a mistake:
    if (_isPausedOnMistake) {
      return _processRetry(spokenTokens);
    }

    AlignmentUpdate lastUpdate = AlignmentUpdate(
      event: RealtimeAlignmentEvent.noChange,
      ayahNumber: currentAyah.verseNumber,
      activeWordIndex: _activeWordIndex,
      totalWordsInAyah: currentAyah.displayWords.length,
    );

    // 2. Process newly arrived tokens sequentially
    if (_processedTokenCount > spokenTokens.length) {
      _processedTokenCount = 0;
    }

    if (_processedTokenCount == spokenTokens.length) {
      return lastUpdate;
    }

    while (_processedTokenCount < spokenTokens.length) {
      if (_activeWordIndex >= currentAyah.normWords.length) {
        // Active verse is already complete
        return _handleAyahCompletion();
      }

      // Synchronize pointer to the start of the active verse if at the beginning of an Ayah
      if (_activeWordIndex == 0 && currentAyah.normWords.isNotEmpty) {
        final firstTarget = currentAyah.normWords[0];
        if (_computeWordSimilarity(firstTarget, spokenTokens[_processedTokenCount]) < 0.65) {
          for (int s = _processedTokenCount + 1; s < spokenTokens.length; s++) {
            if (_computeWordSimilarity(firstTarget, spokenTokens[s]) >= 0.70) {
              _processedTokenCount = s;
              break;
            }
          }
        }
      }

      final currentSpokenToken = spokenTokens[_processedTokenCount];
      final targetNorm = currentAyah.normWords[_activeWordIndex];
      final displayWord = currentAyah.displayWords[_activeWordIndex];
      final transWord = _activeWordIndex < currentAyah.transliterationWords.length
          ? currentAyah.transliterationWords[_activeWordIndex]
          : '';

      final sim = _computeWordSimilarity(targetNorm, currentSpokenToken);

      // 1. Exact or near match on active target word
      if (sim >= 0.65) {
        final status = sim >= 0.88
            ? WordPronunciationStatus.perfect
            : WordPronunciationStatus.good;

        final feedback = VocalizedWordFeedback(
          arabicWord: displayWord,
          spokenWord: currentSpokenToken,
          transliteration: transWord,
          score: sim,
          status: status,
          makhrajTip: ArabicPronunciationMatcher.diagnoseWord(
            displayWord: displayWord,
            targetNorm: targetNorm,
            spokenNorm: currentSpokenToken,
            status: status,
          ).action,
        );

        _currentWordStatuses[_activeWordIndex] = status;
        _completedWordFeedbacks.add(feedback);
        _activeWordIndex++;
        _processedTokenCount++;
        _consecutiveMismatches = 0;

        if (_activeWordIndex >= currentAyah.normWords.length) {
          return _handleAyahCompletion();
        }

        lastUpdate = AlignmentUpdate(
          event: RealtimeAlignmentEvent.wordMatched,
          ayahNumber: currentAyah.verseNumber,
          activeWordIndex: _activeWordIndex,
          totalWordsInAyah: currentAyah.displayWords.length,
          matchedFeedback: feedback,
          spokenToken: currentSpokenToken,
          similarity: sim,
        );
        continue;
      }

      // 2. Check compound target: does current spoken token span active + next target?
      // (e.g. "بسم" + "الله" = "بسمالله" or "الحمد" + "لله" = "الحمدلله")
      if (_activeWordIndex + 1 < currentAyah.normWords.length) {
        final nextTargetNorm = currentAyah.normWords[_activeWordIndex + 1];
        final compoundNorm = targetNorm + nextTargetNorm;
        final compSim = _computeWordSimilarity(compoundNorm, currentSpokenToken);

        if (compSim >= 0.68) {
          final nextDisplay = currentAyah.displayWords[_activeWordIndex + 1];
          final nextTrans = _activeWordIndex + 1 < currentAyah.transliterationWords.length
              ? currentAyah.transliterationWords[_activeWordIndex + 1]
              : '';

          final fb1 = VocalizedWordFeedback(
            arabicWord: displayWord,
            spokenWord: currentSpokenToken,
            transliteration: transWord,
            score: compSim,
            status: WordPronunciationStatus.perfect,
          );
          final fb2 = VocalizedWordFeedback(
            arabicWord: nextDisplay,
            spokenWord: currentSpokenToken,
            transliteration: nextTrans,
            score: compSim,
            status: WordPronunciationStatus.perfect,
          );

          _currentWordStatuses[_activeWordIndex] = WordPronunciationStatus.perfect;
          _currentWordStatuses[_activeWordIndex + 1] = WordPronunciationStatus.perfect;
          _completedWordFeedbacks.add(fb1);
          _completedWordFeedbacks.add(fb2);
          _activeWordIndex += 2;
          _processedTokenCount++;
          _consecutiveMismatches = 0;

          if (_activeWordIndex >= currentAyah.normWords.length) {
            return _handleAyahCompletion();
          }

          lastUpdate = AlignmentUpdate(
            event: RealtimeAlignmentEvent.wordMatched,
            ayahNumber: currentAyah.verseNumber,
            activeWordIndex: _activeWordIndex,
            totalWordsInAyah: currentAyah.displayWords.length,
            matchedFeedback: fb2,
            spokenToken: currentSpokenToken,
            similarity: compSim,
          );
          continue;
        }
      }

      // 3. Check joined spoken match: do 2 consecutive spoken tokens cover target?
      if (_processedTokenCount + 1 < spokenTokens.length) {
        final nextSpoken = spokenTokens[_processedTokenCount + 1];
        final joinedSpoken = currentSpokenToken + nextSpoken;
        final joinedSim = _computeWordSimilarity(targetNorm, joinedSpoken);

        if (joinedSim >= 0.68) {
          final feedback = VocalizedWordFeedback(
            arabicWord: displayWord,
            spokenWord: joinedSpoken,
            transliteration: transWord,
            score: joinedSim,
            status: WordPronunciationStatus.good,
          );

          _currentWordStatuses[_activeWordIndex] = WordPronunciationStatus.good;
          _completedWordFeedbacks.add(feedback);
          _activeWordIndex++;
          _processedTokenCount += 2;
          _consecutiveMismatches = 0;

          if (_activeWordIndex >= currentAyah.normWords.length) {
            return _handleAyahCompletion();
          }

          lastUpdate = AlignmentUpdate(
            event: RealtimeAlignmentEvent.wordMatched,
            ayahNumber: currentAyah.verseNumber,
            activeWordIndex: _activeWordIndex,
            totalWordsInAyah: currentAyah.displayWords.length,
            matchedFeedback: feedback,
            spokenToken: joinedSpoken,
            similarity: joinedSim,
          );
          continue;
        }
      }

      // 4. Multi-word Lookahead check: did user skip current word(s) and recite an upcoming word?
      int matchedLookahead = -1;
      double bestLookaheadSim = 0.0;
      for (int look = 1; look <= 3 && _activeWordIndex + look < currentAyah.normWords.length; look++) {
        final futureTargetNorm = currentAyah.normWords[_activeWordIndex + look];
        final lookSim = _computeWordSimilarity(futureTargetNorm, currentSpokenToken);
        if (lookSim >= 0.72) {
          matchedLookahead = look;
          bestLookaheadSim = lookSim;
          break;
        }
      }

      if (matchedLookahead != -1) {
        if (enableLiveHalting) {
          // In halting drill mode, trigger pause on the skipped word
          _consecutiveMismatches = 0;
          return _triggerMistake(
            displayWord: displayWord,
            targetNorm: targetNorm,
            spokenNorm: null,
            transWord: transWord,
            isSkipped: true,
          );
        } else {
          // In fluid follower mode: mark intermediate word(s) as skipped/practice without halting
          for (int skipIdx = 0; skipIdx < matchedLookahead; skipIdx++) {
            final skippedWordIdx = _activeWordIndex + skipIdx;
            final skippedDisplay = currentAyah.displayWords[skippedWordIdx];
            final skippedTarget = currentAyah.normWords[skippedWordIdx];
            final skippedTrans = skippedWordIdx < currentAyah.transliterationWords.length
                ? currentAyah.transliterationWords[skippedWordIdx]
                : '';

            _currentWordStatuses[skippedWordIdx] = WordPronunciationStatus.needsPractice;
            _totalMistakesCount++;
            _completedWordFeedbacks.add(VocalizedWordFeedback(
              arabicWord: skippedDisplay,
              spokenWord: null,
              transliteration: skippedTrans,
              score: 0.20,
              status: WordPronunciationStatus.needsPractice,
              makhrajTip: ArabicPronunciationMatcher.diagnoseWord(
                displayWord: skippedDisplay,
                targetNorm: skippedTarget,
                spokenNorm: null,
                status: WordPronunciationStatus.needsPractice,
              ).action,
              issueDescription: 'This word was skipped during recitation.',
              issueDescriptionBn: 'এই শব্দটি তেলাওয়াতের সময় বাদ পড়েছে।',
            ));
          }

          _activeWordIndex += matchedLookahead;
          final matchedDisplay = currentAyah.displayWords[_activeWordIndex];
          final matchedTarget = currentAyah.normWords[_activeWordIndex];
          final matchedTrans = _activeWordIndex < currentAyah.transliterationWords.length
              ? currentAyah.transliterationWords[_activeWordIndex]
              : '';
          final status = bestLookaheadSim >= 0.88
              ? WordPronunciationStatus.perfect
              : WordPronunciationStatus.good;

          final feedback = VocalizedWordFeedback(
            arabicWord: matchedDisplay,
            spokenWord: currentSpokenToken,
            transliteration: matchedTrans,
            score: bestLookaheadSim,
            status: status,
            makhrajTip: ArabicPronunciationMatcher.diagnoseWord(
              displayWord: matchedDisplay,
              targetNorm: matchedTarget,
              spokenNorm: currentSpokenToken,
              status: status,
            ).action,
          );

          _currentWordStatuses[_activeWordIndex] = status;
          _completedWordFeedbacks.add(feedback);
          _activeWordIndex++;
          _processedTokenCount++;
          _consecutiveMismatches = 0;

          if (_activeWordIndex >= currentAyah.normWords.length) {
            return _handleAyahCompletion();
          }

          lastUpdate = AlignmentUpdate(
            event: RealtimeAlignmentEvent.wordMatched,
            ayahNumber: currentAyah.verseNumber,
            activeWordIndex: _activeWordIndex,
            totalWordsInAyah: currentAyah.displayWords.length,
            matchedFeedback: feedback,
            spokenToken: currentSpokenToken,
            similarity: bestLookaheadSim,
          );
          continue;
        }
      }

      // 5. Resilient phrase buffering:
      // If this is an interim fragment or the speaker is mid-phrase, allow one non-matching
      // token before halting, unless token is a distinctly conflicting word (length >= 4 and sim < 0.40).
      final isDistinctWord = currentSpokenToken.length >= 4 && sim < 0.40;
      if (_consecutiveMismatches == 0 && !isDistinctWord && _processedTokenCount + 1 < spokenTokens.length) {
        _consecutiveMismatches++;
        _processedTokenCount++;
        continue;
      }

      // 6. Confirmed mistake handling
      if (enableLiveHalting) {
        _processedTokenCount++;
        _consecutiveMismatches = 0;
        return _triggerMistake(
          displayWord: displayWord,
          targetNorm: targetNorm,
          spokenNorm: currentSpokenToken,
          transWord: transWord,
          isSkipped: false,
        );
      } else {
        // Fluid mode: diagnose mistake, mark status, but advance without freezing the user!
        final diagnosis = ArabicPronunciationMatcher.diagnoseWord(
          displayWord: displayWord,
          targetNorm: targetNorm,
          spokenNorm: currentSpokenToken,
          status: WordPronunciationStatus.needsPractice,
        );

        final mistakeFeedback = VocalizedWordFeedback(
          arabicWord: displayWord,
          spokenWord: currentSpokenToken,
          transliteration: transWord,
          score: max(sim, 0.25),
          status: WordPronunciationStatus.needsPractice,
          makhrajTip: diagnosis.action,
          issueDescription: diagnosis.issue,
          issueDescriptionBn: diagnosis.issueBn,
          correctionAction: diagnosis.action,
          correctionActionBn: diagnosis.actionBn,
          problematicLetters: diagnosis.letters,
        );

        _currentWordStatuses[_activeWordIndex] = WordPronunciationStatus.needsPractice;
        _completedWordFeedbacks.add(mistakeFeedback);
        _totalMistakesCount++;
        _activeWordIndex++;
        _processedTokenCount++;
        _consecutiveMismatches = 0;

        if (_activeWordIndex >= currentAyah.normWords.length) {
          return _handleAyahCompletion();
        }

        lastUpdate = AlignmentUpdate(
          event: RealtimeAlignmentEvent.wordMatched,
          ayahNumber: currentAyah.verseNumber,
          activeWordIndex: _activeWordIndex,
          totalWordsInAyah: currentAyah.displayWords.length,
          matchedFeedback: mistakeFeedback,
          spokenToken: currentSpokenToken,
          similarity: sim,
        );
        continue;
      }
    }

    return lastUpdate;
  }

  /// Evaluates retry utterances specifically against the paused erroneous word.
  AlignmentUpdate _processRetry(List<String> spokenTokens) {
    if (_activeWordIndex >= currentAyah.normWords.length) {
      return _handleAyahCompletion();
    }

    final targetNorm = currentAyah.normWords[_activeWordIndex];
    final displayWord = currentAyah.displayWords[_activeWordIndex];
    final transWord = _activeWordIndex < currentAyah.transliterationWords.length
        ? currentAyah.transliterationWords[_activeWordIndex]
        : '';

    // Inspect the recent tokens from the retry attempt
    final startIndex = max(0, spokenTokens.length - 3);
    for (int i = spokenTokens.length - 1; i >= startIndex; i--) {
      final token = spokenTokens[i];
      final sim = _computeWordSimilarity(targetNorm, token);

      if (sim >= 0.65) {
        // Retry Successful!
        final status = sim >= 0.88
            ? WordPronunciationStatus.perfect
            : WordPronunciationStatus.good;

        final feedback = VocalizedWordFeedback(
          arabicWord: displayWord,
          spokenWord: token,
          transliteration: transWord,
          score: sim,
          status: status,
          makhrajTip: ArabicPronunciationMatcher.diagnoseWord(
            displayWord: displayWord,
            targetNorm: targetNorm,
            spokenNorm: token,
            status: status,
          ).action,
        );

        _currentWordStatuses[_activeWordIndex] = status;
        _completedWordFeedbacks.add(feedback);
        _activeWordIndex++;
        _isPausedOnMistake = false;
        _activeMistake = null;
        _consecutiveMismatches = 0;
        _processedTokenCount = spokenTokens.length;

        if (_activeWordIndex >= currentAyah.normWords.length) {
          return _handleAyahCompletion();
        }

        return AlignmentUpdate(
          event: RealtimeAlignmentEvent.mistakeResolved,
          ayahNumber: currentAyah.verseNumber,
          activeWordIndex: _activeWordIndex,
          totalWordsInAyah: currentAyah.displayWords.length,
          matchedFeedback: feedback,
          spokenToken: token,
          similarity: sim,
        );
      }
    }

    return AlignmentUpdate(
      event: RealtimeAlignmentEvent.noChange,
      ayahNumber: currentAyah.verseNumber,
      activeWordIndex: _activeWordIndex,
      totalWordsInAyah: currentAyah.displayWords.length,
    );
  }

  /// Pauses real-time recitation, records the mistake, and produces detailed diagnostic feedback.
  AlignmentUpdate _triggerMistake({
    required String displayWord,
    required String targetNorm,
    required String? spokenNorm,
    required String transWord,
    required bool isSkipped,
  }) {
    _isPausedOnMistake = true;
    _totalMistakesCount++;

    final diagnosis = ArabicPronunciationMatcher.diagnoseWord(
      displayWord: displayWord,
      targetNorm: targetNorm,
      spokenNorm: spokenNorm,
      status: WordPronunciationStatus.needsPractice,
    );

    final mistakeFeedback = VocalizedWordFeedback(
      arabicWord: displayWord,
      spokenWord: spokenNorm,
      transliteration: transWord,
      score: 0.25,
      status: WordPronunciationStatus.needsPractice,
      makhrajTip: diagnosis.action,
      issueDescription: isSkipped
          ? 'This word was skipped during recitation.'
          : diagnosis.issue,
      issueDescriptionBn: isSkipped
          ? 'এই শব্দটি তেলাওয়াতের সময় বাদ পড়েছে।'
          : diagnosis.issueBn,
      correctionAction: diagnosis.action,
      correctionActionBn: diagnosis.actionBn,
      problematicLetters: diagnosis.letters,
    );

    _currentWordStatuses[_activeWordIndex] = WordPronunciationStatus.needsPractice;
    _activeMistake = mistakeFeedback;

    return AlignmentUpdate(
      event: RealtimeAlignmentEvent.mistakeDetected,
      ayahNumber: currentAyah.verseNumber,
      activeWordIndex: _activeWordIndex,
      totalWordsInAyah: currentAyah.displayWords.length,
      mistakeFeedback: mistakeFeedback,
      spokenToken: spokenNorm,
    );
  }

  /// Manually skips the current erroneous word (e.g. user taps "Skip Word" or "Continue Anyway").
  AlignmentUpdate skipActiveWord() {
    if (_activeWordIndex >= currentAyah.normWords.length) {
      return _handleAyahCompletion();
    }

    final displayWord = currentAyah.displayWords[_activeWordIndex];
    final transWord = _activeWordIndex < currentAyah.transliterationWords.length
        ? currentAyah.transliterationWords[_activeWordIndex]
        : '';

    final feedback = VocalizedWordFeedback(
      arabicWord: displayWord,
      spokenWord: null,
      transliteration: transWord,
      score: 0.20,
      status: WordPronunciationStatus.needsPractice,
      issueDescription: 'Skipped by reciter.',
      issueDescriptionBn: 'তেলাওয়াতকারী কর্তৃক বাদ দেওয়া হয়েছে।',
      correctionAction: 'Review and listen to the recitation before the next attempt.',
      correctionActionBn: 'পরবর্তী চেষ্টার পূর্বে তেলাওয়াতটি মনোযোগ দিয়ে শুনুন ও অনুশীলন করুন।',
    );

    _currentWordStatuses[_activeWordIndex] = WordPronunciationStatus.needsPractice;
    _completedWordFeedbacks.add(feedback);
    _activeWordIndex++;
    _isPausedOnMistake = false;
    _activeMistake = null;

    if (_activeWordIndex >= currentAyah.normWords.length) {
      return _handleAyahCompletion();
    }

    return AlignmentUpdate(
      event: RealtimeAlignmentEvent.wordSkipped,
      ayahNumber: currentAyah.verseNumber,
      activeWordIndex: _activeWordIndex,
      totalWordsInAyah: currentAyah.displayWords.length,
      matchedFeedback: feedback,
    );
  }

  /// Handles completion of an Ayah. In Full Surah mode, automatically prepares for the next Ayah.
  AlignmentUpdate _handleAyahCompletion() {
    _completedAyahsCount++;

    if (mode == RecitationMode.fullSurah && hasMoreAyahs) {
      return AlignmentUpdate(
        event: RealtimeAlignmentEvent.ayahCompleted,
        ayahNumber: currentAyah.verseNumber,
        activeWordIndex: currentAyah.displayWords.length,
        totalWordsInAyah: currentAyah.displayWords.length,
        isAyahFinished: true,
        isSurahFinished: false,
      );
    } else {
      final isSurah = mode == RecitationMode.fullSurah;
      return AlignmentUpdate(
        event: isSurah
            ? RealtimeAlignmentEvent.surahCompleted
            : RealtimeAlignmentEvent.ayahCompleted,
        ayahNumber: currentAyah.verseNumber,
        activeWordIndex: currentAyah.displayWords.length,
        totalWordsInAyah: currentAyah.displayWords.length,
        isAyahFinished: true,
        isSurahFinished: isSurah,
      );
    }
  }

  /// Advances to the next Ayah in Full Surah mode.
  bool advanceToNextAyah() {
    if (!hasMoreAyahs) return false;
    _currentAyahIndex++;
    _initCurrentAyah(preserveTokenCount: true);
    return true;
  }

  /// Computes phonetic similarity with clitic and Quranic prefix awareness.
  double _computeWordSimilarity(String target, String spoken) {
    if (target == spoken) return 1.0;
    if (target.isEmpty || spoken.isEmpty) return 0.0;

    double baseSim = ArabicPronunciationMatcher.similarity(target, spoken);
    if (baseSim >= 0.70) return baseSim;

    // Check common Arabic clitic prefixes: Waw (و), Fa (ف), Ba (ب), Alif-Lam (ال)
    final prefixes = ['و', 'ف', 'ب', 'ال', 'وال', 'فال', 'بال', 'ل'];
    for (final p in prefixes) {
      if (target.startsWith(p) && !spoken.startsWith(p)) {
        final strippedTarget = target.substring(p.length);
        final sim = ArabicPronunciationMatcher.similarity(strippedTarget, spoken);
        if (sim > baseSim) baseSim = max(baseSim, sim * 0.95);
      } else if (spoken.startsWith(p) && !target.startsWith(p)) {
        final strippedSpoken = spoken.substring(p.length);
        final sim = ArabicPronunciationMatcher.similarity(target, strippedSpoken);
        if (sim > baseSim) baseSim = max(baseSim, sim * 0.95);
      }
    }

    return baseSim;
  }
}
