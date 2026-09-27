import 'dart:math';

enum WordPronunciationStatus { perfect, good, needsPractice }

/// Detailed evaluation for an individual word in the recitation.
class VocalizedWordFeedback {
  final String arabicWord; // Authentic scripture word (with diacritics/tashkeel for display)
  final String? spokenWord; // What was recognized from the user's speech
  final String transliteration;
  final double score; // 0.0 to 1.0
  final WordPronunciationStatus status;
  final String? makhrajTip;
  final String? issueDescription; // Clear description of the exact discrepancy
  final String? issueDescriptionBn; // Clear description of discrepancy in Bengali
  final String? correctionAction; // Specific mouth, tongue, or throat technique to fix
  final String? correctionActionBn; // Specific technique to fix in Bengali
  final List<String> problematicLetters; // Specific letters that caused mismatch

  const VocalizedWordFeedback({
    required this.arabicWord,
    this.spokenWord,
    required this.transliteration,
    required this.score,
    required this.status,
    this.makhrajTip,
    this.issueDescription,
    this.issueDescriptionBn,
    this.correctionAction,
    this.correctionActionBn,
    this.problematicLetters = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocalizedWordFeedback &&
          runtimeType == other.runtimeType &&
          arabicWord == other.arabicWord &&
          spokenWord == other.spokenWord &&
          transliteration == other.transliteration &&
          status == other.status;

  @override
  int get hashCode =>
      arabicWord.hashCode ^
      (spokenWord?.hashCode ?? 0) ^
      transliteration.hashCode ^
      status.hashCode;
}

class TajweedRule {
  final String name;
  final String description;
  final String letters;

  const TajweedRule({
    required this.name,
    required this.description,
    required this.letters,
  });
}

/// Comprehensive result of a pronunciation evaluation.
class PronunciationResult {
  final int overallScore; // 0 - 100
  final String qualityTitle;
  final String feedbackSummary;
  final String spokenText; // Full recognized Arabic text
  final String expectedText; // Authentic scripture
  final List<VocalizedWordFeedback> words;
  final List<TajweedRule> detectedTajweedRules;
  final String encouragement;
  final String? encouragementBn;
  final bool isOfflineFallback;

  const PronunciationResult({
    required this.overallScore,
    required this.qualityTitle,
    required this.feedbackSummary,
    required this.spokenText,
    required this.expectedText,
    required this.words,
    required this.detectedTajweedRules,
    required this.encouragement,
    this.encouragementBn,
    this.isOfflineFallback = false,
  });
}

/// Linguistic and phonetic matching engine for Arabic Quran, Dua, and Hadith.
class ArabicPronunciationMatcher {
  ArabicPronunciationMatcher._();

  static final ArabicPronunciationMatcher instance =
      ArabicPronunciationMatcher._();

  /// Regular expression to match all Arabic Tashkeel / Harakat.
  static final RegExp _tashkeelRegex = RegExp(
    r'[\u064B-\u065F\u0670\u0656-\u065E\u0610-\u061A\u08F0-\u08FE]',
  );

  /// Regular expression to match Quranic Waqf symbols, stop signs, and ornamentation.
  static final RegExp _quranicMarksRegex = RegExp(
    r'[\u06D6-\u06ED\u0600-\u060F\uFD3E\uFD3F\u06DD\u06DE\u06DF\u06E0\u06E1\u06E2\u06E3\u06E4\u06E5\u06E6\u06E7\u06E8\u06E9\u06EA\u06EB\u06EC\u06ED]',
  );

  /// Strips diacritics, Quranic stop marks, numbers, and normalizes Arabic orthography.
  static String normalizeArabic(String text) {
    if (text.isEmpty) return '';

    var clean = text
        // Replace Dagger Alif (\u0670) with standard Alif (\u0627)
        .replaceAll('\u0670', 'ا')
        // Remove remaining Tashkeel / Harakat
        .replaceAll(_tashkeelRegex, '')
        // Remove Quranic stops and annotations
        .replaceAll(_quranicMarksRegex, '')
        // Remove Tatweel / Kashida
        .replaceAll('\u0640', '')
        // Remove verse end signs, brackets, quotes, punctuation
        .replaceAll(RegExp(r"""[0-9٠-٩\(\)\[\]\{\}«»"\'.,;:!؟\-_/\\~*]"""), ' ')
        .trim();

    // Orthographic Normalization:
    // 1. Normalize all forms of Alif (أ, إ, آ, ٱ) -> ا
    clean = clean.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // 2. Normalize Alif Maqsura (ى) -> ي
    clean = clean.replaceAll('ى', 'ي');

    // 3. Normalize Ta Marbuta (ة) -> ه
    clean = clean.replaceAll('ة', 'ه');

    // 4. Normalize common words where modern Arabic drops medial Alif or adds it
    clean = clean.replaceAll('الرحمان', 'الرحمن');
    clean = clean.replaceAll('باسم', 'بسم');
    clean = clean.replaceAll('بسمالله', 'بسم الله');
    clean = clean.replaceAll('هاذا', 'هذا');
    clean = clean.replaceAll('ذالك', 'ذلك');
    clean = clean.replaceAll('لاكن', 'لكن');

    // Collapse multiple spaces into one
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    return clean;
  }

  /// Calculates Levenshtein distance between two Arabic strings.
  static int levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final aChars = a.runes.toList();
    final bChars = b.runes.toList();

    List<int> previousRow = List<int>.generate(bChars.length + 1, (i) => i);
    List<int> currentRow = List<int>.filled(bChars.length + 1, 0);

    for (int i = 0; i < aChars.length; i++) {
      currentRow[0] = i + 1;
      for (int j = 0; j < bChars.length; j++) {
        final cost = aChars[i] == bChars[j] ? 0 : 1;
        currentRow[j + 1] = min(
          currentRow[j] + 1, // insertion
          min(
            previousRow[j + 1] + 1, // deletion
            previousRow[j] + cost, // substitution
          ),
        );
      }
      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[bChars.length];
  }

  /// Deduplicates repeated consecutive spoken phrases or single word stutters.
  static String deduplicateSpokenText(String text) {
    if (text.trim().isEmpty) return text.trim();
    final rawWords = text
        .replaceAll(RegExp(r"""[.,;:!؟\"'«»]"""), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (rawWords.length <= 1) return text.trim();

    final normTokens = rawWords.map(normalizeArabic).toList();

    // 1. Check for whole sentence repetition (e.g. repeated ayah attempt)
    final mid = rawWords.length ~/ 2;
    for (int offset = -1; offset <= 1; offset++) {
      final split = mid + offset;
      if (split >= 2 && (rawWords.length - split) >= 2) {
        final firstHalf = normTokens.sublist(0, split).join(' ');
        final secondHalf = normTokens.sublist(split).join(' ');
        if (similarity(firstHalf, secondHalf) >= 0.70) {
          // User repeated the entire verse; retain the latest attempt
          return rawWords.sublist(split).join(' ');
        }
      }
    }

    // 2. Check for local consecutive multi-word phrase repetitions (lengths 2 to 6)
    var workingWords = List<String>.from(rawWords);
    var workingNorms = List<String>.from(normTokens);

    bool foundPhraseRepeat = true;
    while (foundPhraseRepeat) {
      foundPhraseRepeat = false;
      for (int len = min(6, workingWords.length ~/ 2); len >= 2; len--) {
        for (int i = 0; i <= workingWords.length - 2 * len; i++) {
          final phrase1 = workingNorms.sublist(i, i + len).join(' ');
          final phrase2 = workingNorms.sublist(i + len, i + 2 * len).join(' ');
          if (similarity(phrase1, phrase2) >= 0.75) {
            // Remove the first repeated phrase
            workingWords.removeRange(i, i + len);
            workingNorms.removeRange(i, i + len);
            foundPhraseRepeat = true;
            break;
          }
        }
        if (foundPhraseRepeat) break;
      }
    }

    // 3. Remove consecutive duplicate single words (e.g. "بسم بسم الله" -> "بسم الله")
    final deduplicated = <String>[];
    for (int i = 0; i < workingWords.length; i++) {
      if (deduplicated.isEmpty ||
          normalizeArabic(deduplicated.last) != workingNorms[i]) {
        deduplicated.add(workingWords[i]);
      }
    }
    return deduplicated.join(' ');
  }

  /// Calculates similarity ratio (0.0 to 1.0) between two words.
  /// Seamlessly bridges Uthmanic and Modern Imla'i spelling variations (e.g. medial Alif).
  static double similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // Check Uthmanic vs Modern Imla'i medial Alif equivalence
    if (a.replaceAll('ا', '') == b.replaceAll('ا', '')) {
      return 1.0;
    }

    final maxLen = max(a.length, b.length);
    final dist = levenshteinDistance(a, b);
    return (maxLen - dist) / maxLen;
  }

  /// Evaluates the user's spoken Arabic recitation against the authentic Arabic text.
  PronunciationResult evaluate({
    required String targetArabic,
    required String spokenArabic,
    String? transliteration,
    Duration? recordedDuration,
    bool isOffline = false,
  }) {
    // Deduplicate any repeated verse attempts or word stutters from ASR
    final cleanSpokenArabic = deduplicateSpokenText(spokenArabic);

    // 1. Extract target words preserving original diacritics for on-screen display
    final targetDisplayWords = targetArabic
        .replaceAll(RegExp(r"""[0-9٠-٩\(\)\[\]«»"\'.,;:!؟]"""), ' ')
        .replaceAll(_quranicMarksRegex, ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // 2. Transliteration words (if available)
    final transWords = transliteration != null && transliteration.isNotEmpty
        ? transliteration
            .replaceAll(RegExp(r'[0-9\(\).,;:!?]'), '')
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList()
        : <String>[];

    // 3. Normalize both target and spoken sequences for linguistic comparison
    final targetNormWords = targetDisplayWords.map(normalizeArabic).toList();
    final spokenNormWords = cleanSpokenArabic
        .split(RegExp(r'\s+'))
        .map(normalizeArabic)
        .where((w) => w.isNotEmpty)
        .toList();

    // 4. Handle edge case: empty or silence
    if (spokenNormWords.isEmpty) {
      final words = <VocalizedWordFeedback>[];
      for (int i = 0; i < targetDisplayWords.length; i++) {
        final trans = i < transWords.length ? transWords[i] : '';
        final diagnosis = diagnoseWord(
          displayWord: targetDisplayWords[i],
          targetNorm: targetNormWords[i],
          spokenNorm: null,
          status: WordPronunciationStatus.needsPractice,
        );

        words.add(VocalizedWordFeedback(
          arabicWord: targetDisplayWords[i],
          spokenWord: null,
          transliteration: trans,
          score: 0.0,
          status: WordPronunciationStatus.needsPractice,
          makhrajTip: diagnosis.action,
          issueDescription: diagnosis.issue,
          correctionAction: diagnosis.action,
          problematicLetters: diagnosis.letters,
        ));
      }

      return PronunciationResult(
        overallScore: 0,
        qualityTitle: 'No Speech Detected',
        feedbackSummary: 'We could not detect clear Arabic recitation. Please ensure microphone permissions are granted and speak closer to the microphone.',
        spokenText: spokenArabic,
        expectedText: targetArabic,
        words: words,
        detectedTajweedRules: _detectTajweedRules(targetArabic),
        encouragement: 'The Prophet (pbuh) said: "The one who recites and stumbles in it, finding it difficult, will have a double reward." (Sahih al-Bukhari)',
        encouragementBn: 'রাসূলুল্লাহ (সা.) বলেছেন: "যে ব্যক্তি কষ্ট করে তোতলাতে তোতলাতে কুরআন পাঠ করে, তার জন্য দ্বিগুণ সওয়াব রয়েছে।" (সহীহ বুখারী)',
        isOfflineFallback: isOffline,
      );
    }

    // 5. Sequence Alignment using Dynamic Alignment
    final feedbackWords = <VocalizedWordFeedback>[];
    double totalScoreSum = 0;

    int spokenIndex = 0;

    for (int i = 0; i < targetDisplayWords.length; i++) {
      final displayWord = targetDisplayWords[i];
      final targetNorm = targetNormWords[i];
      final trans = i < transWords.length ? transWords[i] : '';

      String? matchedSpoken;
      double wordScore = 0.0;
      WordPronunciationStatus status;

      // Lookahead window in spoken words (up to 3 words ahead to handle pauses or skipped words)
      int bestMatchIdx = -1;
      double bestSim = 0.0;

      final lookaheadLimit = min(spokenIndex + 4, spokenNormWords.length);
      for (int s = spokenIndex; s < lookaheadLimit; s++) {
        final currentSpoken = spokenNormWords[s];
        final sim = similarity(targetNorm, currentSpoken);
        if (sim > bestSim) {
          bestSim = sim;
          bestMatchIdx = s;
        }
        if (sim == 1.0) break; // Exact match found
      }

      if (bestMatchIdx != -1 && bestSim >= 0.65) {
        matchedSpoken = spokenNormWords[bestMatchIdx];
        spokenIndex = bestMatchIdx + 1; // Advance spoken pointer

        if (bestSim >= 0.90) {
          status = WordPronunciationStatus.perfect;
          wordScore = 0.95 + (bestSim * 0.05); // 0.95 to 1.0
        } else {
          status = WordPronunciationStatus.good;
          wordScore = 0.75 + (bestSim * 0.15); // 0.75 to 0.88
        }
      } else {
        // Word missed or pronounced with significant discrepancy
        status = WordPronunciationStatus.needsPractice;
        wordScore = 0.25;
        // If there's still a spoken word, preview it without advancing pointer too far
        if (spokenIndex < spokenNormWords.length) {
          matchedSpoken = spokenNormWords[spokenIndex];
        }
      }

      totalScoreSum += wordScore;

      final diagnosis = diagnoseWord(
        displayWord: displayWord,
        targetNorm: targetNorm,
        spokenNorm: matchedSpoken,
        status: status,
      );

      feedbackWords.add(VocalizedWordFeedback(
        arabicWord: displayWord,
        spokenWord: matchedSpoken,
        transliteration: trans,
        score: wordScore,
        status: status,
        makhrajTip: diagnosis.action,
        issueDescription: diagnosis.issue,
        issueDescriptionBn: diagnosis.issueBn,
        correctionAction: diagnosis.action,
        correctionActionBn: diagnosis.actionBn,
        problematicLetters: diagnosis.letters,
      ));
    }

    // 6. Calculate Final Overall Score
    final avgScore = targetDisplayWords.isNotEmpty
        ? (totalScoreSum / targetDisplayWords.length)
        : 0.0;
    final int finalScore = (avgScore * 100).round().clamp(0, 100);

    String qualityTitle;
    String feedbackSummary;

    if (finalScore >= 90) {
      qualityTitle = 'Mumtaz! (Excellent)';
      feedbackSummary = 'Outstanding recitation! Accurate articulation of letters and steady rhythm.';
    } else if (finalScore >= 80) {
      qualityTitle = 'Jayyid Jiddan! (Very Good)';
      feedbackSummary = 'Very clear pronunciation with steady pacing. Pay attention to highlighted words.';
    } else if (finalScore >= 65) {
      qualityTitle = 'Jayyid (Good)';
      feedbackSummary = 'Good effort! Focus on distinguishing heavier letters and pausing at natural waqf.';
    } else {
      qualityTitle = 'Keep Practicing (Ijtihad)';
      feedbackSummary = 'Every attempt is rewarded! Tap on the red words to see their tips, then listen to the recitation.';
    }

    return PronunciationResult(
      overallScore: finalScore,
      qualityTitle: qualityTitle,
      feedbackSummary: feedbackSummary,
      spokenText: cleanSpokenArabic,
      expectedText: targetArabic,
      words: feedbackWords,
      detectedTajweedRules: _detectTajweedRules(targetArabic),
      encouragement: _getRandomEncouragement(targetArabic.hashCode),
      encouragementBn: _getRandomEncouragementBn(targetArabic.hashCode),
      isOfflineFallback: isOffline,
    );
  }

  static String _getMakhrajTipForWord(String word, {required bool isPerfect}) {
    if (RegExp(r'[قطبجد]').hasMatch(word)) {
      return isPerfect
          ? 'Clear Qalqalah (echo) bounce articulated accurately.'
          : 'Notice the Qalqalah letter (ق, ط, ب, ج, د); bounce the sound cleanly when on Sukun.';
    }
    if (RegExp(r'[خصضغطقظ]').hasMatch(word)) {
      return isPerfect
          ? 'Proper Isti\'la (full-mouth) tone with deep resonance.'
          : 'Pronounce with more depth from the back of the throat (Isti\'la letter).';
    }
    if (word.contains('ّ')) {
      return isPerfect
          ? 'Shaddah held with correct emphasis and Ghunnah.'
          : 'Hold the double-letter (Shaddah) slightly longer with nasal resonance.';
    }
    if (word.contains('ع') || word.contains('ح')) {
      return isPerfect
          ? 'Precise throat (Halq) articulation.'
          : 'Articulate from the middle of the throat for Ayn (ع) and Haa (ح).';
    }
    return isPerfect
        ? 'Accurate articulation and clear letter boundaries.'
        : 'Good effort. Maintain steady vowel elongation.';
  }

  static String _getMakhrajTipForWordBn(String word, {required bool isPerfect}) {
    if (RegExp(r'[قطبجد]').hasMatch(word)) {
      return isPerfect
          ? 'কলকলাহর প্রতিধ্বনি স্পষ্টভাবে উচ্চারিত হয়েছে।'
          : 'কলকলাহর হরফে (ق, ط, ব, ج, د) সাকিন অবস্থায় স্পষ্ট ধাক্কা দিয়ে পড়ুন।';
    }
    if (RegExp(r'[خصضغطقظ]').hasMatch(word)) {
      return isPerfect
          ? 'ইসতিলাহর ভারী ও গম্ভীর ধ্বনি সুন্দরভাবে প্রকাশ পেয়েছে।'
          : 'মুখ ভরে গম্ভীর আওয়াজে ইসতিলাহর হরফ উচ্চারণ করুন।';
    }
    if (word.contains('ّ')) {
      return isPerfect
          ? 'তাশদীদের মাত্রা ও গুন্নাহ সঠিকভাবে আদায় হয়েছে।'
          : 'তাশদীদযুক্ত হরফে কিছুটা সময় দিয়ে নাসিকা ধ্বনি বজায় রাখুন।';
    }
    if (word.contains('ع') || word.contains('ح')) {
      return isPerfect
          ? 'হলকের হরফ অত্যন্ত নিখুঁতভাবে উচ্চারিত হয়েছে।'
          : 'হলকের মধ্যভাগ থেকে আইন (ع) ও হা (ح) উচ্চারণ করুন।';
    }
    return isPerfect
        ? 'সঠিক মাখরাজ থেকে নিখুঁত ও সুস্পষ্ট উচ্চারণ।'
        : 'হরকত ও মাখরাজ নিয়ন্ত্রণে রেখে ধীরে ধীরে পাঠ করুন।';
  }

  static ({String? issue, String? issueBn, String? action, String? actionBn, List<String> letters}) diagnoseWord({
    required String displayWord,
    required String targetNorm,
    required String? spokenNorm,
    required WordPronunciationStatus status,
  }) {
    if (status == WordPronunciationStatus.perfect) {
      return (
        issue: null,
        issueBn: null,
        action: _getMakhrajTipForWord(displayWord, isPerfect: true),
        actionBn: _getMakhrajTipForWordBn(displayWord, isPerfect: true),
        letters: <String>[],
      );
    }

    if (spokenNorm == null || spokenNorm.isEmpty) {
      return (
        issue: 'This word was omitted, inaudible, or cut off during recitation.',
        issueBn: 'এই শব্দটি উচ্চারিত হয়নি, অস্পষ্ট ছিল অথবা বাদ পড়েছে।',
        action: 'Listen to the recitation, take a steady breath before this word, and recite each letter clearly.',
        actionBn: 'তেলাওয়াতটি শুনুন, এই শব্দের পূর্বে স্বাভাবিক শ্বাস নিন এবং প্রতিটি হরফ স্পষ্ট উচ্চারণ করুন।',
        letters: <String>[],
      );
    }

    final letters = <String>[];
    String? issue;
    String? issueBn;
    String? action;
    String? actionBn;

    // Emphatic / Heavy letters
    if (targetNorm.contains('ص') && !spokenNorm.contains('ص')) {
      letters.add('ص');
      issue = 'Soft Sin (س) was articulated instead of the heavy, emphatic Sad (ص).';
      issueBn = 'ভারী ও মোটা সোয়াদ (ص)-এর পরিবর্তে হালকা সিন (س) উচ্চারিত হয়েছে।';
      action = 'Keep the tongue tip behind lower front teeth, but elevate the back of your tongue towards the soft palate for a full, heavy sound.';
      actionBn = 'জিহ্বার ডগা নিচের দাঁতের গোড়ায় রাখুন এবং পেছনের অংশ নরম তালুর দিকে তুলে ভারী আওয়াজ করুন।';
    } else if (targetNorm.contains('ط') && !spokenNorm.contains('ط')) {
      letters.add('ط');
      issue = 'Light Taa (ت) was heard instead of the heavy, emphatic Taa (ط).';
      issueBn = 'মোটা হরফ ত্বোয়া (ط)-এর পরিবর্তে হালকা তা (ت) শোনা গেছে।';
      action = 'Raise the back of your tongue firmly against the roof of your mouth. Do not release a puff of breath.';
      actionBn = 'জিহ্বার পেছনের অংশ শক্তভাবে তালুর দিকে তুলুন এবং অতিরিক্ত বাতাস ছাড়া পরিহার করুন।';
    } else if (targetNorm.contains('ض') && !spokenNorm.contains('ض')) {
      letters.add('ض');
      issue = 'Dhad (ض) was pronounced like a light Dal (د) or Zay (ز).';
      issueBn = 'দোয়াদ (ض)-এর স্থানে হালকা দাল (د) বা যা (ز)-এর মতো শোনা গেছে।';
      action = 'Press one or both sides of your tongue against the upper back molars to produce the deep, elongated Dhad.';
      actionBn = 'জিহ্বার এক বা উভয় পার্শ্ব ওপরের মাড়ির দাঁতের গোড়ায় চেপে ধরে দোয়াদ উচ্চারণ করুন।';
    } else if (targetNorm.contains('ظ') && !spokenNorm.contains('ظ')) {
      letters.add('ظ');
      issue = 'Light Dhal (ذ) or Zay (ز) was heard instead of heavy Zhaa (ظ).';
      issueBn = 'ভারী যোয়া (ظ)-এর পরিবর্তে যাল (ذ) বা যা (ز) উচ্চারিত হয়েছে।';
      action = 'Place the tip of your tongue against the edges of the top teeth while elevating the back of your tongue.';
      actionBn = 'জিহ্বার আগা ওপরের সামনের দাঁতের প্রান্তের সাথে লাগান এবং পেছনের অংশ উঁচিয়ে ভারী শব্দ করুন।';
    } else if (targetNorm.contains('ق') && !spokenNorm.contains('ق')) {
      letters.add('ق');
      issue = 'Light Kaf (ك) was heard instead of deep throat Qaf (ق).';
      issueBn = 'হলকের গোড়ার ক্বাফ (ق)-এর স্থানে মুখের সামনের কাফ (ك) শোনা গেছে।';
      action = 'Strike the deepest root of your tongue against the soft palate near the uvula. Avoid the English \'k\' sound.';
      actionBn = 'জিহ্বার গোড়া নরম তালুর সাথে লাগিয়ে গভীর থেকে ক্বাফ উচ্চারণ করুন।';
    } else if (targetNorm.contains('ع') && !spokenNorm.contains('ع')) {
      letters.add('ع');
      issue = 'Throat letter Ayn (ع) was softened into Alif/Hamza (أ) or dropped.';
      issueBn = 'হলকের মধ্যভাগের হরফ আইন (ع) নরম হয়ে হামযা/আলিফ (أ)-এর মতো হয়ে গেছে।';
      action = 'Squeeze the middle of your throat (epiglottis) cleanly to produce the distinct, resonant Ayn.';
      actionBn = 'হলকের মধ্যভাগ সামান্য চেপে পরিষ্কার ও সুনির্দিষ্ট আইন উচ্চারণ করুন।';
    } else if (targetNorm.contains('ح') && !spokenNorm.contains('ح')) {
      letters.add('ح');
      issue = 'Chest Haa (هـ) was heard instead of raspy throat Haa (ح).';
      issueBn = 'হলকের মধ্যভাগের হা (ح)-এর স্থানে বুকের গভীরের হা (هـ) শোনা গেছে।';
      action = 'Exhale a warm, sharp stream of breath from the middle of the throat, as if fogging a mirror.';
      actionBn = 'আয়নায় শ্বাস ফেলার মতো হলকের মধ্যভাগ থেকে উষ্ণ ও স্পষ্ট বাতাস বের করে হা উচ্চারণ করুন।';
    } else if (targetNorm.contains('خ') && !spokenNorm.contains('خ')) {
      letters.add('خ');
      issue = 'Khaa (خ) throat friction was missing.';
      issueBn = 'হলকের প্রথমভাগের খা (خ)-এর স্বাভাবিক ঘর্ষণ অনুপস্থিত ছিল।';
      action = 'Create a gentle rasping vibration at the top of the throat near the uvula.';
      actionBn = 'হলকের ওপরের অংশ থেকে হালকা ঘর্ষণের সাথে আওয়াজ বের করুন।';
    } else if (targetNorm.contains('غ') && !spokenNorm.contains('غ')) {
      letters.add('غ');
      issue = 'Ghayn (غ) resonance was unclear.';
      issueBn = 'হলকের প্রথমভাগের গ্বাইন (غ)-এর ধ্বনি অস্পষ্ট ছিল।';
      action = 'Articulate from the upper throat with a soft gargling sound, similar to the French \'r\'.';
      actionBn = 'গড়গড়া করার মতো কোমল শব্দে হলকের ওপরের অংশ থেকে গ্বাইন উচ্চারণ করুন।';
    } else if (targetNorm.contains('ث') && !spokenNorm.contains('ث')) {
      letters.add('ث');
      issue = 'Sin (س) was heard instead of interdental Thaa (ث).';
      issueBn = 'নরম হরফ ছা (ث)-এর পরিবর্তে শিষ দিয়ে সিন (س) উচ্চারিত হয়েছে।';
      action = 'Place the flat tip of your tongue gently between your front teeth (as in \'think\').';
      actionBn = 'জিহ্বার আগা আলতোভাবে সামনের দুই দাঁতের মাঝে রেখে নরম সুরে উচ্চারণ করুন।';
    } else if (targetNorm.contains('ذ') && !spokenNorm.contains('ذ')) {
      letters.add('ذ');
      issue = 'Zay (ز) was heard instead of interdental Dhal (ذ).';
      issueBn = 'নরম হরফ যাল (ذ)-এর পরিবর্তে কম্পিত যা (ز) হয়েছে।';
      action = 'Place the tip of your tongue on the edges of the top front teeth (as in \'this\').';
      actionBn = 'জিহ্বার আগা ওপরের সামনের দাঁতের পেটে বা কিনারে স্পর্শ করে নরমভাবে বলুন।';
    } else if (displayWord.contains('ّ')) {
      letters.add('ّ');
      issue = 'The doubled letter (Shaddah) duration was too brief.';
      issueBn = 'তাশদীদযুক্ত হরফের দৈর্ঘ্য খুব কম ছিল।';
      action = 'Hold the doubled consonant for two full beats before pronouncing the vowel to give it weight.';
      actionBn = 'পরবর্তী হরকত পড়ার আগে তাশদীদযুক্ত হরফে দুই মাত্রা সময় ধরে জোর দিন।';
    } else if (RegExp(r'[قطبجد]').hasMatch(displayWord) && status == WordPronunciationStatus.needsPractice) {
      final qLetter = RegExp(r'[قطبجد]').firstMatch(displayWord)?.group(0) ?? '';
      letters.add(qLetter);
      issue = 'Qalqalah (echo bounce) on $qLetter was omitted or incomplete.';
      issueBn = 'কলকলাহর হরফ $qLetter-এ প্রতিধ্বনি বা ধাক্কা অনুপস্থিত ছিল।';
      action = 'Release the consonant abruptly with a clean bounce without adding any extra vowel.';
      actionBn = 'সাকিন অবস্থায় হরফটি পড়ার সময় কোনো অতিরিক্ত স্বরবর্ণ না যুক্ত করে স্পষ্ট ধাক্কা দিয়ে পড়ুন।';
    } else {
      issue = status == WordPronunciationStatus.needsPractice
          ? 'Significant pronunciation divergence from the authentic scripture.'
          : 'Minor vowel or pacing variation detected.';
      issueBn = status == WordPronunciationStatus.needsPractice
          ? 'বিশুদ্ধ তিলাওয়াতের সাথে ধ্বনিগত গরমিল রয়েছে।'
          : 'স্বরবর্ণ বা উচ্চারণের গতিতে সামান্য ব্যতিক্রম হয়েছে।';
      action = 'Listen to the recitation audio and repeat this specific word slowly syllable by syllable.';
      actionBn = 'তেলাওয়াতটি মনোযোগ দিয়ে শুনুন এবং প্রতিটি অক্ষর আলাদা করে ধীরে ধীরে বলুন।';
    }

    return (
      issue: issue,
      issueBn: issueBn,
      action: action,
      actionBn: actionBn,
      letters: letters,
    );
  }

  static List<TajweedRule> _detectTajweedRules(String arabicText) {
    final rules = <TajweedRule>[];
    if (RegExp(r'[قطبجد]').hasMatch(arabicText)) {
      rules.add(const TajweedRule(
        name: 'Qalqalah (Echoing Bounce)',
        description: 'Vibrate or bounce the sound when stopping on: Qaf, Taa, Baa, Jeem, Daal.',
        letters: 'ق - ط - ب - ج - د',
      ));
    }
    if (arabicText.contains('ّ')) {
      rules.add(const TajweedRule(
        name: 'Ghunnah & Shaddah (Emphasis)',
        description: 'Produce a resonant sound from the nasal passage for 2 counts on Noon and Meem Mushaddad.',
        letters: 'نّ - مّ',
      ));
    }
    if (RegExp(r'[خصضغطقظ]').hasMatch(arabicText)) {
      rules.add(const TajweedRule(
        name: 'Isti\'la (Heavy / Full-Mouth Letters)',
        description: 'Elevate the back of the tongue to the roof of the mouth for deep resonance.',
        letters: 'خ - ص - ض - غ - ط - ق - ظ',
      ));
    }
    if (arabicText.contains('آ') || arabicText.contains('~') || arabicText.contains('ٰ')) {
      rules.add(const TajweedRule(
        name: 'Madd (Elongation)',
        description: 'Stretch the vowel sound for 2 to 6 counts depending on the sign.',
        letters: 'ا - و - ي',
      ));
    }
    return rules;
  }

  static String _getRandomEncouragement(int seed) {
    const encouragements = [
      'The Prophet (pbuh) said: "The one who is proficient in recitation will be with the noble, obedient angels." (Sahih Muslim)',
      'The Prophet (pbuh) said: "The one who recites and stumbles in it, finding it difficult, will have a double reward." (Sahih al-Bukhari)',
      'The Prophet (pbuh) said: "Dua (supplication) is the essence of worship." (Jami` at-Tirmidhi)',
      'Allah says: "Call upon Me; I will respond to you." (Surah Ghafir 40:60)',
      'The Prophet (pbuh) said: "The best among you are those who learn the Quran and teach it to others." (Sahih al-Bukhari)',
      'Allah says: "And recite with measured, rhythmic recitation." (Surah al-Muzzammil 73:4)',
    ];
    final rng = Random(seed);
    return encouragements[rng.nextInt(encouragements.length)];
  }

  static String _getRandomEncouragementBn(int seed) {
    const encouragementsBn = [
      'রাসূলুল্লাহ (সা.) বলেছেন: "যে ব্যক্তি কুরআনে দক্ষ, সে সম্মানিত পুণ্যবান ফেরেশতাদের সাথে থাকবে।" (সহীহ মুসলিম)',
      'রাসূলুল্লাহ (সা.) বলেছেন: "যে ব্যক্তি কষ্ট করে তোতলাতে তোতলাতে কুরআন পাঠ করে, তার জন্য দ্বিগুণ সওয়াব রয়েছে।" (সহীহ বুখারী)',
      'রাসূলুল্লাহ (সা.) বলেছেন: "দোয়াই হলো ইবাদতের মূল।" (জামে তিরমিযী)',
      'আল্লাহ তাআলা বলেন: "তোমরা আমাকে ডাকো, আমি তোমাদের ডাকে সাড়া দেব।" (সূরা গাফির ৪০:৬০)',
      'রাসূলুল্লাহ (সা.) বলেছেন: "তোমাদের মধ্যে সর্বোত্তম সেই ব্যক্তি, যে নিজে কুরআন শিখে এবং অন্যকে শিক্ষা দেয়।" (সহীহ বুখারী)',
      'আল্লাহ তাআলা বলেন: "আর কুরআন তিলাওয়াত করুন ধীরে ধীরে ও সুস্পষ্টভাবে।" (সূরা মুযযাম্মিল ৭৩:৪)',
    ];
    final rng = Random(seed);
    return encouragementsBn[rng.nextInt(encouragementsBn.length)];
  }
}
