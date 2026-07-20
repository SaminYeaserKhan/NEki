import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────
//  12 / 24-hour toggle (persisted via Riverpod)
// ─────────────────────────────────────────────────────────

class Is24HourNotifier extends Notifier<bool> {
  @override
  bool build() => false; // default: 12-hour format

  void toggle() => state = !state;
}

final is24HourProvider =
    NotifierProvider<Is24HourNotifier, bool>(Is24HourNotifier.new);

// ─────────────────────────────────────────────────────────
//  Data model for the live waqt display
// ─────────────────────────────────────────────────────────

class WaqtData {
  /// Gregorian date (e.g. "Wednesday, 18 June 2026")
  final String dateDisplay;

  /// Hijri date (e.g. "22 Dhul-Qi'dah 1448")
  final String? hijriDisplay;

  /// Current wall-clock time.
  final DateTime currentTime;

  /// Name of the current waqt period.
  final String currentWaqtName;

  /// When the current waqt ends.
  final DateTime currentWaqtEnd;

  /// Name of the next waqt.
  final String nextWaqtName;

  /// When the next waqt starts.
  final DateTime nextWaqtStart;

  /// When the next waqt ends.
  final DateTime nextWaqtEnd;

  WaqtData({
    required this.dateDisplay,
    this.hijriDisplay,
    required this.currentTime,
    required this.currentWaqtName,
    required this.currentWaqtEnd,
    required this.nextWaqtName,
    required this.nextWaqtStart,
    required this.nextWaqtEnd,
  });
}

// ─────────────────────────────────────────────────────────
//  GPS helper
// ─────────────────────────────────────────────────────────

Future<Position> _determinePosition() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) throw Exception('Location services are disabled.');

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied.');
  }

  return await Geolocator.getCurrentPosition();
}

// ─────────────────────────────────────────────────────────
//  Raw API response (timings + hijri date)
// ─────────────────────────────────────────────────────────

class _PrayerApiData {
  final Map<String, dynamic> timings;
  final String? hijriDisplay;

  _PrayerApiData({required this.timings, this.hijriDisplay});
}

final rawPrayerProvider = FutureProvider<_PrayerApiData>((ref) async {
  final position = await _determinePosition();

  final url = Uri.parse(
    'https://api.aladhan.com/v1/timings'
    '?latitude=${position.latitude}'
    '&longitude=${position.longitude}'
    '&method=2',
  );

  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('Failed to load prayer times');
  }

  final data = jsonDecode(response.body)['data'];
  final timings = data['timings'] as Map<String, dynamic>;

  // Extract Hijri date if available.
  String? hijri;
  try {
    final h = data['date']['hijri'];
    final day = h['day'];
    final month = h['month']['en'];
    final year = h['year'];
    hijri = '$day $month $year';
  } catch (_) {
    // Non-critical — gracefully degrade.
  }

  return _PrayerApiData(timings: timings, hijriDisplay: hijri);
});

// ─────────────────────────────────────────────────────────
//  Live engine — ticks every second
// ─────────────────────────────────────────────────────────

final liveWaqtProvider = StreamProvider<WaqtData>((ref) async* {
  final apiData = await ref.watch(rawPrayerProvider.future);
  final timings = apiData.timings;

  yield* Stream.periodic(const Duration(seconds: 1), (_) {
    final now = DateTime.now();

    DateTime parseTime(String key) {
      final parts = (timings[key] as String).split(':');
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    final fajr = parseTime('Fajr');
    final sunrise = parseTime('Sunrise');
    final dhuhr = parseTime('Dhuhr');
    final asr = parseTime('Asr');
    final maghrib = parseTime('Maghrib');
    final isha = parseTime('Isha');

    String currentName = '';
    DateTime currentEnd = now;
    String nextName = '';
    DateTime nextStart = now;
    DateTime nextEnd = now;

    if (now.isAfter(fajr) && now.isBefore(sunrise)) {
      currentName = 'Fajr';
      currentEnd = sunrise;
      nextName = 'Dhuhr';
      nextStart = dhuhr;
      nextEnd = asr;
    } else if (now.isAfter(sunrise) && now.isBefore(dhuhr)) {
      currentName = 'Post-Sunrise';
      currentEnd = dhuhr;
      nextName = 'Dhuhr';
      nextStart = dhuhr;
      nextEnd = asr;
    } else if (now.isAfter(dhuhr) && now.isBefore(asr)) {
      currentName = 'Dhuhr';
      currentEnd = asr;
      nextName = 'Asr';
      nextStart = asr;
      nextEnd = maghrib;
    } else if (now.isAfter(asr) && now.isBefore(maghrib)) {
      currentName = 'Asr';
      currentEnd = maghrib;
      nextName = 'Maghrib';
      nextStart = maghrib;
      nextEnd = isha;
    } else if (now.isAfter(maghrib) && now.isBefore(isha)) {
      currentName = 'Maghrib';
      currentEnd = isha;
      nextName = 'Isha';
      nextStart = isha;
      nextEnd = fajr.add(const Duration(days: 1));
    } else {
      currentName = 'Isha';
      currentEnd = fajr.add(const Duration(days: 1));
      nextName = 'Fajr';
      nextStart = currentEnd;
      nextEnd = sunrise.add(const Duration(days: 1));
    }

    final dateDisplay = DateFormat('EEEE, d MMMM yyyy').format(now);

    return WaqtData(
      dateDisplay: dateDisplay,
      hijriDisplay: apiData.hijriDisplay,
      currentTime: now,
      currentWaqtName: currentName,
      currentWaqtEnd: currentEnd,
      nextWaqtName: nextName,
      nextWaqtStart: nextStart,
      nextWaqtEnd: nextEnd,
    );
  });
});