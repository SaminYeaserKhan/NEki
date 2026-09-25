import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/hijri_helper.dart';
import '../models/prayer_calculation_settings.dart';
import '../models/prayer_location.dart';
import 'prayer_location_provider.dart';
import 'prayer_settings_provider.dart';

/// Full calculated schedule for a specific day.
class PrayerDaySchedule {
  final DateTime date;
  final PrayerLocation location;
  final HijriDate hijriDate;
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime tahajjud;
  final DateTime duha;
  final DateTime midnight;
  final double qiblaDirection;

  const PrayerDaySchedule({
    required this.date,
    required this.location,
    required this.hijriDate,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.tahajjud,
    required this.duha,
    required this.midnight,
    required this.qiblaDirection,
  });

  DateTime? timeFor(String prayerKey) {
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        return fajr;
      case 'sunrise':
        return sunrise;
      case 'dhuhr':
        return dhuhr;
      case 'asr':
        return asr;
      case 'maghrib':
        return maghrib;
      case 'isha':
        return isha;
      case 'tahajjud':
        return tahajjud;
      case 'duha':
      case 'ishraq':
        return duha;
      default:
        return null;
    }
  }
}

/// Helper to compute schedule for any date given location & settings.
PrayerDaySchedule calculatePrayerSchedule({
  required DateTime date,
  required PrayerLocation location,
  required PrayerCalculationSettings settings,
}) {
  final coordinates = Coordinates(location.latitude, location.longitude);
  final params = settings.toCalculationParameters();
  final dateComponents = DateComponents.from(date);

  final prayerTimes = PrayerTimes(coordinates, dateComponents, params);
  final sunnahTimes = SunnahTimes(prayerTimes);
  final qibla = Qibla(coordinates);
  final hijri = HijriDate.fromGregorian(date);

  // Duha / Ishraq begins ~15 minutes after sunrise
  final duhaTime = prayerTimes.sunrise.add(const Duration(minutes: 15));

  return PrayerDaySchedule(
    date: date,
    location: location,
    hijriDate: hijri,
    fajr: prayerTimes.fajr,
    sunrise: prayerTimes.sunrise,
    dhuhr: prayerTimes.dhuhr,
    asr: prayerTimes.asr,
    maghrib: prayerTimes.maghrib,
    isha: prayerTimes.isha,
    tahajjud: sunnahTimes.lastThirdOfTheNight,
    duha: duhaTime,
    midnight: sunnahTimes.middleOfTheNight,
    qiblaDirection: qibla.direction,
  );
}

/// Live waqt data for real-time tickers and home display.
class WaqtData {
  final String dateDisplay;
  final String? hijriDisplay;
  final DateTime currentTime;
  final String currentWaqtName;
  final DateTime currentWaqtEnd;
  final String nextWaqtName;
  final DateTime nextWaqtStart;
  final DateTime nextWaqtEnd;
  final double progressPercent; // 0.0 to 1.0 through current waqt
  final String locationDisplay;
  final bool isAutoGps;
  final PrayerDaySchedule todaySchedule;
  final bool isMakruhTime;
  final String? makruhReason;

  const WaqtData({
    required this.dateDisplay,
    this.hijriDisplay,
    required this.currentTime,
    required this.currentWaqtName,
    required this.currentWaqtEnd,
    required this.nextWaqtName,
    required this.nextWaqtStart,
    required this.nextWaqtEnd,
    this.progressPercent = 0.0,
    required this.locationDisplay,
    this.isAutoGps = false,
    required this.todaySchedule,
    this.isMakruhTime = false,
    this.makruhReason,
  });
}

/// Computes monthly schedule for calendar view.
final monthlyScheduleProvider =
    Provider.family<List<PrayerDaySchedule>, DateTime>((ref, monthDate) {
  final location = ref.watch(prayerLocationProvider).location;
  final settings = ref.watch(prayerSettingsProvider);

  final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
  final list = <PrayerDaySchedule>[];

  for (int d = 1; d <= daysInMonth; d++) {
    final day = DateTime(monthDate.year, monthDate.month, d);
    list.add(calculatePrayerSchedule(
      date: day,
      location: location,
      settings: settings,
    ));
  }

  return list;
});

/// Today's schedule provider.
final todayScheduleProvider = Provider<PrayerDaySchedule>((ref) {
  final location = ref.watch(prayerLocationProvider).location;
  final settings = ref.watch(prayerSettingsProvider);
  return calculatePrayerSchedule(
    date: DateTime.now(),
    location: location,
    settings: settings,
  );
});

/// Helper to compute live WaqtData for a given moment, location, and calculation settings.
WaqtData calculateLiveWaqtData({
  DateTime? now,
  required PrayerLocation location,
  required PrayerCalculationSettings settings,
}) {
  final currentTime = now ?? DateTime.now();
  final todaySchedule = calculatePrayerSchedule(
    date: currentTime,
    location: location,
    settings: settings,
  );

  final fajr = todaySchedule.fajr;
  final sunrise = todaySchedule.sunrise;
  final dhuhr = todaySchedule.dhuhr;
  final asr = todaySchedule.asr;
  final maghrib = todaySchedule.maghrib;
  final isha = todaySchedule.isha;

  // Tomorrow's Fajr for late-night transitions
  final tomorrowSchedule = calculatePrayerSchedule(
    date: currentTime.add(const Duration(days: 1)),
    location: location,
    settings: settings,
  );
  final tomorrowFajr = tomorrowSchedule.fajr;

  // Yesterday's Isha for early-morning transitions
  final yesterdaySchedule = calculatePrayerSchedule(
    date: currentTime.subtract(const Duration(days: 1)),
    location: location,
    settings: settings,
  );
  final yesterdayIsha = yesterdaySchedule.isha;

  String currentName;
  DateTime currentStart;
  DateTime currentEnd;
  String nextName;
  DateTime nextStart;
  DateTime nextEnd;

  if (currentTime.isBefore(fajr)) {
    // Midnight to Fajr (Late night / Tahajjud / Isha extension)
    currentName = 'Isha';
    currentStart = yesterdayIsha;
    currentEnd = fajr;
    nextName = 'Fajr';
    nextStart = fajr;
    nextEnd = sunrise;
  } else if (currentTime.isBefore(sunrise)) {
    // Fajr
    currentName = 'Fajr';
    currentStart = fajr;
    currentEnd = sunrise;
    nextName = 'Dhuhr';
    nextStart = dhuhr;
    nextEnd = asr;
  } else if (currentTime.isBefore(dhuhr)) {
    // Post-Sunrise / Duha
    currentName = 'Post-Sunrise';
    currentStart = sunrise;
    currentEnd = dhuhr;
    nextName = 'Dhuhr';
    nextStart = dhuhr;
    nextEnd = asr;
  } else if (currentTime.isBefore(asr)) {
    // Dhuhr
    currentName = 'Dhuhr';
    currentStart = dhuhr;
    currentEnd = asr;
    nextName = 'Asr';
    nextStart = asr;
    nextEnd = maghrib;
  } else if (currentTime.isBefore(maghrib)) {
    // Asr
    currentName = 'Asr';
    currentStart = asr;
    currentEnd = maghrib;
    nextName = 'Maghrib';
    nextStart = maghrib;
    nextEnd = isha;
  } else if (currentTime.isBefore(isha)) {
    // Maghrib
    currentName = 'Maghrib';
    currentStart = maghrib;
    currentEnd = isha;
    nextName = 'Isha';
    nextStart = isha;
    nextEnd = tomorrowFajr;
  } else {
    // Isha (post-Isha until midnight)
    currentName = 'Isha';
    currentStart = isha;
    currentEnd = tomorrowFajr;
    nextName = 'Fajr';
    nextStart = tomorrowFajr;
    nextEnd = tomorrowSchedule.sunrise;
  }

  // Calculate progress percentage
  double progress = 0.0;
  final totalDuration = currentEnd.difference(currentStart).inMilliseconds;
  if (totalDuration > 0) {
    final elapsed = currentTime.difference(currentStart).inMilliseconds;
    progress = (elapsed / totalDuration).clamp(0.0, 1.0);
  }

  // Check for Makruh / Prohibited prayer times
  bool isMakruh = false;
  String? makruhReason;

  // 1. Sunrise window: from sunrise until 15 minutes after
  if (currentTime.isAfter(sunrise) &&
      currentTime.isBefore(sunrise.add(const Duration(minutes: 15)))) {
    isMakruh = true;
    makruhReason = 'Sun is rising (Salah prohibited)';
  }
  // 2. Midday zenith / Zawal: 10 mins before Dhuhr until Dhuhr enters
  else if (currentTime.isAfter(dhuhr.subtract(const Duration(minutes: 10))) &&
      currentTime.isBefore(dhuhr)) {
    isMakruh = true;
    makruhReason = 'Midday Zenith / Zawal (Salah prohibited)';
  }
  // 3. Sunset window: 15 mins before Maghrib until Maghrib begins
  else if (currentTime.isAfter(maghrib.subtract(const Duration(minutes: 15))) &&
      currentTime.isBefore(maghrib)) {
    isMakruh = true;
    makruhReason = 'Sun is setting (Voluntary Salah prohibited)';
  }

  final dateDisplay = DateFormat('EEEE, d MMMM yyyy').format(currentTime);
  final hijriDisplay = todaySchedule.hijriDate.formatEn();

  return WaqtData(
    dateDisplay: dateDisplay,
    hijriDisplay: hijriDisplay,
    currentTime: currentTime,
    currentWaqtName: currentName,
    currentWaqtEnd: currentEnd,
    nextWaqtName: nextName,
    nextWaqtStart: nextStart,
    nextWaqtEnd: nextEnd,
    progressPercent: progress,
    locationDisplay: location.displayName,
    isAutoGps: location.isAutoGps,
    todaySchedule: todaySchedule,
    isMakruhTime: isMakruh,
    makruhReason: makruhReason,
  );
}

/// Live stream provider that ticks every second and emits comprehensive WaqtData.
final liveWaqtProvider = StreamProvider<WaqtData>((ref) async* {
  final locationState = ref.watch(prayerLocationProvider);
  final location = locationState.location;
  final settings = ref.watch(prayerSettingsProvider);

  WaqtData compute() => calculateLiveWaqtData(
        location: location,
        settings: settings,
      );

  // Emit initial value immediately
  yield compute();

  yield* Stream.periodic(const Duration(seconds: 1), (_) => compute());
});
