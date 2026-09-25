import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/locale/locale_provider.dart';
import 'utils/quran_verse_helper.dart';

// ─────────────────────────────────────────────────────
//  Translation language preference (Synced with global locale)
// ─────────────────────────────────────────────────────

enum TranslationLang { bengali, english }

class TranslationNotifier extends Notifier<TranslationLang> {
  static const _key = 'neki_quran_translation';

  @override
  TranslationLang build() {
    final currentLocale = ref.watch(localeProvider);
    return currentLocale == AppLocale.bangla
        ? TranslationLang.bengali
        : TranslationLang.english;
  }

  Future<void> setLang(TranslationLang lang) async {
    final targetLocale =
        lang == TranslationLang.bengali ? AppLocale.bangla : AppLocale.english;
    await ref.read(localeProvider.notifier).setLocale(targetLocale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.name);
  }

  Future<void> toggle() async {
    await ref.read(localeProvider.notifier).toggle();
  }
}

final translationProvider =
    NotifierProvider<TranslationNotifier, TranslationLang>(
        TranslationNotifier.new);

// ─────────────────────────────────────────────────────
//  Reading progress tracking
// ─────────────────────────────────────────────────────

class ReadingProgress {
  final int surahNumber;
  final int verseNumber;
  final DateTime? lastReadTime;

  const ReadingProgress({
    this.surahNumber = 1,
    this.verseNumber = 1,
    this.lastReadTime,
  });
}

class ReadingProgressNotifier extends Notifier<ReadingProgress> {
  static const _surahKey = 'neki_last_surah';
  static const _verseKey = 'neki_last_verse';
  static const _timeKey = 'neki_last_read_timestamp';

  bool _hasUpdated = false;

  @override
  ReadingProgress build() {
    _hasUpdated = false;
    _loadPersisted();
    return const ReadingProgress();
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    if (_hasUpdated) return;
    final rawSurah = prefs.getInt(_surahKey) ?? 1;
    final validSurah = rawSurah.clamp(1, 114);
    final totalVerses = quran.getVerseCount(validSurah);
    final rawVerse = prefs.getInt(_verseKey) ?? 1;
    final validVerse = rawVerse.clamp(1, totalVerses);
    final timeMillis = prefs.getInt(_timeKey);
    if (_hasUpdated) return;
    state = ReadingProgress(
      surahNumber: validSurah,
      verseNumber: validVerse,
      lastReadTime: timeMillis != null ? DateTime.fromMillisecondsSinceEpoch(timeMillis) : null,
    );
  }

  Future<void> update(int surah, int verse) async {
    _hasUpdated = true;
    final validSurah = surah.clamp(1, 114);
    final totalVerses = quran.getVerseCount(validSurah);
    final validVerse = verse.clamp(1, totalVerses);
    final now = DateTime.now();
    state = ReadingProgress(
      surahNumber: validSurah,
      verseNumber: validVerse,
      lastReadTime: now,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_surahKey, validSurah);
    await prefs.setInt(_verseKey, validVerse);
    await prefs.setInt(_timeKey, now.millisecondsSinceEpoch);
  }
}

final readingProgressProvider =
    NotifierProvider<ReadingProgressNotifier, ReadingProgress>(
        ReadingProgressNotifier.new);

// ─────────────────────────────────────────────────────
//  Quran Bookmarks (Persistent with SharedPreferences)
// ─────────────────────────────────────────────────────

class QuranBookmarkNotifier extends Notifier<Set<String>> {
  static const _key = 'neki_quran_bookmarks';

  @override
  Set<String> build() {
    _loadPersisted();
    return {};
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    if (stored != null) state = stored.toSet();
  }

  Future<void> toggle(int surahNumber, [int? verseNumber]) async {
    final key = verseNumber != null ? '$surahNumber:$verseNumber' : 'surah:$surahNumber';
    final updated = Set<String>.from(state);
    if (updated.contains(key)) {
      updated.remove(key);
    } else {
      updated.add(key);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated.toList());
  }

  bool isBookmarked(int surahNumber, [int? verseNumber]) {
    final key = verseNumber != null ? '$surahNumber:$verseNumber' : 'surah:$surahNumber';
    return state.contains(key);
  }
}

final quranBookmarkProvider =
    NotifierProvider<QuranBookmarkNotifier, Set<String>>(
        QuranBookmarkNotifier.new);

class QuranBookmark {
  final int surahNumber;
  final int? verseNumber;
  final String surahNameEn;
  final String surahNameAr;
  final String surahNameTranslation;
  final int totalVerses;
  final String? arabicText;
  final String? translationEn;
  final String? translationBn;

  const QuranBookmark({
    required this.surahNumber,
    this.verseNumber,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.surahNameTranslation,
    required this.totalVerses,
    this.arabicText,
    this.translationEn,
    this.translationBn,
  });

  bool get isSurah => verseNumber == null;
  bool get isAyah => verseNumber != null;
}

final bookmarkedQuranProvider =
    FutureProvider<List<QuranBookmark>>((ref) async {
  final bookmarks = ref.watch(quranBookmarkProvider);
  if (bookmarks.isEmpty) return [];

  final result = <QuranBookmark>[];
  for (final key in bookmarks) {
    if (key.startsWith('surah:')) {
      final s = int.tryParse(key.substring(6));
      if (s != null && s >= 1 && s <= 114) {
        result.add(QuranBookmark(
          surahNumber: s,
          surahNameEn: quran.getSurahName(s),
          surahNameAr: quran.getSurahNameArabic(s),
          surahNameTranslation: quran.getSurahNameEnglish(s),
          totalVerses: quran.getVerseCount(s),
        ));
      }
    } else {
      final parts = key.split(':');
      if (parts.length == 2) {
        final s = int.tryParse(parts[0]);
        final v = int.tryParse(parts[1]);
        if (s != null && v != null && s >= 1 && s <= 114) {
          final maxVerse = quran.getVerseCount(s);
          if (v >= 1 && v <= maxVerse) {
            result.add(QuranBookmark(
              surahNumber: s,
              verseNumber: v,
              surahNameEn: quran.getSurahName(s),
              surahNameAr: quran.getSurahNameArabic(s),
              surahNameTranslation: quran.getSurahNameEnglish(s),
              totalVerses: maxVerse,
              arabicText: QuranVerseHelper.getCleanVerseText(s, v, verseEndSymbol: false),
              translationEn: QuranVerseHelper.getVerseTranslation(s, v, TranslationLang.english),
              translationBn: QuranVerseHelper.getVerseTranslation(s, v, TranslationLang.bengali),
            ));
          }
        }
      }
    }
  }

  return result;
});

// ─────────────────────────────────────────────────────
//  Surah list data model
// ─────────────────────────────────────────────────────

class SurahInfo {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final String nameTranslation;
  final int verseCount;
  final String placeOfRevelation;

  const SurahInfo({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.nameTranslation,
    required this.verseCount,
    required this.placeOfRevelation,
  });
}

final surahListProvider = Provider<List<SurahInfo>>((ref) {
  return List.generate(114, (index) {
    final num = index + 1;
    return SurahInfo(
      number: num,
      nameArabic: quran.getSurahNameArabic(num),
      nameEnglish: quran.getSurahName(num),
      nameTranslation: quran.getSurahNameEnglish(num),
      verseCount: quran.getVerseCount(num),
      placeOfRevelation: quran.getPlaceOfRevelation(num),
    );
  });
});

class JuzInfo {
  final int number;
  final int startSurahNumber;
  final String startSurahName;
  final int startVerse;

  const JuzInfo({
    required this.number,
    required this.startSurahNumber,
    required this.startSurahName,
    required this.startVerse,
  });
}

final juzListProvider = Provider<List<JuzInfo>>((ref) {
  return List.generate(30, (index) {
    final juzNum = index + 1;
    final map = quran.getSurahAndVersesFromJuz(juzNum);
    final firstSurah = map.keys.isNotEmpty ? map.keys.first : 1;
    final firstVerse = map[firstSurah]?.isNotEmpty == true ? map[firstSurah]!.first : 1;
    return JuzInfo(
      number: juzNum,
      startSurahNumber: firstSurah,
      startSurahName: quran.getSurahName(firstSurah),
      startVerse: firstVerse,
    );
  });
});


// ─────────────────────────────────────────────────────
//  Audio player management
// ─────────────────────────────────────────────────────

enum AudioState { idle, loading, playing, paused }

class AudioPlayerState {
  final AudioState state;
  final int? currentSurah;
  final int? currentVerse;
  final Duration position;
  final Duration duration;

  const AudioPlayerState({
    this.state = AudioState.idle,
    this.currentSurah,
    this.currentVerse,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  AudioPlayerState copyWith({
    AudioState? state,
    int? currentSurah,
    int? currentVerse,
    Duration? position,
    Duration? duration,
  }) {
    return AudioPlayerState(
      state: state ?? this.state,
      currentSurah: currentSurah ?? this.currentSurah,
      currentVerse: currentVerse ?? this.currentVerse,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  AudioPlayer? _player;

  @override
  AudioPlayerState build() {
    ref.onDispose(() => _player?.dispose());
    return const AudioPlayerState();
  }

  AudioPlayer _getPlayer() {
    _player ??= AudioPlayer();
    return _player!;
  }

  Future<void> playVerse(int surah, int verse) async {
    final player = _getPlayer();
    state = state.copyWith(
      state: AudioState.loading,
      currentSurah: surah,
      currentVerse: verse,
    );

    try {
      final url = quran.getAudioURLByVerse(surah, verse);
      await player.setUrl(url);

      // Listen to position updates
      player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
      });

      player.durationStream.listen((dur) {
        if (dur != null) {
          state = state.copyWith(duration: dur);
        }
      });

      player.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          state = state.copyWith(state: AudioState.idle);
        }
      });

      await player.play();
      state = state.copyWith(state: AudioState.playing);
    } catch (e) {
      state = state.copyWith(state: AudioState.idle);
    }
  }

  Future<void> playSurah(int surah) async {
    final player = _getPlayer();
    state = state.copyWith(
      state: AudioState.loading,
      currentSurah: surah,
    );

    try {
      final url = quran.getAudioURLBySurah(surah);
      await player.setUrl(url);

      player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
      });

      player.durationStream.listen((dur) {
        if (dur != null) state = state.copyWith(duration: dur);
      });

      player.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          state = state.copyWith(state: AudioState.idle);
        }
      });

      await player.play();
      state = state.copyWith(state: AudioState.playing);
    } catch (e) {
      state = state.copyWith(state: AudioState.idle);
    }
  }

  Future<void> togglePlayPause() async {
    final player = _getPlayer();
    if (state.state == AudioState.playing) {
      await player.pause();
      state = state.copyWith(state: AudioState.paused);
    } else if (state.state == AudioState.paused) {
      await player.play();
      state = state.copyWith(state: AudioState.playing);
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    state = const AudioPlayerState();
  }

  Future<void> seekTo(Duration position) async {
    await _player?.seek(position);
  }
}

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
        AudioPlayerNotifier.new);
