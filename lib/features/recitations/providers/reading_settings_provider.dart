import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/neural_tts_service.dart';

enum ReadingMode {
  /// Continuous scripture flow like the printed Holy Mushaf
  mushaf,

  /// Structured line-by-line verse study with translation & transliteration
  study,
}

enum ArabicScript {
  uthmanic, // Amiri Quran
  indopak,  // Scheherazade New
}

enum AudioTrackMode {
  /// Authentic Arabic studio recitation (Mishary Alafasy, Hisnul Muslim, Nawawi)
  recitation,

  /// Spoken translation speech in active language (Bangla or English)
  translation,
}

enum FontSizePreset {
  small,
  medium,
  large,
  extraLarge,
}

class ReadingSettingsState {
  final ReadingMode readingMode;
  final ArabicScript arabicScript;
  final double arabicFontSize;
  final double translationFontSize;
  final bool showArabic;
  final bool showTransliteration;
  final bool showTranslation;
  final AudioTrackMode audioTrackMode;
  final TtsVoiceGender voiceGender;

  const ReadingSettingsState({
    this.readingMode = ReadingMode.study,
    this.arabicScript = ArabicScript.uthmanic,
    this.arabicFontSize = 26.0,
    this.translationFontSize = 14.0,
    this.showArabic = true,
    this.showTransliteration = true,
    this.showTranslation = true,
    this.audioTrackMode = AudioTrackMode.recitation,
    this.voiceGender = TtsVoiceGender.female,
  });

  /// Returns true if only translations are shown.
  bool get isTranslationOnly => !showArabic && !showTransliteration && showTranslation;

  /// Returns true if only pronunciations are shown.
  bool get isPronunciationOnly => !showArabic && showTransliteration && !showTranslation;

  /// Returns true if all three elements are visible.
  bool get isAllThree => showArabic && showTransliteration && showTranslation;

  /// Returns the closest matching active font size preset.
  FontSizePreset get currentFontSizePreset {
    if (arabicFontSize <= 23.0) return FontSizePreset.small;
    if (arabicFontSize <= 28.0) return FontSizePreset.medium;
    if (arabicFontSize <= 34.0) return FontSizePreset.large;
    return FontSizePreset.extraLarge;
  }

  ReadingSettingsState copyWith({
    ReadingMode? readingMode,
    ArabicScript? arabicScript,
    double? arabicFontSize,
    double? translationFontSize,
    bool? showArabic,
    bool? showTransliteration,
    bool? showTranslation,
    AudioTrackMode? audioTrackMode,
    TtsVoiceGender? voiceGender,
  }) {
    return ReadingSettingsState(
      readingMode: readingMode ?? this.readingMode,
      arabicScript: arabicScript ?? this.arabicScript,
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      translationFontSize: translationFontSize ?? this.translationFontSize,
      showArabic: showArabic ?? this.showArabic,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      showTranslation: showTranslation ?? this.showTranslation,
      audioTrackMode: audioTrackMode ?? this.audioTrackMode,
      voiceGender: voiceGender ?? this.voiceGender,
    );
  }
}

class ReadingSettingsNotifier extends Notifier<ReadingSettingsState> {
  static const _keyMode = 'neki_reading_mode';
  static const _keyScript = 'neki_arabic_script';
  static const _keyArabicSize = 'neki_arabic_font_size';
  static const _keyTransSize = 'neki_trans_font_size';
  static const _keyShowArabic = 'neki_show_arabic';
  static const _keyShowTranslit = 'neki_show_translit';
  static const _keyShowTrans = 'neki_show_trans';
  static const _keyAudioTrackMode = 'neki_audio_track_mode';
  static const _keyVoiceGender = 'neki_voice_gender';

  @override
  ReadingSettingsState build() {
    _loadFromPrefs();
    return const ReadingSettingsState();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_keyMode);
    final scriptStr = prefs.getString(_keyScript);
    final arabicSize = prefs.getDouble(_keyArabicSize);
    final transSize = prefs.getDouble(_keyTransSize);
    final showArabic = prefs.getBool(_keyShowArabic);
    final showTranslit = prefs.getBool(_keyShowTranslit);
    final showTrans = prefs.getBool(_keyShowTrans);
    final trackModeStr = prefs.getString(_keyAudioTrackMode);
    final genderStr = prefs.getString(_keyVoiceGender);

    state = state.copyWith(
      readingMode: modeStr == 'mushaf' ? ReadingMode.mushaf : ReadingMode.study,
      arabicScript: scriptStr == 'indopak' ? ArabicScript.indopak : ArabicScript.uthmanic,
      arabicFontSize: arabicSize ?? 26.0,
      translationFontSize: transSize ?? 14.0,
      showArabic: showArabic ?? true,
      showTransliteration: showTranslit ?? true,
      showTranslation: showTrans ?? true,
      audioTrackMode: trackModeStr == AudioTrackMode.translation.name
          ? AudioTrackMode.translation
          : AudioTrackMode.recitation,
      voiceGender: genderStr == 'male' ? TtsVoiceGender.male : TtsVoiceGender.female,
    );
  }

  Future<void> setVoiceGender(TtsVoiceGender gender) async {
    state = state.copyWith(voiceGender: gender);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVoiceGender, gender == TtsVoiceGender.male ? 'male' : 'female');
  }

  Future<void> setReadingMode(ReadingMode mode) async {
    state = state.copyWith(readingMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode == ReadingMode.mushaf ? 'mushaf' : 'study');
  }

  Future<void> setArabicScript(ArabicScript script) async {
    state = state.copyWith(arabicScript: script);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyScript, script == ArabicScript.indopak ? 'indopak' : 'uthmanic');
  }

  Future<void> setArabicFontSize(double size) async {
    final clamped = size.clamp(18.0, 42.0);
    state = state.copyWith(arabicFontSize: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyArabicSize, clamped);
  }

  Future<void> setTranslationFontSize(double size) async {
    final clamped = size.clamp(11.0, 22.0);
    state = state.copyWith(translationFontSize: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTransSize, clamped);
  }

  /// Toggles Arabic visibility. Prevents hiding if both transliteration and
  /// translation are already hidden (prevents completely blank cards).
  Future<bool> toggleArabic() async {
    if (state.showArabic && !state.showTransliteration && !state.showTranslation) {
      return false; // Guard: cannot hide all three
    }
    final newVal = !state.showArabic;
    state = state.copyWith(showArabic: newVal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowArabic, newVal);
    return true;
  }

  /// Toggles Transliteration/Pronunciation visibility. Prevents hiding if both
  /// Arabic and translation are already hidden.
  Future<bool> toggleTransliteration() async {
    if (state.showTransliteration && !state.showArabic && !state.showTranslation) {
      return false; // Guard: cannot hide all three
    }
    final newVal = !state.showTransliteration;
    state = state.copyWith(showTransliteration: newVal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTranslit, newVal);
    return true;
  }

  /// Toggles Translation visibility. Prevents hiding if both Arabic and
  /// transliteration are already hidden.
  Future<bool> toggleTranslation() async {
    if (state.showTranslation && !state.showArabic && !state.showTransliteration) {
      return false; // Guard: cannot hide all three
    }
    final newVal = !state.showTranslation;
    state = state.copyWith(showTranslation: newVal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTrans, newVal);
    return true;
  }

  /// Sets a display preset (e.g. Translation Only, Pronunciation Only, Both, All Three).
  /// Enforces that at least one element is visible.
  Future<void> setDisplayPreset({
    required bool arabic,
    required bool transliteration,
    required bool translation,
  }) async {
    // If all false, fallback to translation
    final safeArabic = (!arabic && !transliteration && !translation) ? false : arabic;
    final safeTranslit = transliteration;
    final safeTrans = (!arabic && !transliteration && !translation) ? true : translation;

    state = state.copyWith(
      showArabic: safeArabic,
      showTransliteration: safeTranslit,
      showTranslation: safeTrans,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowArabic, safeArabic);
    await prefs.setBool(_keyShowTranslit, safeTranslit);
    await prefs.setBool(_keyShowTrans, safeTrans);
  }

  /// Sets audio playback track mode (Recitation vs Spoken Translation).
  Future<void> setAudioTrackMode(AudioTrackMode mode) async {
    state = state.copyWith(audioTrackMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAudioTrackMode, mode.name);
  }

  /// Toggles between Recitation and Translation audio track modes.
  Future<void> toggleAudioTrackMode() async {
    final nextMode = state.audioTrackMode == AudioTrackMode.recitation
        ? AudioTrackMode.translation
        : AudioTrackMode.recitation;
    await setAudioTrackMode(nextMode);
  }

  /// Cycles to the next font size preset (Small -> Medium -> Large -> Extra Large -> Small).
  Future<FontSizePreset> cycleFontSizePreset() async {
    final current = state.currentFontSizePreset;
    final next = switch (current) {
      FontSizePreset.small => FontSizePreset.medium,
      FontSizePreset.medium => FontSizePreset.large,
      FontSizePreset.large => FontSizePreset.extraLarge,
      FontSizePreset.extraLarge => FontSizePreset.small,
    };
    await applyFontSizePreset(next);
    return next;
  }

  /// Sets fonts to predefined proportional scale presets.
  Future<void> applyFontSizePreset(FontSizePreset preset) async {
    switch (preset) {
      case FontSizePreset.small:
        await setArabicFontSize(22.0);
        await setTranslationFontSize(12.5);
        break;
      case FontSizePreset.medium:
        await setArabicFontSize(26.0);
        await setTranslationFontSize(14.0);
        break;
      case FontSizePreset.large:
        await setArabicFontSize(32.0);
        await setTranslationFontSize(16.5);
        break;
      case FontSizePreset.extraLarge:
        await setArabicFontSize(38.0);
        await setTranslationFontSize(19.5);
        break;
    }
  }
}

final readingSettingsProvider =
    NotifierProvider<ReadingSettingsNotifier, ReadingSettingsState>(
        ReadingSettingsNotifier.new);
