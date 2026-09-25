import 'package:flutter_test/flutter_test.dart';
import 'package:neki/features/namaz/models/prayer_tracker_model.dart';

void main() {
  group('DailyPrayerRecord Model Tests', () {
    test('Initial record has zero completed prayers', () {
      const record = DailyPrayerRecord(dateKey: '2026-09-25');
      expect(record.farzCompletedCount, equals(0));
      expect(record.farzCompletionRate, equals(0.0));
      expect(record.isCompleted('fajr'), isFalse);
    });

    test('Toggling prayers updates completion counts correctly', () {
      DailyPrayerRecord record = const DailyPrayerRecord(dateKey: '2026-09-25');
      record = record.toggle('fajr');
      record = record.toggle('dhuhr');
      record = record.toggle('asr');

      expect(record.fajr, isTrue);
      expect(record.dhuhr, isTrue);
      expect(record.asr, isTrue);
      expect(record.maghrib, isFalse);
      expect(record.isha, isFalse);

      expect(record.farzCompletedCount, equals(3));
      expect(record.farzCompletionRate, closeTo(0.6, 0.001));

      // Toggle fajr off
      record = record.toggle('fajr');
      expect(record.fajr, isFalse);
      expect(record.farzCompletedCount, equals(2));
    });

    test('Sunnah and Nafl prayers track independently', () {
      DailyPrayerRecord record = const DailyPrayerRecord(dateKey: '2026-09-25');
      record = record.toggle('tahajjud');
      record = record.toggle('witr');

      expect(record.tahajjud, isTrue);
      expect(record.witr, isTrue);
      expect(record.farzCompletedCount, equals(0));
      expect(record.sunnahCompletedCount, equals(2));
    });

    test('Serialization and deserialization works seamlessly', () {
      const record = DailyPrayerRecord(
        dateKey: '2026-09-25',
        fajr: true,
        maghrib: true,
        tahajjud: true,
      );
      final json = record.toJson();
      final decoded = DailyPrayerRecord.fromJson(json);

      expect(decoded.dateKey, equals('2026-09-25'));
      expect(decoded.fajr, isTrue);
      expect(decoded.dhuhr, isFalse);
      expect(decoded.maghrib, isTrue);
      expect(decoded.tahajjud, isTrue);
    });
  });

  group('QazaTrackerRecord Model Tests', () {
    test('Default Qaza record has zero counts', () {
      const qaza = QazaTrackerRecord();
      expect(qaza.totalQaza, equals(0));
      expect(qaza.getCount('fajr'), equals(0));
    });

    test('Increment and decrement adjust counts and clamp at 0', () {
      QazaTrackerRecord qaza = const QazaTrackerRecord();
      qaza = qaza.update('fajr', 5);
      qaza = qaza.update('dhuhr', 2);

      expect(qaza.fajr, equals(5));
      expect(qaza.dhuhr, equals(2));
      expect(qaza.totalQaza, equals(7));

      // Decrement by 1
      qaza = qaza.update('fajr', -1);
      expect(qaza.fajr, equals(4));

      // Decrement past 0 clamps to 0
      qaza = qaza.update('dhuhr', -10);
      expect(qaza.dhuhr, equals(0));
    });

    test('Serialization of QazaTrackerRecord', () {
      const qaza = QazaTrackerRecord(
        fajr: 10,
        dhuhr: 8,
        asr: 12,
        maghrib: 5,
        isha: 15,
        witr: 15,
      );
      final json = qaza.toJson();
      final decoded = QazaTrackerRecord.fromJson(json);

      expect(decoded.totalQaza, equals(65));
      expect(decoded.isha, equals(15));
    });
  });
}
