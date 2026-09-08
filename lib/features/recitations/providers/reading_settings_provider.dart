import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class ReadingSettingsState {
  final ReadingMode readingMode;
  final ArabicScript arabicScript;
  final double arabicFontSize;
  final double translationFontSize;
  final bool showTransliteration;
  final bool showTranslation;

  const ReadingSettingsState({
    this.readingMode = ReadingMode.study,
    this.arabicScript = ArabicScript.uthmanic,
    this.arabicFontSize = 26.0,
    this.translationFontSize = 14.0,
    this.showTransliteration = true,
    this.showTranslation = true,
  });

  ReadingSettingsState copyWith({
    ReadingMode? readingMode,
    ArabicScript? arabicScript,
    double? arabicFontSize,
    double? translationFontSize,
    bool? showTransliteration,
    bool? showTranslation,
  }) {
    return ReadingSettingsState(
      readingMode: readingMode ?? this.readingMode,
      arabicScript: arabicScript ?? this.arabicScript,
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      translationFontSize: translationFontSize ?? this.translationFontSize,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      showTranslation: showTranslation ?? this.showTranslation,
    );
  }
}

class ReadingSettingsNotifier extends Notifier<ReadingSettingsState> {
  static const _keyMode = 'neki_reading_mode';
  static const _keyScript = 'neki_arabic_script';
  static const _keyArabicSize = 'neki_arabic_font_size';
  static const _keyTransSize = 'neki_trans_font_size';
  static const _keyShowTranslit = 'neki_show_translit';
  static const _keyShowTrans = 'neki_show_trans';

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
    final showTranslit = prefs.getBool(_keyShowTranslit);
    final showTrans = prefs.getBool(_keyShowTrans);

    state = state.copyWith(
      readingMode: modeStr == 'mushaf' ? ReadingMode.mushaf : ReadingMode.study,
      arabicScript: scriptStr == 'indopak' ? ArabicScript.indopak : ArabicScript.uthmanic,
      arabicFontSize: arabicSize ?? 26.0,
      translationFontSize: transSize ?? 14.0,
      showTransliteration: showTranslit ?? true,
      showTranslation: showTrans ?? true,
    );
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

  Future<void> toggleTransliteration() async {
    final newVal = !state.showTransliteration;
    state = state.copyWith(showTransliteration: newVal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTranslit, newVal);
  }

  Future<void> toggleTranslation() async {
    final newVal = !state.showTranslation;
    state = state.copyWith(showTranslation: newVal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTrans, newVal);
  }
}

final readingSettingsProvider =
    NotifierProvider<ReadingSettingsNotifier, ReadingSettingsState>(
        ReadingSettingsNotifier.new);
