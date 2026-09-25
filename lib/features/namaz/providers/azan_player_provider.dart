import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

class AzanPlayerState {
  final bool isPlaying;
  final String? activeSoundKey;
  final String? errorMessage;

  const AzanPlayerState({
    this.isPlaying = false,
    this.activeSoundKey,
    this.errorMessage,
  });

  AzanPlayerState copyWith({
    bool? isPlaying,
    String? activeSoundKey,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AzanPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      activeSoundKey: activeSoundKey ?? this.activeSoundKey,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AzanPlayerNotifier extends Notifier<AzanPlayerState> {
  AudioPlayer? _player;

  static const Map<String, String> localAssets = {
    'mishary': 'assets/audio/azan/azan_mishary.mp3',
    'makkah': 'assets/audio/azan/azan_makkah.mp3',
    'madinah': 'assets/audio/azan/azan_madinah.mp3',
    'alaqsa': 'assets/audio/azan/azan_alaqsa.mp3',
    'mansour': 'assets/audio/azan/azan_mansour.mp3',
    'takbir': 'assets/audio/azan/azan_takbir.mp3',
  };

  static const Map<String, String> fallbackUrls = {
    'mishary': 'https://raw.githubusercontent.com/abodehq/Athan-MP3/master/Sounds/Athan%20Mishary%20Alafasi.mp3',
    'makkah': 'https://raw.githubusercontent.com/abodehq/Athan-MP3/master/Sounds/Athan%20Hamdan%20Almalki.mp3',
    'madinah': 'https://raw.githubusercontent.com/abodehq/Athan-MP3/master/Sounds/Athan%20Ahmad%20Nuyne3.mp3',
    'alaqsa': 'https://upload.wikimedia.org/wikipedia/commons/b/b0/Beautiful_adhan.ogg',
    'mansour': 'https://raw.githubusercontent.com/abodehq/Athan-MP3/master/Sounds/Athan%20Mansoor%20Az-Zahrani.mp3',
    'takbir': 'https://raw.githubusercontent.com/abodehq/Athan-MP3/master/Sounds/Athan%20Abed%20Albase6.mp3',
  };

  @override
  AzanPlayerState build() {
    ref.onDispose(() {
      _player?.dispose();
    });
    return const AzanPlayerState();
  }

  AudioPlayer get _audioPlayer {
    _player ??= AudioPlayer();
    _player!.playerStateStream.listen((stateEvent) {
      if (stateEvent.processingState == ProcessingState.completed) {
        state = state.copyWith(isPlaying: false, activeSoundKey: null);
      }
    });
    return _player!;
  }

  Future<void> playSound(String soundKey) async {
    final key = soundKey.toLowerCase();

    // If already playing this sound, stop it (toggle)
    if (state.isPlaying && state.activeSoundKey == key) {
      await stop();
      return;
    }

    final assetPath = localAssets[key];
    final fallbackUrl = fallbackUrls[key];

    if (assetPath == null && fallbackUrl == null) {
      state = state.copyWith(
        isPlaying: false,
        errorMessage: 'Sound not found',
      );
      return;
    }

    try {
      state = state.copyWith(
        isPlaying: true,
        activeSoundKey: key,
        clearError: true,
      );

      final p = _audioPlayer;
      await p.stop();

      // Try local asset first
      if (assetPath != null) {
        try {
          await p.setAsset(assetPath);
          await p.play();
          return;
        } catch (assetErr) {
          debugPrint('Local azan asset load failed, trying fallback URL: $assetErr');
        }
      }

      // If asset load fails or unavailable, try fallback URL
      if (fallbackUrl != null) {
        await p.setUrl(fallbackUrl);
        await p.play();
      }
    } catch (e) {
      debugPrint('Error playing azan audio: $e');
      state = state.copyWith(
        isPlaying: false,
        activeSoundKey: null,
        errorMessage: 'Unable to play azan audio ($e)',
      );
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    state = state.copyWith(isPlaying: false, activeSoundKey: null);
  }
}

final azanPlayerProvider =
    NotifierProvider<AzanPlayerNotifier, AzanPlayerState>(
  AzanPlayerNotifier.new,
);
