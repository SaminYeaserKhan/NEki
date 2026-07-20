import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app languages.
enum AppLocale { bangla, english }

/// Manages the global app locale with persistence.
class LocaleNotifier extends Notifier<AppLocale> {
  static const _key = 'neki_app_locale';

  @override
  AppLocale build() {
    _loadPersisted();
    return AppLocale.bangla; // Default: Bangla
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'english') state = AppLocale.english;
  }

  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.name);
  }

  Future<void> toggle() async {
    await setLocale(
      state == AppLocale.bangla ? AppLocale.english : AppLocale.bangla,
    );
  }
}

/// Global locale provider.
final localeProvider =
    NotifierProvider<LocaleNotifier, AppLocale>(LocaleNotifier.new);
