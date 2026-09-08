import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';


enum NekiTimeTheme {
  system,
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha
}

extension NekiTimeThemeExt on NekiTimeTheme {
  int get simulatedHour {
    switch (this) {
      case NekiTimeTheme.system:
        return DateTime.now().hour;
      case NekiTimeTheme.fajr:
        return 5;
      case NekiTimeTheme.sunrise:
        return 6;
      case NekiTimeTheme.dhuhr:
        return 12;
      case NekiTimeTheme.asr:
        return 16;
      case NekiTimeTheme.maghrib:
        return 18;
      case NekiTimeTheme.isha:
        return 20;
    }
  }

  String get label {
    switch (this) {
      case NekiTimeTheme.system: return 'System Time';
      case NekiTimeTheme.fajr: return 'Fajr Theme';
      case NekiTimeTheme.sunrise: return 'Sunrise Theme';
      case NekiTimeTheme.dhuhr: return 'Dhuhr Theme';
      case NekiTimeTheme.asr: return 'Asr Theme';
      case NekiTimeTheme.maghrib: return 'Maghrib Theme';
      case NekiTimeTheme.isha: return 'Isha Theme';
    }
  }

  IconData get icon {
    switch (this) {
      case NekiTimeTheme.system: return Icons.schedule_rounded;
      case NekiTimeTheme.fajr: return Icons.nights_stay_rounded;
      case NekiTimeTheme.sunrise: return Icons.wb_twilight_rounded;
      case NekiTimeTheme.dhuhr: return Icons.wb_sunny_rounded;
      case NekiTimeTheme.asr: return Icons.wb_cloudy_rounded;
      case NekiTimeTheme.maghrib: return Icons.brightness_6_rounded;
      case NekiTimeTheme.isha: return Icons.dark_mode_rounded;
    }
  }
}

class TimeThemeNotifier extends Notifier<NekiTimeTheme> {
  static const _key = 'neki_time_theme';

  @override
  NekiTimeTheme build() {
    _loadPersisted();
    return NekiTimeTheme.system;
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      state = NekiTimeTheme.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => NekiTimeTheme.system,
      );
    }
  }

  Future<void> setTheme(NekiTimeTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.name);
  }

  Future<void> cycle() async {
    final nextIndex = (state.index + 1) % NekiTimeTheme.values.length;
    await setTheme(NekiTimeTheme.values[nextIndex]);
  }
}

final timeThemeProvider =
    NotifierProvider<TimeThemeNotifier, NekiTimeTheme>(TimeThemeNotifier.new);

/// Provides the current simulated hour based on the selected theme.
final currentHourProvider = Provider<int>((ref) {
  final theme = ref.watch(timeThemeProvider);
  return theme.simulatedHour;
});

/// Provides Flutter's ThemeMode. We always use dark mode so that standard 
/// components (like the navigation bar) stay dark and align with our custom 
/// glassmorphic dark-green shades.
final themeProvider = Provider<ThemeMode>((ref) {
  return ThemeMode.dark;
});
