import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran/quran.dart' as quran;

import '../../dua/dua_provider.dart';
import '../../hadith/hadith_provider.dart';
import '../../quran/utils/quran_verse_helper.dart';

enum RecitationType { none, quran, dua, hadith }

enum RecitationPlaybackStatus { idle, loading, playing, paused, error }

enum RecitationRepeatMode { off, verse, all }

class RecitationAudioState {
  final RecitationPlaybackStatus status;
  final RecitationType type;
  final int? currentSurah;
  final int? currentVerse;
  final int? totalVersesInSurah;
  final String title;
  final String subtitle;
  final Duration position;
  final Duration duration;
  final double speed;
  final RecitationRepeatMode repeatMode;

  const RecitationAudioState({
    this.status = RecitationPlaybackStatus.idle,
    this.type = RecitationType.none,
    this.currentSurah,
    this.currentVerse,
    this.totalVersesInSurah,
    this.title = '',
    this.subtitle = '',
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.repeatMode = RecitationRepeatMode.off,
  });

  bool get isPlaying => status == RecitationPlaybackStatus.playing;
  bool get isLoading => status == RecitationPlaybackStatus.loading;
  bool get hasAudio => status != RecitationPlaybackStatus.idle;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  RecitationAudioState copyWith({
    RecitationPlaybackStatus? status,
    RecitationType? type,
    int? currentSurah,
    int? currentVerse,
    int? totalVersesInSurah,
    String? title,
    String? subtitle,
    Duration? position,
    Duration? duration,
    double? speed,
    RecitationRepeatMode? repeatMode,
  }) {
    return RecitationAudioState(
      status: status ?? this.status,
      type: type ?? this.type,
      currentSurah: currentSurah ?? this.currentSurah,
      currentVerse: currentVerse ?? this.currentVerse,
      totalVersesInSurah: totalVersesInSurah ?? this.totalVersesInSurah,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

class RecitationAudioNotifier extends Notifier<RecitationAudioState> {
  AudioPlayer? _player;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  RecitationAudioState build() {
    AudioPlayer.clearAssetCache().catchError((_) {});
    ref.onDispose(() {
      _posSub?.cancel();
      _durSub?.cancel();
      _stateSub?.cancel();
      _player?.dispose();
    });
    return const RecitationAudioState();
  }

  AudioPlayer _initPlayer() {
    if (_player != null) return _player!;
    _player = AudioPlayer();

    _posSub = _player!.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durSub = _player!.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });

    _stateSub = _player!.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      } else if (ps.playing) {
        if (state.status != RecitationPlaybackStatus.playing) {
          state = state.copyWith(status: RecitationPlaybackStatus.playing);
        }
      } else if (ps.processingState == ProcessingState.ready && !ps.playing) {
        if (state.status == RecitationPlaybackStatus.playing) {
          state = state.copyWith(status: RecitationPlaybackStatus.paused);
        }
      }
    });

    return _player!;
  }

  void _onTrackCompleted() {
    if (state.repeatMode == RecitationRepeatMode.verse) {
      // Loop same verse
      seekTo(Duration.zero);
      resume();
      return;
    }

    if (state.type == RecitationType.quran &&
        state.currentSurah != null &&
        state.currentVerse != null) {
      final surah = state.currentSurah!;
      final total = state.totalVersesInSurah ?? quran.getVerseCount(surah);

      if (state.currentVerse == 0) {
        // Opening track ("A'udhu billahi minash-shaytanir-rajim, Bismillahir Rahmanir Raheem") finished!
        // Seamlessly start Ayah 1!
        playVerse(surah, 1);
        return;
      } else if (state.currentVerse! < total) {
        // Auto-advance to next verse!
        playVerse(surah, state.currentVerse! + 1);
        return;
      } else if (state.currentVerse == total) {
        // Surah complete! Recite closing "Sadaqallahul Aliyyil Azeem"
        playSurahConclusion(surah);
        return;
      } else if (state.currentVerse! > total && state.repeatMode == RecitationRepeatMode.all) {
        // Loop Surah back to opening track
        playSurahOpening(surah);
        return;
      }
    }

    state = state.copyWith(
      status: RecitationPlaybackStatus.idle,
      position: Duration.zero,
    );
  }

  /// Plays the introductory opening audio (first ayah of Surah Al-Fatihah: Bismillah).
  /// - For Surah 1 (Al-Fatihah), Ayah 1 is the Bismillah itself, so it starts directly at Ayah 1.
  /// - For Surah 9 (At-Tawbah), starts directly at Ayah 1 as it has no Bismillah.
  Future<void> playSurahOpening(int surah) async {
    if (!QuranVerseHelper.hasOpeningAudio(surah)) {
      await playVerse(surah, 1);
      return;
    }
    final player = _initPlayer();
    final total = quran.getVerseCount(surah);
    final surahName = quran.getSurahName(surah);

    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.quran,
      currentSurah: surah,
      currentVerse: 0,
      totalVersesInSurah: total,
      title: '$surahName • Bismillah',
      subtitle: QuranVerseHelper.basmalahTransliterationEn,
      position: Duration.zero,
    );

    try {
      final url = QuranVerseHelper.getOpeningAudioUrl();
      await player.setUrl(url);
      await player.setSpeed(state.speed);
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    } catch (_) {
      // If opening fails, seamlessly start Ayah 1
      playVerse(surah, 1);
    }
  }

  /// Plays the authentic conclusion recitation ("Sadaqallahul 'Adheem").
  Future<void> playSurahConclusion(int surah) async {
    final player = _initPlayer();
    final total = quran.getVerseCount(surah);
    final surahName = quran.getSurahName(surah);

    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.quran,
      currentSurah: surah,
      currentVerse: total + 1,
      totalVersesInSurah: total,
      title: '$surahName • Tasdiq',
      subtitle: QuranVerseHelper.tasdiqTransliterationEn,
      position: Duration.zero,
    );

    try {
      await player.setAsset(QuranVerseHelper.closingAudioPath);
      await player.setSpeed(state.speed);
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    } catch (_) {
      state = state.copyWith(
        status: RecitationPlaybackStatus.idle,
        position: Duration.zero,
      );
    }
  }

  /// Plays a surah from the beginning with introductory opening (Ayah 1 of Al-Fatihah).
  Future<void> playSurah(int surah, {bool withOpening = true}) async {
    if (withOpening && QuranVerseHelper.hasOpeningAudio(surah)) {
      await playSurahOpening(surah);
    } else {
      await playVerse(surah, 1);
    }
  }

  Future<void> playVerse(int surah, int verse) async {
    final player = _initPlayer();
    final total = quran.getVerseCount(surah);
    final surahName = quran.getSurahName(surah);

    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.quran,
      currentSurah: surah,
      currentVerse: verse,
      totalVersesInSurah: total,
      title: '$surahName • Ayah $verse',
      subtitle: 'Surah $surah • Mishary Rashid Alafasy',
      position: Duration.zero,
    );

    try {
      final url = quran.getAudioURLByVerse(surah, verse);
      await player.setUrl(url);
      await player.setSpeed(state.speed);
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    } catch (_) {
      state = state.copyWith(status: RecitationPlaybackStatus.error);
    }
  }

  Future<void> playDua(Dua dua) async {
    final player = _initPlayer();

    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.dua,
      currentSurah: null,
      currentVerse: dua.id,
      title: dua.title,
      subtitle: dua.category.toUpperCase(),
      position: Duration.zero,
    );

    try {
      // Audio pronunciation via secure Islamic audio streaming or TTS pronunciation URL
      final encodedText = Uri.encodeComponent(dua.arabic);
      final url = 'https://translate.google.com/translate_tts?ie=UTF-8&q=$encodedText&tl=ar&client=tw-ob';
      await player.setUrl(url);
      await player.setSpeed(state.speed);
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    } catch (_) {
      state = state.copyWith(status: RecitationPlaybackStatus.error);
    }
  }

  Future<void> playHadith(HadithEntry hadith) async {
    final player = _initPlayer();

    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.hadith,
      currentSurah: null,
      currentVerse: hadith.number,
      title: hadith.reference ?? 'Hadith ${hadith.number}',
      subtitle: hadith.chapter,
      position: Duration.zero,
    );

    try {
      // Arabic Matn pronunciation
      final cleanArabic = hadith.arabic.replaceAll(RegExp(r'[0-9]'), '').trim();
      final snippet = cleanArabic.length > 180 ? cleanArabic.substring(0, 180) : cleanArabic;
      final encodedText = Uri.encodeComponent(snippet);
      final url = 'https://translate.google.com/translate_tts?ie=UTF-8&q=$encodedText&tl=ar&client=tw-ob';
      await player.setUrl(url);
      await player.setSpeed(state.speed);
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    } catch (_) {
      state = state.copyWith(status: RecitationPlaybackStatus.error);
    }
  }

  Future<void> togglePlayPause() async {
    final player = _initPlayer();
    if (state.isPlaying) {
      await player.pause();
      state = state.copyWith(status: RecitationPlaybackStatus.paused);
    } else if (state.status == RecitationPlaybackStatus.paused || (state.hasAudio && !state.isPlaying)) {
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    }
  }

  Future<void> pause() async {
    await _player?.pause();
    state = state.copyWith(status: RecitationPlaybackStatus.paused);
  }

  Future<void> resume() async {
    await _player?.play();
    state = state.copyWith(status: RecitationPlaybackStatus.playing);
  }

  Future<void> seekTo(Duration position) async {
    await _player?.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> fastForward([Duration step = const Duration(seconds: 10)]) async {
    final newPos = state.position + step;
    if (newPos < state.duration) {
      await seekTo(newPos);
    } else {
      await nextItem();
    }
  }

  Future<void> rewind([Duration step = const Duration(seconds: 10)]) async {
    final newPos = state.position - step;
    await seekTo(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> nextItem() async {
    if (state.type == RecitationType.quran &&
        state.currentSurah != null &&
        state.currentVerse != null) {
      final surah = state.currentSurah!;
      final total = state.totalVersesInSurah ?? quran.getVerseCount(surah);
      if (state.currentVerse == 0) {
        await playVerse(surah, 1);
      } else if (state.currentVerse! < total) {
        await playVerse(surah, state.currentVerse! + 1);
      } else if (state.currentVerse == total) {
        await playSurahConclusion(surah);
      }
    }
  }

  Future<void> previousItem() async {
    if (state.type == RecitationType.quran &&
        state.currentSurah != null &&
        state.currentVerse != null) {
      final surah = state.currentSurah!;
      if (state.currentVerse! > 1) {
        await playVerse(surah, state.currentVerse! - 1);
      } else if (state.currentVerse == 1 && QuranVerseHelper.hasOpeningAudio(surah)) {
        await playSurahOpening(surah);
      } else {
        await seekTo(Duration.zero);
      }
    } else {
      await seekTo(Duration.zero);
    }
  }

  Future<void> setSpeed(double newSpeed) async {
    await _player?.setSpeed(newSpeed);
    state = state.copyWith(speed: newSpeed);
  }

  void toggleRepeatMode() {
    switch (state.repeatMode) {
      case RecitationRepeatMode.off:
        state = state.copyWith(repeatMode: RecitationRepeatMode.verse);
        break;
      case RecitationRepeatMode.verse:
        state = state.copyWith(repeatMode: RecitationRepeatMode.all);
        break;
      case RecitationRepeatMode.all:
        state = state.copyWith(repeatMode: RecitationRepeatMode.off);
        break;
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    state = const RecitationAudioState();
  }
}

final recitationAudioProvider =
    NotifierProvider<RecitationAudioNotifier, RecitationAudioState>(
        RecitationAudioNotifier.new);
