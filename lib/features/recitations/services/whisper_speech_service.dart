import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

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
/// via Groq Whisper Large-v3 with live micro-streaming and target scripture conditioning.
class WhisperSpeechService {
  WhisperSpeechService._();

  static final WhisperSpeechService instance = WhisperSpeechService._();

  AudioRecorder? _audioRecorder;
  String? _currentRecordingPath;
  StreamSubscription<Uint8List>? _streamSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  BytesBuilder _pcmBuffer = BytesBuilder(copy: false);
  Timer? _chunkTimer;
  bool _isTranscribingChunk = false;
  bool _isStreaming = false;

  bool get isStreaming => _isStreaming;

  /// Checks if microphone recording permission is granted.
  Future<bool> hasPermission() async {
    try {
      _audioRecorder ??= AudioRecorder();
      return await _audioRecorder!.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Starts live streaming audio capture with rolling Groq Whisper micro-chunk transcription.
  /// Audio is captured at 16kHz mono PCM (ideal for Whisper), and periodic slices are sent
  /// every ~3.2 seconds (~18.7 RPM) safely within Groq's 20 RPM limit.
  Future<RecordingStartResult> startLiveStreaming({
    required Function(String liveTranscript) onTranscript,
    Function(double normalizedSoundLevel)? onSoundLevel,
    String? prompt,
  }) async {
    try {
      _audioRecorder ??= AudioRecorder();

      final hasPerm = await _audioRecorder!.hasPermission();
      if (!hasPerm) return RecordingStartResult.permissionDenied;

      // Clean up any stale sessions
      await cancel();

      _pcmBuffer = BytesBuilder(copy: false);
      _isStreaming = true;
      _isTranscribingChunk = false;

      // Start recording PCM 16-bit 16kHz mono audio stream
      final audioStream = await _audioRecorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      // Listen to raw PCM chunks and update live amplitude
      _streamSub?.cancel();
      _streamSub = audioStream.listen((chunk) {
        if (!_isStreaming) return;
        _pcmBuffer.add(chunk);

        if (onSoundLevel != null && chunk.isNotEmpty) {
          final byteData = ByteData.sublistView(chunk);
          double sumSquares = 0.0;
          final sampleCount = chunk.length ~/ 2;
          for (int i = 0; i < chunk.length - 1; i += 2) {
            final sample = byteData.getInt16(i, Endian.little);
            sumSquares += sample * sample;
          }
          if (sampleCount > 0) {
            final rms = math.sqrt(sumSquares / sampleCount);
            final normalized = (rms / 8000.0).clamp(0.0, 1.0);
            onSoundLevel(normalized);
          }
        }
      });

      // Periodic Groq Whisper micro-chunk timer
      // Interval: 3.2 seconds (comfortably under 20 RPM free-tier limit)
      _chunkTimer?.cancel();
      _chunkTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) async {
        if (!_isStreaming || _isTranscribingChunk) return;

        final currentBytes = _pcmBuffer.toBytes();
        // Require at least 1.5 seconds of audio (16000 * 2 * 1.5 = 48000 bytes)
        if (currentBytes.length < 48000) return;

        _isTranscribingChunk = true;
        try {
          // If recitation is long (>40s), take rolling slice of last 25s
          Uint8List pcmSlice;
          const maxChunkBytes = 16000 * 2 * 25; // 25 seconds
          if (currentBytes.length > maxChunkBytes) {
            pcmSlice = currentBytes.sublist(currentBytes.length - maxChunkBytes);
          } else {
            pcmSlice = currentBytes;
          }

          final wavBytes = buildWavBytes(pcmSlice, sampleRate: 16000, numChannels: 1);
          final text = await _transcribeWavBytes(
            wavBytes: wavBytes,
            prompt: prompt ?? '',
            isLiveChunk: true,
          );

          if (text != null && text.trim().isNotEmpty && _isStreaming) {
            onTranscript(text.trim());
          }
        } catch (_) {
          // Transient network issue, next tick will retry with updated buffer
        } finally {
          _isTranscribingChunk = false;
        }
      });

      return RecordingStartResult.success;
    } catch (e) {
      _isStreaming = false;
      if (e.toString().contains('MissingPluginException') ||
          e.toString().contains('No implementation found')) {
        return RecordingStartResult.pluginNotLoaded;
      }
      return RecordingStartResult.failure;
    }
  }

  /// Starts standard audio recording with live amplitude monitoring (used in fallback mode).
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

  /// Stops audio recording or streaming, saves finalized WAV audio if streaming,
  /// cleans up subscriptions and returns the resulting audio file path.
  Future<String?> stopRecording() async {
    try {
      _chunkTimer?.cancel();
      _chunkTimer = null;
      _isStreaming = false;

      await _streamSub?.cancel();
      _streamSub = null;

      await _amplitudeSub?.cancel();
      _amplitudeSub = null;

      if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
        final stoppedPath = await _audioRecorder!.stop();
        if (stoppedPath != null) {
          _currentRecordingPath = stoppedPath;
        }
      }

      // If PCM was streamed, build and save the complete WAV file
      if (_pcmBuffer.length > 0) {
        final allPcm = _pcmBuffer.toBytes();
        final fullWav = buildWavBytes(allPcm, sampleRate: 16000, numChannels: 1);

        final tempDir = await getTemporaryDirectory();
        _currentRecordingPath =
            '${tempDir.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.wav';
        final file = File(_currentRecordingPath!);
        await file.writeAsBytes(fullWav, flush: true);
        return _currentRecordingPath;
      }

      return _currentRecordingPath;
    } catch (_) {
      return _currentRecordingPath;
    }
  }

  /// Discards the current recording session and releases microphone.
  Future<void> cancel() async {
    try {
      _chunkTimer?.cancel();
      _chunkTimer = null;
      _isStreaming = false;

      await _streamSub?.cancel();
      _streamSub = null;

      await _amplitudeSub?.cancel();
      _amplitudeSub = null;

      _pcmBuffer.clear();

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

  /// Transcribes in-memory WAV bytes directly via Groq Whisper API without disk I/O.
  Future<String?> _transcribeWavBytes({
    required Uint8List wavBytes,
    required String prompt,
    bool isLiveChunk = false,
  }) async {
    final apiKey = await ApiKeys.getGroqApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $apiKey';
      // Use whisper-large-v3-turbo for sub-200ms latency during live streaming,
      // whisper-large-v3 for final authoritative scoring
      request.fields['model'] = isLiveChunk ? 'whisper-large-v3-turbo' : 'whisper-large-v3';
      request.fields['language'] = 'ar';

      if (prompt.isNotEmpty) {
        request.fields['prompt'] = prompt;
      }

      request.fields['response_format'] = 'json';
      request.fields['temperature'] = '0.0';

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        wavBytes,
        filename: 'chunk.wav',
      ));

      final streamedResponse = await request.send().timeout(
        Duration(seconds: isLiveChunk ? 8 : 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['text'] as String?)?.trim();
      } else if (isLiveChunk && (response.statusCode == 404 || response.statusCode == 400)) {
        // Fallback to whisper-large-v3 if turbo is unavailable
        return await _transcribeWavBytes(
          wavBytes: wavBytes,
          prompt: prompt,
          isLiveChunk: false,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
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

      final isPromptBias = await ApiKeys.isPromptBiasEnabled();
      if (isPromptBias && targetArabicPrompt.isNotEmpty) {
        request.fields['prompt'] = targetArabicPrompt;
      }

      request.fields['response_format'] = 'json';
      request.fields['temperature'] = '0.0';

      final filename = file.path.endsWith('.wav') ? 'recitation.wav' : 'recitation.m4a';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: filename,
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
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

  /// Synthesizes standard 44-byte RIFF WAV audio bytes from raw 16-bit PCM bytes.
  static Uint8List buildWavBytes(
    Uint8List pcmData, {
    int sampleRate = 16000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final totalDataLen = pcmData.length;
    final totalAudioLen = totalDataLen + 36;

    final header = Uint8List(44);
    final bd = ByteData.sublistView(header);

    // RIFF chunk
    bd.setUint8(0, 0x52); // 'R'
    bd.setUint8(1, 0x49); // 'I'
    bd.setUint8(2, 0x46); // 'F'
    bd.setUint8(3, 0x46); // 'F'
    bd.setUint32(4, totalAudioLen, Endian.little);
    bd.setUint8(8, 0x57); // 'W'
    bd.setUint8(9, 0x41); // 'A'
    bd.setUint8(10, 0x56); // 'V'
    bd.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    bd.setUint8(12, 0x66); // 'f'
    bd.setUint8(13, 0x6D); // 'm'
    bd.setUint8(14, 0x74); // 't'
    bd.setUint8(15, 0x20); // ' '
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    bd.setUint8(36, 0x64); // 'd'
    bd.setUint8(37, 0x61); // 'a'
    bd.setUint8(38, 0x74); // 't'
    bd.setUint8(39, 0x61); // 'a'
    bd.setUint32(40, totalDataLen, Endian.little);

    final wav = Uint8List(44 + totalDataLen);
    wav.setRange(0, 44, header);
    wav.setRange(44, 44 + totalDataLen, pcmData);
    return wav;
  }

  void dispose() {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _streamSub?.cancel();
    _streamSub = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _audioRecorder?.dispose();
    _audioRecorder = null;
  }
}
