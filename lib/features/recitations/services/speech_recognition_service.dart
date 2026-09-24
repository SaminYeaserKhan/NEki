import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// On-device native speech recognition service (`speech_to_text`).
/// Used for real-time live word streaming and 100% offline fallback.
class SpeechRecognitionService {
  SpeechRecognitionService._();

  static final SpeechRecognitionService instance = SpeechRecognitionService._();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  String _activeArabicLocale = 'ar-SA';
  String _lastRecognizedWords = '';

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isInitialized && _speechToText.isAvailable;
  String get lastRecognizedWords => _lastRecognizedWords;

  /// Initializes the native speech recognition engine and discovers available Arabic locales.
  Future<bool> initialize({
    Function(String status)? onStatus,
    Function(SpeechRecognitionError error)? onError,
  }) async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onStatus: onStatus,
        onError: onError,
      );

      if (_isInitialized) {
        // Query system locales to select the best available Arabic locale
        final locales = await _speechToText.locales();
        final arabicLocales = locales.where((l) => l.localeId.startsWith('ar')).toList();

        if (arabicLocales.isNotEmpty) {
          // Prefer Saudi Arabic (standard Quranic dialect)
          final saudi = arabicLocales.firstWhere(
            (l) => l.localeId == 'ar-SA' || l.localeId == 'ar_SA',
            orElse: () => arabicLocales.first,
          );
          _activeArabicLocale = saudi.localeId;
        }
      }

      return _isInitialized;
    } catch (_) {
      _isInitialized = false;
      return false;
    }
  }

  /// Begins listening for Arabic speech.
  Future<bool> startListening({
    required Function(String interimWords) onResult,
    Function(double soundLevel)? onSoundLevel,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return false;
    }

    _lastRecognizedWords = '';

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastRecognizedWords = result.recognizedWords;
          onResult(result.recognizedWords);
        },
        onSoundLevelChange: onSoundLevel != null
            ? (level) {
                // Normalize level (-30 to 10 or 0 to 100) to 0.0 - 1.0
                final normalized = ((level + 10) / 30).clamp(0.0, 1.0);
                onSoundLevel(normalized);
              }
            : null,
        listenOptions: SpeechListenOptions(
          localeId: _activeArabicLocale,
          listenMode: ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops native speech recognition and returns the final recognized words.
  Future<String> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      return _lastRecognizedWords;
    } catch (_) {
      return _lastRecognizedWords;
    }
  }

  /// Cancels listening and discards results.
  Future<void> cancel() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
      _lastRecognizedWords = '';
    } catch (_) {}
  }
}
