import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_calculation_settings.dart';

class PrayerSettingsNotifier extends Notifier<PrayerCalculationSettings> {
  static const _prefsKey = 'neki_prayer_settings_v1';

  @override
  PrayerCalculationSettings build() {
    _loadSettings();
    return const PrayerCalculationSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefsKey);
      if (savedJson != null) {
        state = PrayerCalculationSettings.fromJson(savedJson);
      }
    } catch (e) {
      debugPrint('Error loading prayer settings: $e');
    }
  }

  Future<void> _saveSettings(PrayerCalculationSettings newSettings) async {
    state = newSettings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, newSettings.toJson());
    } catch (e) {
      debugPrint('Error saving prayer settings: $e');
    }
  }

  Future<void> setCalculationMethod(CalculationMethod method) async {
    await _saveSettings(state.copyWith(calculationMethod: method));
  }

  Future<void> setMadhab(Madhab madhab) async {
    await _saveSettings(state.copyWith(madhab: madhab));
  }

  Future<void> setHighLatitudeRule(HighLatitudeRule rule) async {
    await _saveSettings(state.copyWith(highLatitudeRule: rule));
  }

  Future<void> setOffset({
    int? fajr,
    int? sunrise,
    int? dhuhr,
    int? asr,
    int? maghrib,
    int? isha,
  }) async {
    await _saveSettings(state.copyWith(
      fajrOffset: fajr ?? state.fajrOffset,
      sunriseOffset: sunrise ?? state.sunriseOffset,
      dhuhrOffset: dhuhr ?? state.dhuhrOffset,
      asrOffset: asr ?? state.asrOffset,
      maghribOffset: maghrib ?? state.maghribOffset,
      ishaOffset: isha ?? state.ishaOffset,
    ));
  }

  Future<void> setAzanSound(String sound) async {
    await _saveSettings(state.copyWith(azanSound: sound));
  }

  Future<void> setReminderMinutes(int minutes) async {
    await _saveSettings(state.copyWith(reminderMinutes: minutes));
  }

  Future<void> toggleAlert(String prayerName) async {
    final updated = Map<String, bool>.from(state.prayerAlerts);
    updated[prayerName] = !(updated[prayerName] ?? true);
    await _saveSettings(state.copyWith(prayerAlerts: updated));
  }

  Future<void> resetToDefaults() async {
    await _saveSettings(const PrayerCalculationSettings());
  }
}

final prayerSettingsProvider =
    NotifierProvider<PrayerSettingsNotifier, PrayerCalculationSettings>(
  PrayerSettingsNotifier.new,
);
