import 'package:just_audio/just_audio.dart';

import '../services/neural_tts_service.dart';

/// Helper to generate high-fidelity, spoken neural audio streams for translations in Bengali or English.
class TranslationSpeechHelper {
  static const int maxChunkLength = 150;

  /// Cleans and sanitizes translation text for speech synthesis.
  static String sanitizeText(String rawText) {
    return NeuralTtsService.sanitizeText(rawText);
  }

  /// Splits long text into speakable chunks respecting punctuation and sentence boundaries.
  static List<String> splitIntoSpeakableChunks(String text, {int maxLen = maxChunkLength}) {
    final clean = sanitizeText(text);
    if (clean.isEmpty) return [];
    if (clean.length <= maxLen) return [clean];

    final chunks = <String>[];
    final sentencePattern = RegExp(r'([^।\.!\?;\n]+[।\.!\?;\n]+)');
    final matches = sentencePattern.allMatches(clean);

    final clauses = <String>[];
    int lastIndex = 0;

    for (final m in matches) {
      if (m.start > lastIndex) {
        final gap = clean.substring(lastIndex, m.start).trim();
        if (gap.isNotEmpty) clauses.add(gap);
      }
      clauses.add(m.group(0)!.trim());
      lastIndex = m.end;
    }
    if (lastIndex < clean.length) {
      final remainder = clean.substring(lastIndex).trim();
      if (remainder.isNotEmpty) clauses.add(remainder);
    }

    if (clauses.isEmpty) {
      clauses.add(clean);
    }

    String currentChunk = '';
    for (final clause in clauses) {
      if (clause.length > maxLen) {
        final words = clause.split(' ');
        for (final word in words) {
          if (currentChunk.isEmpty) {
            currentChunk = word;
          } else if ((currentChunk.length + 1 + word.length) <= maxLen) {
            currentChunk += ' $word';
          } else {
            chunks.add(currentChunk.trim());
            currentChunk = word;
          }
        }
      } else {
        if (currentChunk.isEmpty) {
          currentChunk = clause;
        } else if ((currentChunk.length + 1 + clause.length) <= maxLen) {
          currentChunk += ' $clause';
        } else {
          chunks.add(currentChunk.trim());
          currentChunk = clause;
        }
      }
    }

    if (currentChunk.trim().isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    return chunks.isNotEmpty ? chunks : [clean];
  }

  /// Generates a speech URL for fallback or test compatibility.
  static String getSpeechUrl(String text, String langCode) {
    final encoded = Uri.encodeComponent(text.trim());
    return 'https://translate.google.com/translate_tts?ie=UTF-8&q=$encoded&tl=$langCode&client=tw-ob';
  }

  /// Creates a ready-to-play [AudioSource] powered by Microsoft Edge / Azure Neural TTS
  /// with automatic local disk caching for instantaneous subsequent plays.
  static Future<AudioSource> createTranslationAudioSource(
    String text, {
    required bool isBengali,
    TtsVoiceGender gender = TtsVoiceGender.female,
    double speed = 1.0,
  }) async {
    final langCode = isBengali ? 'bn' : 'en';
    try {
      return await NeuralTtsService.instance.getAudioSource(
        text: text,
        langCode: langCode,
        gender: gender,
        speed: speed,
      );
    } catch (e) {
      // Fallback to streaming URI if offline synthesis fails
      final url = getSpeechUrl(sanitizeText(text), langCode);
      return AudioSource.uri(Uri.parse(url));
    }
  }

  /// Direct path retrieval for offline-cached audio files.
  static Future<String> getAudioFilePath(
    String text, {
    required bool isBengali,
    TtsVoiceGender gender = TtsVoiceGender.female,
    double speed = 1.0,
  }) async {
    final langCode = isBengali ? 'bn' : 'en';
    return await NeuralTtsService.instance.getOrSynthesizeAudio(
      text: text,
      langCode: langCode,
      gender: gender,
      speed: speed,
    );
  }
}
