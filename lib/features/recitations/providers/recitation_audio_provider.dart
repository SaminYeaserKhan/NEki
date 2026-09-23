import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran/quran.dart' as quran;

import '../../../core/locale/locale_provider.dart';
import '../../dua/dua_provider.dart';
import '../../hadith/hadith_provider.dart';
import '../../quran/quran_provider.dart';
import '../../quran/utils/quran_verse_helper.dart';
import '../services/neural_tts_service.dart';
import '../utils/translation_speech_helper.dart';
import 'reading_settings_provider.dart';

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
  final AudioTrackMode trackMode;
  final String? currentArabicText;
  final Dua? currentDua;
  final HadithEntry? currentHadith;

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
    this.trackMode = AudioTrackMode.recitation,
    this.currentArabicText,
    this.currentDua,
    this.currentHadith,
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
    AudioTrackMode? trackMode,
    String? currentArabicText,
    Dua? currentDua,
    HadithEntry? currentHadith,
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
      trackMode: trackMode ?? this.trackMode,
      currentArabicText: currentArabicText ?? this.currentArabicText,
      currentDua: currentDua ?? this.currentDua,
      currentHadith: currentHadith ?? this.currentHadith,
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

  Future<void> playVerse(int surah, int verse, {AudioTrackMode? trackMode}) async {
    final player = _initPlayer();
    final total = quran.getVerseCount(surah);
    final surahName = quran.getSurahName(surah);
    final cleanArabic = QuranVerseHelper.getCleanVerseText(surah, verse, verseEndSymbol: false);
    final effectiveMode = trackMode ?? ref.read(readingSettingsProvider).audioTrackMode;
    final isBn = ref.read(localeProvider) == AppLocale.bangla;

    final String subtitleText = effectiveMode == AudioTrackMode.recitation
        ? 'Surah $surah • Mishary Rashid Alafasy'
        : (isBn ? 'বাংলা অনুবাদ • Spoken Audio' : 'English Translation • Spoken Audio');

    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.quran,
      currentSurah: surah,
      currentVerse: verse,
      totalVersesInSurah: total,
      title: '$surahName • Ayah $verse',
      subtitle: subtitleText,
      trackMode: effectiveMode,
      currentArabicText: cleanArabic,
      currentDua: null,
      currentHadith: null,
      position: Duration.zero,
    );

    try {
      if (effectiveMode == AudioTrackMode.recitation) {
        final url = quran.getAudioURLByVerse(surah, verse);
        await player.setUrl(url);
      } else {
        final transLang = isBn ? TranslationLang.bengali : TranslationLang.english;
        final translationText = QuranVerseHelper.getVerseTranslation(surah, verse, transLang);
        final source = await TranslationSpeechHelper.createTranslationAudioSource(
          translationText,
          isBengali: isBn,
          gender: ref.read(readingSettingsProvider).voiceGender,
          speed: state.speed,
        );
        await player.setAudioSource(source);
      }
      await player.setSpeed(state.speed);
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    } catch (_) {
      state = state.copyWith(status: RecitationPlaybackStatus.error);
    }
  }

  /// Mapping of Hadith ID to track number in Sheikh Yasir Al-Failakawi's studio
  /// recitation of Imam An-Nawawi's 40 Hadiths (Arba'een) archive on Archive.org.
  static const Map<int, int> hadithNawawiTrackMap = {
    1: 1, // Bukhari 1: Actions are by intention (Nawawi 1)
    2: 13, // Bukhari 13: None of you believes until he loves for his brother (Nawawi 13)
    3: 15, // Bukhari 6018: Speak good or remain silent (Nawawi 15)
    6: 3, // Bukhari 8: Islam is built on five pillars (Nawawi 3)
    9: 23, // Muslim 223: Purification is half of faith (Nawawi 23)
    12: 36, // Muslim 2699: Relieving a believer's hardship & seeking knowledge (Nawawi 36)
    13: 18, // Tirmidhi 1987: Fear Allah wherever you are (Nawawi 18)
  };

  /// Resolves the studio Quran recitation URL for Quranic Duas.
  static String? getDuaAudioUrl(Dua dua) {
    if (dua.audioUrl != null && dua.audioUrl!.isNotEmpty) {
      return dua.audioUrl!;
    }
    if (dua.isQuranic && dua.surahNumber != null && dua.verseNumber != null) {
      final s = dua.surahNumber!.toString().padLeft(3, '0');
      final v = dua.verseNumber!.toString().padLeft(3, '0');
      return 'https://everyayah.com/data/Alafasy_128kbps/$s$v.mp3';
    }
    return null;
  }

  /// Returns descriptive subtitle for Dua recitation player.
  static String getDuaSubtitle(Dua dua) {
    if (dua.isQuranic && dua.surahNumber != null && dua.verseNumber != null) {
      return '${quran.getSurahName(dua.surahNumber!)}:${dua.verseNumber} • Sheikh Mishary Alafasy';
    }
    return 'Arabic Recitation • Authentic Pronunciation';
  }

  /// Resolves the bundled studio human recitation asset for a Hadith.
  static String getHadithAudioAsset(HadithEntry hadith) {
    if (hadith.audioAsset != null && hadith.audioAsset!.isNotEmpty) {
      return hadith.audioAsset!;
    }
    final num = hadith.id ?? hadith.number;
    return 'assets/audio/hadiths/h$num.mp3';
  }

  /// Resolves studio reciter audio URL for a Hadith if available.
  static String? getHadithAudioUrl(HadithEntry hadith) {
    final track = hadithNawawiTrackMap[hadith.id] ?? hadithNawawiTrackMap[hadith.number];
    if (track != null) {
      return 'https://archive.org/download/al-arbaeen_an-nawawi_al-failakawi/$track.mp3';
    }
    return null;
  }

  /// Returns descriptive subtitle for Hadith recitation player.
  static String getHadithSubtitle(HadithEntry hadith) {
    return '${hadith.bookName} • Human Arabic Recitation';
  }

  Future<void> playDua(Dua dua, {AudioTrackMode? trackMode}) async {
    final player = _initPlayer();
    final effectiveMode = trackMode ?? ref.read(readingSettingsProvider).audioTrackMode;
    final isBn = ref.read(localeProvider) == AppLocale.bangla;

    final subtitleText = effectiveMode == AudioTrackMode.recitation
        ? getDuaSubtitle(dua)
        : (isBn ? 'বাংলা অনুবাদ • Spoken Audio' : 'English Translation • Spoken Audio');

    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.dua,
      currentSurah: dua.surahNumber,
      currentVerse: dua.id,
      title: dua.title,
      subtitle: subtitleText,
      trackMode: effectiveMode,
      currentArabicText: dua.arabic,
      currentDua: dua,
      currentHadith: null,
      position: Duration.zero,
    );

    try {
      if (effectiveMode == AudioTrackMode.recitation) {
        final url = getDuaAudioUrl(dua);
        if (url != null && url.isNotEmpty) {
          try {
            if (url.startsWith('assets/')) {
              await player.setAsset(url);
            } else {
              await player.setUrl(url);
            }
          } catch (_) {
            // Seamless offline fallback to Arabic Neural TTS if network audio stream fails
            final source = await NeuralTtsService.instance.getAudioSource(
              text: dua.arabic,
              langCode: 'ar',
              gender: ref.read(readingSettingsProvider).voiceGender,
              speed: state.speed,
            );
            await player.setAudioSource(source);
          }
        } else {
          // Authentic Arabic Neural TTS for Prophetic Duas (100% word-for-word accuracy with tashkeel)
          final source = await NeuralTtsService.instance.getAudioSource(
            text: dua.arabic,
            langCode: 'ar',
            gender: ref.read(readingSettingsProvider).voiceGender,
            speed: state.speed,
          );
          await player.setAudioSource(source);
        }
      } else {
        final translationText = isBn
            ? (dua.bengali?.trim().isNotEmpty == true ? dua.bengali! : dua.description)
            : dua.description;
        final source = await TranslationSpeechHelper.createTranslationAudioSource(
          translationText,
          isBengali: isBn,
          gender: ref.read(readingSettingsProvider).voiceGender,
          speed: state.speed,
        );
        await player.setAudioSource(source);
      }
      await player.setSpeed(state.speed);
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    } catch (_) {
      state = state.copyWith(status: RecitationPlaybackStatus.error);
    }
  }

  Future<void> playHadith(HadithEntry hadith, {AudioTrackMode? trackMode}) async {
    final player = _initPlayer();
    final effectiveMode = trackMode ?? ref.read(readingSettingsProvider).audioTrackMode;
    final isBn = ref.read(localeProvider) == AppLocale.bangla;

    final subtitleText = effectiveMode == AudioTrackMode.recitation
        ? getHadithSubtitle(hadith)
        : (isBn ? 'বাংলা অনুবাদ • Spoken Audio' : 'English Translation • Spoken Audio');

    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.hadith,
      currentSurah: null,
      currentVerse: hadith.number,
      title: hadith.reference ?? 'Hadith ${hadith.number}',
      subtitle: subtitleText,
      trackMode: effectiveMode,
      currentArabicText: hadith.arabic,
      currentHadith: hadith,
      currentDua: null,
      position: Duration.zero,
    );

    try {
      if (effectiveMode == AudioTrackMode.recitation) {
        final assetPath = getHadithAudioAsset(hadith);
        try {
          await player.setAsset(assetPath);
        } catch (_) {
          final studioUrl = getHadithAudioUrl(hadith);
          if (studioUrl != null) {
            await player.setUrl(studioUrl);
          } else {
            final source = await TranslationSpeechHelper.createTranslationAudioSource(
              hadith.arabic,
              isBengali: false,
              gender: TtsVoiceGender.male,
              speed: state.speed,
            );
            await player.setAudioSource(source);
          }
        }
      } else {
        final translationText = isBn
            ? (hadith.bengali?.trim().isNotEmpty == true
                ? hadith.bengali!
                : (hadith.english ?? hadith.text))
            : (hadith.english?.trim().isNotEmpty == true
                ? hadith.english!
                : (hadith.bengali ?? hadith.text));
        final source = await TranslationSpeechHelper.createTranslationAudioSource(
          translationText,
          isBengali: isBn,
          gender: ref.read(readingSettingsProvider).voiceGender,
          speed: state.speed,
        );
        await player.setAudioSource(source);
      }
      await player.setSpeed(state.speed);
      await player.play();
      state = state.copyWith(status: RecitationPlaybackStatus.playing);
    } catch (_) {
      state = state.copyWith(status: RecitationPlaybackStatus.error);
    }
  }

  /// Switches audio track mode (Recitation <-> Translation) and seamlessly restarts
  /// playback of the active item on the newly chosen track.
  Future<void> switchTrackMode(AudioTrackMode newMode) async {
    await ref.read(readingSettingsProvider.notifier).setAudioTrackMode(newMode);
    if (!state.hasAudio) return;

    if (state.type == RecitationType.quran &&
        state.currentSurah != null &&
        state.currentVerse != null) {
      if (state.currentVerse == 0) {
        await playSurahOpening(state.currentSurah!);
      } else {
        await playVerse(state.currentSurah!, state.currentVerse!, trackMode: newMode);
      }
    } else if (state.type == RecitationType.dua && state.currentDua != null) {
      await playDua(state.currentDua!, trackMode: newMode);
    } else if (state.type == RecitationType.hadith && state.currentHadith != null) {
      await playHadith(state.currentHadith!, trackMode: newMode);
    }
  }

  Future<void> playArabicPronunciation({
    required String title,
    required String subtitle,
    required String arabicText,
    int? surahNumber,
    int? verseNumber,
    Dua? dua,
    HadithEntry? hadith,
  }) async {
    if (dua != null) {
      await playDua(dua);
      return;
    }
    if (hadith != null) {
      await playHadith(hadith);
      return;
    }
    if (surahNumber != null && verseNumber != null) {
      await playVerse(surahNumber, verseNumber);
      return;
    }

    final player = _initPlayer();
    state = state.copyWith(
      status: RecitationPlaybackStatus.loading,
      type: RecitationType.dua,
      currentSurah: surahNumber,
      currentVerse: verseNumber,
      title: title,
      subtitle: subtitle,
      currentArabicText: arabicText,
      position: Duration.zero,
    );

    try {
      final cleanArabic = arabicText.replaceAll(RegExp(r'[0-9\(\)]'), '').trim();
      final snippet = cleanArabic.length > 200 ? cleanArabic.substring(0, 200) : cleanArabic;
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

  /// Fast forwards audio playback by 5 seconds.
  Future<void> fastForward5Seconds() =>
      fastForward(const Duration(seconds: 5));

  /// Rewinds audio playback by 5 seconds.
  Future<void> rewind5Seconds() =>
      rewind(const Duration(seconds: 5));

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

  static const List<double> availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  Future<void> setSpeed(double newSpeed) async {
    await _player?.setSpeed(newSpeed);
    state = state.copyWith(speed: newSpeed);
  }

  /// Decreases playback speed to the nearest lower preset (min 0.5x).
  Future<void> decreaseSpeed() async {
    final current = state.speed;
    final lowerSpeeds = availableSpeeds.where((s) => s < current - 0.01).toList();
    if (lowerSpeeds.isNotEmpty) {
      await setSpeed(lowerSpeeds.last);
    }
  }

  /// Increases playback speed to the nearest higher preset (max 2.0x).
  Future<void> increaseSpeed() async {
    final current = state.speed;
    final higherSpeeds = availableSpeeds.where((s) => s > current + 0.01).toList();
    if (higherSpeeds.isNotEmpty) {
      await setSpeed(higherSpeeds.first);
    }
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
