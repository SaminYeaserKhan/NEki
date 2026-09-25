import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/namaz/models/hijri_helper.dart';
import 'package:neki/features/namaz/models/prayer_calculation_settings.dart';
import 'package:neki/features/namaz/models/prayer_location.dart';
import 'package:neki/features/namaz/providers/prayer_schedule_provider.dart';

void main() {
  group('Prayer Location & Offline Cities Tests', () {
    test('Default location is Dhaka, Bangladesh', () {
      const loc = PrayerLocation.defaultLocation;
      expect(loc.cityName, 'Dhaka');
      expect(loc.countryName, 'Bangladesh');
      expect(loc.latitude, closeTo(23.8103, 0.001));
      expect(loc.longitude, closeTo(90.4125, 0.001));
    });

    test('Nearest offline city matches accurately', () {
      // Coordinates close to Chittagong (22.35, 91.78)
      final nearestCtg = findNearestOfflineCity(22.36, 91.79);
      expect(nearestCtg.cityName, 'Chittagong');

      // Coordinates close to Makkah (21.42, 39.82)
      final nearestMakkah = findNearestOfflineCity(21.43, 39.81);
      expect(nearestMakkah.cityName, 'Makkah');
    });

    test('Serialization and deserialization of PrayerLocation', () {
      const loc = PrayerLocation(
        cityName: 'Sylhet',
        countryName: 'Bangladesh',
        latitude: 24.8949,
        longitude: 91.8687,
        isAutoGps: true,
      );
      final json = loc.toJson();
      final decoded = PrayerLocation.fromJson(json);

      expect(decoded.cityName, 'Sylhet');
      expect(decoded.countryName, 'Bangladesh');
      expect(decoded.isAutoGps, isTrue);
    });
  });

  group('Prayer Calculation Engine Tests', () {
    final dhaka = const PrayerLocation(
      cityName: 'Dhaka',
      countryName: 'Bangladesh',
      latitude: 23.8103,
      longitude: 90.4125,
    );
    final testDate = DateTime(2026, 9, 25);

    test('Calculates valid non-null prayer times for Dhaka', () {
      const settings = PrayerCalculationSettings(
        calculationMethod: CalculationMethod.karachi,
        madhab: Madhab.hanafi,
      );

      final schedule = calculatePrayerSchedule(
        date: testDate,
        location: dhaka,
        settings: settings,
      );

      expect(schedule.fajr.isBefore(schedule.sunrise), isTrue);
      expect(schedule.sunrise.isBefore(schedule.dhuhr), isTrue);
      expect(schedule.dhuhr.isBefore(schedule.asr), isTrue);
      expect(schedule.asr.isBefore(schedule.maghrib), isTrue);
      expect(schedule.maghrib.isBefore(schedule.isha), isTrue);

      // Qibla direction for Dhaka is roughly 277-278 degrees West
      expect(schedule.qiblaDirection, closeTo(277.5, 2.0));

      // Sunnah & Special times
      expect(schedule.duha.isAfter(schedule.sunrise), isTrue);
      expect(schedule.tahajjud.isAfter(schedule.midnight), isTrue);
    });

    test('Hanafi Asr is later than Shafi Asr', () {
      const hanafiSettings = PrayerCalculationSettings(
        calculationMethod: CalculationMethod.karachi,
        madhab: Madhab.hanafi,
      );
      const shafiSettings = PrayerCalculationSettings(
        calculationMethod: CalculationMethod.karachi,
        madhab: Madhab.shafi,
      );

      final hanafiSched = calculatePrayerSchedule(
        date: testDate,
        location: dhaka,
        settings: hanafiSettings,
      );
      final shafiSched = calculatePrayerSchedule(
        date: testDate,
        location: dhaka,
        settings: shafiSettings,
      );

      expect(hanafiSched.asr.isAfter(shafiSched.asr), isTrue);
    });

    test('Manual minute adjustments shift prayer times accurately', () {
      const regularSettings = PrayerCalculationSettings();
      const adjustedSettings = PrayerCalculationSettings(
        fajrOffset: 5,
        maghribOffset: -3,
      );

      final regular = calculatePrayerSchedule(
        date: testDate,
        location: dhaka,
        settings: regularSettings,
      );
      final adjusted = calculatePrayerSchedule(
        date: testDate,
        location: dhaka,
        settings: adjustedSettings,
      );

      expect(
        adjusted.fajr.difference(regular.fajr).inMinutes,
        equals(5),
      );
      expect(
        adjusted.maghrib.difference(regular.maghrib).inMinutes,
        equals(-3),
      );
    });
  });

  group('Hijri Date Converter Tests', () {
    test('Converts Gregorian date to valid Hijri components', () {
      final hijri = HijriDate.fromGregorian(DateTime(2026, 9, 25));

      expect(hijri.day, inInclusiveRange(1, 30));
      expect(hijri.month, inInclusiveRange(1, 12));
      expect(hijri.year, inInclusiveRange(1447, 1449));

      expect(hijri.formatEn(), contains('AH'));
      expect(hijri.formatBn(), contains('হিজরি'));
    });
  });
}
