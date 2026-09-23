import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:edge_tts/edge_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

enum TtsVoiceGender { female, male }

/// High-fidelity Neural Text-to-Speech service using Microsoft Azure / Edge Neural voices.
/// Provides near-human speech quality for English and Bengali with persistent local disk caching.
class NeuralTtsService {
  NeuralTtsService._();
  static final NeuralTtsService instance = NeuralTtsService._();

  Directory? _cacheDir;

  // Premium Voice Profiles
  static const String voiceBanglaFemale = 'bn-BD-NabanitaNeural';
  static const String voiceBanglaMale = 'bn-BD-PradeepNeural';

  static const String voiceEnglishFemale = 'en-US-JennyNeural';
  static const String voiceEnglishMale = 'en-US-GuyNeural';

  static const String voiceArabicMale = 'ar-SA-HamedNeural';
  static const String voiceArabicFemale = 'ar-SA-ZariyahNeural';

  /// Resolves the neural voice name for a given language and gender.
  static String resolveVoice({
    required String langCode,
    TtsVoiceGender gender = TtsVoiceGender.female,
  }) {
    final cleanLang = langCode.toLowerCase().trim();
    if (cleanLang == 'bn' || cleanLang == 'bengali' || cleanLang == 'bangla') {
      return gender == TtsVoiceGender.male ? voiceBanglaMale : voiceBanglaFemale;
    } else if (cleanLang == 'ar' || cleanLang == 'arabic') {
      return gender == TtsVoiceGender.female ? voiceArabicFemale : voiceArabicMale;
    } else {
      return gender == TtsVoiceGender.male ? voiceEnglishMale : voiceEnglishFemale;
    }
  }

  /// Initializes or returns the dedicated local cache directory for synthesized speech.
  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      return _cacheDir!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/tts_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Cleans and sanitizes input text for optimal pronunciation and prosody.
  static String sanitizeText(String rawText) {
    final isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(rawText);
    var processed = rawText
        .replaceAll(RegExp(r'<[^>]*>'), ' ') // Remove HTML tags
        .replaceAll(RegExp(r'\[[0-9]+\]'), ' '); // Remove footnote markers like [1]

    if (isArabic) {
      processed = processed.replaceAll(RegExp(r'[()]'), ' ');
    } else {
      processed = processed.replaceAll(RegExp(r'\([^\)]*\)'), ' ');
    }

    return processed
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '') // Zero width spaces
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse extra spaces
        .trim();
  }

  /// Computes a deterministic cache key based on voice, speed, and content.
  static String _computeCacheKey(String text, String voice, double speed) {
    final raw = '$voice|${speed.toStringAsFixed(2)}|$text';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Converts playback speed multiplier (e.g. 1.0, 1.25, 0.75) to Edge TTS rate string (e.g. '+0%', '+25%', '-25%').
  static String _formatRate(double speed) {
    final diff = ((speed - 1.0) * 100).round();
    if (diff > 0) return '+$diff%';
    if (diff < 0) return '$diff%';
    return '+0%';
  }

  /// Synthesizes neural audio or retrieves from disk cache, returning the local file path.
  Future<String> getOrSynthesizeAudio({
    required String text,
    required String langCode,
    TtsVoiceGender gender = TtsVoiceGender.female,
    double speed = 1.0,
  }) async {
    final cleanText = sanitizeText(text);
    if (cleanText.isEmpty) {
      throw ArgumentError('Cannot synthesize empty text');
    }

    final voice = resolveVoice(langCode: langCode, gender: gender);
    final cacheDir = await _getCacheDirectory();
    final cacheKey = _computeCacheKey(cleanText, voice, speed);
    final cacheFile = File('${cacheDir.path}/$cacheKey.mp3');

    // 1. Return cached audio file if present and valid
    if (await cacheFile.exists()) {
      final size = await cacheFile.length();
      if (size > 500) {
        return cacheFile.path;
      }
    }

    // 2. Synthesize using Microsoft Edge Neural TTS
    final rateStr = _formatRate(speed);
    final communicate = Communicate(
      text: cleanText,
      voice: voice,
      rate: rateStr,
    );

    final tempFile = File('${cacheDir.path}/tmp_$cacheKey.mp3');
    try {
      await communicate.save(tempFile.path);
      if (await tempFile.exists() && await tempFile.length() > 500) {
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        await tempFile.rename(cacheFile.path);
        return cacheFile.path;
      } else {
        throw Exception('TTS synthesis produced empty audio');
      }
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Convenience helper returning a ready-to-play [AudioSource] for just_audio.
  Future<AudioSource> getAudioSource({
    required String text,
    required String langCode,
    TtsVoiceGender gender = TtsVoiceGender.female,
    double speed = 1.0,
  }) async {
    final filePath = await getOrSynthesizeAudio(
      text: text,
      langCode: langCode,
      gender: gender,
      speed: speed,
    );
    return AudioSource.file(filePath);
  }
}
