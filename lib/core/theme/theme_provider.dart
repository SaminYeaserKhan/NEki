import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted theme mode managed by Riverpod.
///
/// Usage:
/// ```dart
/// // Read the current mode
/// final mode = ref.watch(themeProvider);
///
/// // Toggle dark mode
/// ref.read(themeProvider.notifier).setMode(ThemeMode.dark);
/// ```
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'neki_theme_mode';

  @override
  ThemeMode build() {
    // Load persisted preference asynchronously.
    _loadPersisted();
    return ThemeMode.system; // initial default
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
    }
  }

  /// Sets the theme mode and persists it.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Cycles through system → light → dark.
  Future<void> cycle() async {
    switch (state) {
      case ThemeMode.system:
        await setMode(ThemeMode.light);
      case ThemeMode.light:
        await setMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setMode(ThemeMode.system);
    }
  }

  /// Toggles between light and dark (ignoring system).
  Future<void> toggle() async {
    await setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Global theme mode provider.
final themeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
