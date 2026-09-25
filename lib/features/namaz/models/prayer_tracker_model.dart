import 'dart:convert';

/// Tracks prayers completed for a specific Gregorian day.
class DailyPrayerRecord {
  final String dateKey; // Format: 'YYYY-MM-DD'
  final bool fajr;
  final bool dhuhr;
  final bool asr;
  final bool maghrib;
  final bool isha;
  final bool tahajjud;
  final bool duha;
  final bool witr;

  const DailyPrayerRecord({
    required this.dateKey,
    this.fajr = false,
    this.dhuhr = false,
    this.asr = false,
    this.maghrib = false,
    this.isha = false,
    this.tahajjud = false,
    this.duha = false,
    this.witr = false,
  });

  int get farzCompletedCount {
    int count = 0;
    if (fajr) count++;
    if (dhuhr) count++;
    if (asr) count++;
    if (maghrib) count++;
    if (isha) count++;
    return count;
  }

  int get sunnahCompletedCount {
    int count = 0;
    if (tahajjud) count++;
    if (duha) count++;
    if (witr) count++;
    return count;
  }

  double get farzCompletionRate => farzCompletedCount / 5.0;

  bool isCompleted(String prayerKey) {
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        return fajr;
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
      case 'witr':
        return witr;
      default:
        return false;
    }
  }

  DailyPrayerRecord copyWith({
    bool? fajr,
    bool? dhuhr,
    bool? asr,
    bool? maghrib,
    bool? isha,
    bool? tahajjud,
    bool? duha,
    bool? witr,
  }) {
    return DailyPrayerRecord(
      dateKey: dateKey,
      fajr: fajr ?? this.fajr,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      tahajjud: tahajjud ?? this.tahajjud,
      duha: duha ?? this.duha,
      witr: witr ?? this.witr,
    );
  }

  DailyPrayerRecord toggle(String prayerKey) {
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        return copyWith(fajr: !fajr);
      case 'dhuhr':
        return copyWith(dhuhr: !dhuhr);
      case 'asr':
        return copyWith(asr: !asr);
      case 'maghrib':
        return copyWith(maghrib: !maghrib);
      case 'isha':
        return copyWith(isha: !isha);
      case 'tahajjud':
        return copyWith(tahajjud: !tahajjud);
      case 'duha':
      case 'ishraq':
        return copyWith(duha: !duha);
      case 'witr':
        return copyWith(witr: !witr);
      default:
        return this;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'fajr': fajr,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
      'tahajjud': tahajjud,
      'duha': duha,
      'witr': witr,
    };
  }

  factory DailyPrayerRecord.fromMap(Map<String, dynamic> map) {
    return DailyPrayerRecord(
      dateKey: map['dateKey'] as String,
      fajr: map['fajr'] as bool? ?? false,
      dhuhr: map['dhuhr'] as bool? ?? false,
      asr: map['asr'] as bool? ?? false,
      maghrib: map['maghrib'] as bool? ?? false,
      isha: map['isha'] as bool? ?? false,
      tahajjud: map['tahajjud'] as bool? ?? false,
      duha: map['duha'] as bool? ?? false,
      witr: map['witr'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DailyPrayerRecord.fromJson(String source) =>
      DailyPrayerRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Tracks missed prayers (Qaza-e-Umri) counter.
class QazaTrackerRecord {
  final int fajr;
  final int dhuhr;
  final int asr;
  final int maghrib;
  final int isha;
  final int witr;

  const QazaTrackerRecord({
    this.fajr = 0,
    this.dhuhr = 0,
    this.asr = 0,
    this.maghrib = 0,
    this.isha = 0,
    this.witr = 0,
  });

  int get totalQaza => fajr + dhuhr + asr + maghrib + isha + witr;

  int getCount(String prayerKey) {
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        return fajr;
      case 'dhuhr':
        return dhuhr;
      case 'asr':
        return asr;
      case 'maghrib':
        return maghrib;
      case 'isha':
        return isha;
      case 'witr':
        return witr;
      default:
        return 0;
    }
  }

  QazaTrackerRecord update(String prayerKey, int delta) {
    int clampZero(int val) => val < 0 ? 0 : val;

    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        return copyWith(fajr: clampZero(fajr + delta));
      case 'dhuhr':
        return copyWith(dhuhr: clampZero(dhuhr + delta));
      case 'asr':
        return copyWith(asr: clampZero(asr + delta));
      case 'maghrib':
        return copyWith(maghrib: clampZero(maghrib + delta));
      case 'isha':
        return copyWith(isha: clampZero(isha + delta));
      case 'witr':
        return copyWith(witr: clampZero(witr + delta));
      default:
        return this;
    }
  }

  QazaTrackerRecord copyWith({
    int? fajr,
    int? dhuhr,
    int? asr,
    int? maghrib,
    int? isha,
    int? witr,
  }) {
    return QazaTrackerRecord(
      fajr: fajr ?? this.fajr,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      witr: witr ?? this.witr,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fajr': fajr,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
      'witr': witr,
    };
  }

  factory QazaTrackerRecord.fromMap(Map<String, dynamic> map) {
    return QazaTrackerRecord(
      fajr: (map['fajr'] as num?)?.toInt() ?? 0,
      dhuhr: (map['dhuhr'] as num?)?.toInt() ?? 0,
      asr: (map['asr'] as num?)?.toInt() ?? 0,
      maghrib: (map['maghrib'] as num?)?.toInt() ?? 0,
      isha: (map['isha'] as num?)?.toInt() ?? 0,
      witr: (map['witr'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory QazaTrackerRecord.fromJson(String source) =>
      QazaTrackerRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
