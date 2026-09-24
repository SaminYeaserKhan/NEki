import 'arabic_pronunciation_matcher.dart';
import 'whisper_speech_service.dart';

export 'arabic_pronunciation_matcher.dart';

/// Central pronunciation service coordinating audio recording, transcription,
/// and Arabic linguistic phonetic matching across Quran, Dua, and Hadith.
class PronunciationService {
  PronunciationService._();

  static final PronunciationService instance = PronunciationService._();

  /// Evaluates an Arabic recitation given the authentic target text and the user's spoken Arabic text.
  PronunciationResult evaluateRecitation({
    required String arabicText,
    String? transliteration,
    String? spokenArabic,
    Duration? recordedDuration,
    bool isOffline = false,
  }) {
    return ArabicPronunciationMatcher.instance.evaluate(
      targetArabic: arabicText,
      spokenArabic: spokenArabic ?? arabicText,
      transliteration: transliteration,
      recordedDuration: recordedDuration,
      isOffline: isOffline,
    );
  }

  /// Evaluates a recorded audio file.
  /// First attempts transcription with Groq Whisper Large-v3 with target scripture prompt conditioning.
  /// If Whisper is unconfigured or unavailable, uses the fallback spoken text from on-device speech recognition.
  Future<PronunciationResult> evaluateAudioFile({
    required String audioPath,
    required String targetArabic,
    String? fallbackSpokenText,
    String? transliteration,
    Duration? recordedDuration,
  }) async {
    // 1. Try Groq Whisper Large-v3 (Wispr Flow accuracy)
    final whisperText = await WhisperSpeechService.instance.transcribeWithWhisper(
      audioPath: audioPath,
      targetArabicPrompt: targetArabic,
    );

    if (whisperText != null && whisperText.trim().isNotEmpty) {
      return evaluateRecitation(
        arabicText: targetArabic,
        transliteration: transliteration,
        spokenArabic: whisperText,
        recordedDuration: recordedDuration,
        isOffline: false,
      );
    }

    // 2. Fall back to on-device speech recognized text
    final spoken = fallbackSpokenText?.trim() ?? '';
    return evaluateRecitation(
      arabicText: targetArabic,
      transliteration: transliteration,
      spokenArabic: spoken,
      recordedDuration: recordedDuration,
      isOffline: true,
    );
  }
}
