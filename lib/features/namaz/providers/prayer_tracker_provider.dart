import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_tracker_model.dart';

String _formatDateKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

// ─────────────────────────────────────────────────────────
//  Daily Prayer Tracker
// ─────────────────────────────────────────────────────────

class DailyPrayerTrackerState {
  final DateTime selectedDate;
  final DailyPrayerRecord record;
  final Map<String, DailyPrayerRecord> historyCache;

  const DailyPrayerTrackerState({
    required this.selectedDate,
    required this.record,
    this.historyCache = const {},
  });

  DailyPrayerTrackerState copyWith({
    DateTime? selectedDate,
    DailyPrayerRecord? record,
    Map<String, DailyPrayerRecord>? historyCache,
  }) {
    return DailyPrayerTrackerState(
      selectedDate: selectedDate ?? this.selectedDate,
      record: record ?? this.record,
      historyCache: historyCache ?? this.historyCache,
    );
  }
}

class DailyPrayerTrackerNotifier extends Notifier<DailyPrayerTrackerState> {
  static const _prefix = 'neki_prayer_track_';

  @override
  DailyPrayerTrackerState build() {
    final now = DateTime.now();
    final key = _formatDateKey(now);
    _loadRecordForDate(now);
    return DailyPrayerTrackerState(
      selectedDate: now,
      record: DailyPrayerRecord(dateKey: key),
    );
  }

  Future<void> _loadRecordForDate(DateTime date) async {
    final key = _formatDateKey(date);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_prefix$key');
      DailyPrayerRecord rec;
      if (jsonStr != null) {
        rec = DailyPrayerRecord.fromJson(jsonStr);
      } else {
        rec = DailyPrayerRecord(dateKey: key);
      }

      final updatedCache = Map<String, DailyPrayerRecord>.from(state.historyCache);
      updatedCache[key] = rec;

      state = state.copyWith(
        selectedDate: date,
        record: rec,
        historyCache: updatedCache,
      );
    } catch (e) {
      debugPrint('Error loading prayer record: $e');
    }
  }

  Future<void> changeDate(DateTime newDate) async {
    final key = _formatDateKey(newDate);
    if (state.historyCache.containsKey(key)) {
      state = state.copyWith(
        selectedDate: newDate,
        record: state.historyCache[key]!,
      );
    } else {
      await _loadRecordForDate(newDate);
    }
  }

  Future<void> togglePrayer(String prayerKey) async {
    final updatedRecord = state.record.toggle(prayerKey);
    final key = updatedRecord.dateKey;

    final updatedCache = Map<String, DailyPrayerRecord>.from(state.historyCache);
    updatedCache[key] = updatedRecord;

    state = state.copyWith(
      record: updatedRecord,
      historyCache: updatedCache,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', updatedRecord.toJson());
    } catch (e) {
      debugPrint('Error saving prayer toggle: $e');
    }
  }

  /// Returns the completion record for the last 7 days.
  List<DailyPrayerRecord> getLast7Days() {
    final now = DateTime.now();
    final list = <DailyPrayerRecord>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final k = _formatDateKey(day);
      list.add(state.historyCache[k] ?? DailyPrayerRecord(dateKey: k));
    }
    return list;
  }
}

final dailyPrayerTrackerProvider =
    NotifierProvider<DailyPrayerTrackerNotifier, DailyPrayerTrackerState>(
  DailyPrayerTrackerNotifier.new,
);

// ─────────────────────────────────────────────────────────
//  Qaza (Missed Prayer) Tracker
// ─────────────────────────────────────────────────────────

class QazaTrackerNotifier extends Notifier<QazaTrackerRecord> {
  static const _prefsKey = 'neki_qaza_tracker_v1';

  @override
  QazaTrackerRecord build() {
    _loadQaza();
    return const QazaTrackerRecord();
  }

  Future<void> _loadQaza() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        state = QazaTrackerRecord.fromJson(jsonStr);
      }
    } catch (e) {
      debugPrint('Error loading qaza records: $e');
    }
  }

  Future<void> _save(QazaTrackerRecord updated) async {
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, updated.toJson());
    } catch (e) {
      debugPrint('Error saving qaza records: $e');
    }
  }

  Future<void> increment(String prayerKey) async {
    await _save(state.update(prayerKey, 1));
  }

  Future<void> decrement(String prayerKey) async {
    await _save(state.update(prayerKey, -1));
  }

  Future<void> setCount(String prayerKey, int count) async {
    int clampZero(int val) => val < 0 ? 0 : val;
    final c = clampZero(count);

    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        await _save(state.copyWith(fajr: c));
        break;
      case 'dhuhr':
        await _save(state.copyWith(dhuhr: c));
        break;
      case 'asr':
        await _save(state.copyWith(asr: c));
        break;
      case 'maghrib':
        await _save(state.copyWith(maghrib: c));
        break;
      case 'isha':
        await _save(state.copyWith(isha: c));
        break;
      case 'witr':
        await _save(state.copyWith(witr: c));
        break;
    }
  }

  Future<void> resetAll() async {
    await _save(const QazaTrackerRecord());
  }
}

final qazaTrackerProvider =
    NotifierProvider<QazaTrackerNotifier, QazaTrackerRecord>(
  QazaTrackerNotifier.new,
);
