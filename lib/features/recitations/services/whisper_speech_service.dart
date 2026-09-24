import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/config/api_keys.dart';

enum RecordingStartResult {
  success,
  permissionDenied,
  pluginNotLoaded,
  failure,
}

/// Service responsible for recording voice recitation and transcribing it
/// via Groq Whisper Large-v3 with target scripture prompt conditioning.
class WhisperSpeechService {
  WhisperSpeechService._();

  static final WhisperSpeechService instance = WhisperSpeechService._();

  AudioRecorder? _audioRecorder;
  String? _currentRecordingPath;
  StreamSubscription<Amplitude>? _amplitudeSub;

  /// Checks if microphone recording permission is granted.
  Future<bool> hasPermission() async {
    try {
      _audioRecorder ??= AudioRecorder();
      return await _audioRecorder!.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Starts audio recording with live amplitude monitoring.
  Future<RecordingStartResult> startRecording({
    Function(double normalizedSoundLevel)? onSoundLevel,
  }) async {
    try {
      _audioRecorder ??= AudioRecorder();

      final hasPerm = await _audioRecorder!.hasPermission();
      if (!hasPerm) return RecordingStartResult.permissionDenied;

      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${tempDir.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start live decibel amplitude monitoring
      if (onSoundLevel != null) {
        _amplitudeSub?.cancel();
        _amplitudeSub = _audioRecorder!
            .onAmplitudeChanged(const Duration(milliseconds: 100))
            .listen((amp) {
          final current = amp.current;
          final normalized = ((current + 60) / 60).clamp(0.0, 1.0);
          onSoundLevel(normalized);
        });
      }

      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      return RecordingStartResult.success;
    } catch (e) {
      if (e.toString().contains('MissingPluginException') ||
          e.toString().contains('No implementation found')) {
        return RecordingStartResult.pluginNotLoaded;
      }
      return RecordingStartResult.failure;
    }
  }

  /// Stops audio recording and cleans up amplitude subscription.
  Future<String?> stopRecording() async {
    try {
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;

      if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
        final path = await _audioRecorder!.stop();
        return path ?? _currentRecordingPath;
      }
      return _currentRecordingPath;
    } catch (_) {
      return null;
    }
  }

  /// Discards the current recording session and releases microphone.
  Future<void> cancel() async {
    try {
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;

      if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
        await _audioRecorder!.stop();
      }
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  /// Sends the recorded audio to Groq Whisper Large-v3 with the target scripture as prompt.
  /// Returns the recognized Arabic text, or null if unconfigured or error.
  Future<String?> transcribeWithWhisper({
    required String audioPath,
    required String targetArabicPrompt,
  }) async {
    final apiKey = await ApiKeys.getGroqApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final file = File(audioPath);
    if (!await file.exists()) return null;

    try {
      final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $apiKey';
      request.fields['model'] = 'whisper-large-v3';
      request.fields['language'] = 'ar';

      // Strict acoustic evaluation mode:
      // By default, prompt conditioning is disabled to prevent Whisper from auto-correcting
      // phonetic errors (such as pronouncing Kaf instead of Qaf, or Seen instead of Sad).
      final isPromptBias = await ApiKeys.isPromptBiasEnabled();
      if (isPromptBias && targetArabicPrompt.isNotEmpty) {
        request.fields['prompt'] = targetArabicPrompt;
      }

      request.fields['response_format'] = 'json';
      request.fields['temperature'] = '0.0';

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: 'recitation.m4a',
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['text'] as String?)?.trim();
        return text;
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _amplitudeSub?.cancel();
    _audioRecorder?.dispose();
    _audioRecorder = null;
  }
}
