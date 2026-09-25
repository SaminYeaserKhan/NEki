import 'dart:convert';
import 'package:adhan/adhan.dart';

/// User preferences for prayer calculations, juristic methods, offsets, and alerts.
class PrayerCalculationSettings {
  final CalculationMethod calculationMethod;
  final Madhab madhab;
  final HighLatitudeRule highLatitudeRule;
  final int fajrOffset;
  final int sunriseOffset;
  final int dhuhrOffset;
  final int asrOffset;
  final int maghribOffset;
  final int ishaOffset;
  final String azanSound; // 'makkah', 'madinah', 'alaqsa', 'takbir', 'chime', 'silent'
  final int reminderMinutes; // 0 = off, 5, 10, 15, 20 minutes before
  final Map<String, bool> prayerAlerts;

  const PrayerCalculationSettings({
    this.calculationMethod = CalculationMethod.karachi,
    this.madhab = Madhab.hanafi,
    this.highLatitudeRule = HighLatitudeRule.middle_of_the_night,
    this.fajrOffset = 0,
    this.sunriseOffset = 0,
    this.dhuhrOffset = 0,
    this.asrOffset = 0,
    this.maghribOffset = 0,
    this.ishaOffset = 0,
    this.azanSound = 'makkah',
    this.reminderMinutes = 10,
    this.prayerAlerts = const {
      'Fajr': true,
      'Sunrise': false,
      'Dhuhr': true,
      'Asr': true,
      'Maghrib': true,
      'Isha': true,
    },
  });

  CalculationParameters toCalculationParameters() {
    final params = calculationMethod.getParameters();
    params.madhab = madhab;
    params.highLatitudeRule = highLatitudeRule;
    params.adjustments.fajr = fajrOffset;
    params.adjustments.sunrise = sunriseOffset;
    params.adjustments.dhuhr = dhuhrOffset;
    params.adjustments.asr = asrOffset;
    params.adjustments.maghrib = maghribOffset;
    params.adjustments.isha = ishaOffset;
    return params;
  }

  PrayerCalculationSettings copyWith({
    CalculationMethod? calculationMethod,
    Madhab? madhab,
    HighLatitudeRule? highLatitudeRule,
    int? fajrOffset,
    int? sunriseOffset,
    int? dhuhrOffset,
    int? asrOffset,
    int? maghribOffset,
    int? ishaOffset,
    String? azanSound,
    int? reminderMinutes,
    Map<String, bool>? prayerAlerts,
  }) {
    return PrayerCalculationSettings(
      calculationMethod: calculationMethod ?? this.calculationMethod,
      madhab: madhab ?? this.madhab,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      fajrOffset: fajrOffset ?? this.fajrOffset,
      sunriseOffset: sunriseOffset ?? this.sunriseOffset,
      dhuhrOffset: dhuhrOffset ?? this.dhuhrOffset,
      asrOffset: asrOffset ?? this.asrOffset,
      maghribOffset: maghribOffset ?? this.maghribOffset,
      ishaOffset: ishaOffset ?? this.ishaOffset,
      azanSound: azanSound ?? this.azanSound,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      prayerAlerts: prayerAlerts ?? this.prayerAlerts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calculationMethod': calculationMethod.name,
      'madhab': madhab.name,
      'highLatitudeRule': highLatitudeRule.name,
      'fajrOffset': fajrOffset,
      'sunriseOffset': sunriseOffset,
      'dhuhrOffset': dhuhrOffset,
      'asrOffset': asrOffset,
      'maghribOffset': maghribOffset,
      'ishaOffset': ishaOffset,
      'azanSound': azanSound,
      'reminderMinutes': reminderMinutes,
      'prayerAlerts': prayerAlerts,
    };
  }

  factory PrayerCalculationSettings.fromMap(Map<String, dynamic> map) {
    CalculationMethod method = CalculationMethod.karachi;
    final methodName = map['calculationMethod'] as String?;
    if (methodName != null) {
      method = CalculationMethod.values.firstWhere(
        (m) => m.name == methodName,
        orElse: () => CalculationMethod.karachi,
      );
    }

    Madhab madhab = Madhab.hanafi;
    final madhabName = map['madhab'] as String?;
    if (madhabName != null) {
      madhab = Madhab.values.firstWhere(
        (m) => m.name == madhabName,
        orElse: () => Madhab.hanafi,
      );
    }

    HighLatitudeRule rule = HighLatitudeRule.middle_of_the_night;
    final ruleName = map['highLatitudeRule'] as String?;
    if (ruleName != null) {
      rule = HighLatitudeRule.values.firstWhere(
        (r) => r.name == ruleName,
        orElse: () => HighLatitudeRule.middle_of_the_night,
      );
    }

    Map<String, bool> alerts = {
      'Fajr': true,
      'Sunrise': false,
      'Dhuhr': true,
      'Asr': true,
      'Maghrib': true,
      'Isha': true,
    };
    if (map['prayerAlerts'] is Map) {
      alerts = (map['prayerAlerts'] as Map).map(
        (k, v) => MapEntry(k.toString(), v == true),
      );
    }

    return PrayerCalculationSettings(
      calculationMethod: method,
      madhab: madhab,
      highLatitudeRule: rule,
      fajrOffset: (map['fajrOffset'] as num?)?.toInt() ?? 0,
      sunriseOffset: (map['sunriseOffset'] as num?)?.toInt() ?? 0,
      dhuhrOffset: (map['dhuhrOffset'] as num?)?.toInt() ?? 0,
      asrOffset: (map['asrOffset'] as num?)?.toInt() ?? 0,
      maghribOffset: (map['maghribOffset'] as num?)?.toInt() ?? 0,
      ishaOffset: (map['ishaOffset'] as num?)?.toInt() ?? 0,
      azanSound: map['azanSound'] as String? ?? 'makkah',
      reminderMinutes: (map['reminderMinutes'] as num?)?.toInt() ?? 10,
      prayerAlerts: alerts,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PrayerCalculationSettings.fromJson(String source) =>
      PrayerCalculationSettings.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// User friendly names and descriptions for calculation methods.
extension CalculationMethodExtension on CalculationMethod {
  String get titleEn {
    switch (this) {
      case CalculationMethod.karachi:
        return 'University of Islamic Sciences, Karachi (Bangladesh & South Asia)';
      case CalculationMethod.muslim_world_league:
        return 'Muslim World League (MWL)';
      case CalculationMethod.umm_al_qura:
        return 'Umm al-Qura University, Makkah';
      case CalculationMethod.egyptian:
        return 'Egyptian General Authority of Survey';
      case CalculationMethod.north_america:
        return 'ISNA (Islamic Society of North America)';
      case CalculationMethod.dubai:
        return 'Dubai, United Arab Emirates';
      case CalculationMethod.qatar:
        return 'Ministry of Endowments & Islamic Affairs, Qatar';
      case CalculationMethod.kuwait:
        return 'Kuwait State Authority';
      case CalculationMethod.singapore:
        return 'MUIS (Singapore)';
      case CalculationMethod.turkey:
        return 'Diyanet İşleri Başkanlığı, Turkey';
      case CalculationMethod.moon_sighting_committee:
        return 'Moonsighting Committee Worldwide';
      case CalculationMethod.tehran:
        return 'Institute of Geophysics, Tehran';
      case CalculationMethod.other:
        return 'Custom / Other';
    }
  }

  String get shortNameEn {
    switch (this) {
      case CalculationMethod.karachi:
        return 'Karachi (BD/PK/India)';
      case CalculationMethod.muslim_world_league:
        return 'Muslim World League';
      case CalculationMethod.umm_al_qura:
        return 'Makkah (Umm al-Qura)';
      case CalculationMethod.egyptian:
        return 'Egyptian Authority';
      case CalculationMethod.north_america:
        return 'ISNA (North America)';
      case CalculationMethod.dubai:
        return 'Dubai (UAE)';
      case CalculationMethod.qatar:
        return 'Qatar';
      case CalculationMethod.kuwait:
        return 'Kuwait';
      case CalculationMethod.singapore:
        return 'MUIS (Singapore)';
      case CalculationMethod.turkey:
        return 'Turkey (Diyanet)';
      case CalculationMethod.moon_sighting_committee:
        return 'Moonsighting Committee';
      case CalculationMethod.tehran:
        return 'Tehran';
      case CalculationMethod.other:
        return 'Other';
    }
  }

  String get shortNameBn {
    switch (this) {
      case CalculationMethod.karachi:
        return 'করাচী (বাংলাদেশ ও দক্ষিণ এশিয়া)';
      case CalculationMethod.muslim_world_league:
        return 'মুসলিম ওয়ার্ল্ড লীগ (MWL)';
      case CalculationMethod.umm_al_qura:
        return 'মক্কা (উম্মুল কুরা, সৌদি আরব)';
      case CalculationMethod.egyptian:
        return 'মিশরীয় সাধারণ জরিপ কর্তৃপক্ষ';
      case CalculationMethod.north_america:
        return 'উত্তর আমেরিকা (ISNA)';
      case CalculationMethod.dubai:
        return 'দুবাই (সংযুক্ত আরব আমিরাত)';
      case CalculationMethod.qatar:
        return 'কাতার ধর্ম মন্ত্রণালয়';
      case CalculationMethod.kuwait:
        return 'কুয়েত ধর্ম বিষয়ক কর্তৃপক্ষ';
      case CalculationMethod.singapore:
        return 'সিঙ্গাপুর (MUIS)';
      case CalculationMethod.turkey:
        return 'তুরস্ক (দিয়ানেত)';
      case CalculationMethod.moon_sighting_committee:
        return 'মুনসাইটিং কমিটি';
      case CalculationMethod.tehran:
        return 'তেহরান (জিওফিজিক্স)';
      case CalculationMethod.other:
        return 'অন্যান্য';
    }
  }

  String get titleBn {
    switch (this) {
      case CalculationMethod.karachi:
        return 'ইসলামিক সাইন্সেস করাচি (বাংলাদেশ ও দক্ষিণ এশিয়া)';
      case CalculationMethod.muslim_world_league:
        return 'মুসলিম ওয়ার্ল্ড লিগ (MWL)';
      case CalculationMethod.umm_al_qura:
        return 'উম্মুল কুরা বিশ্ববিদ্যালয়, মক্কা';
      case CalculationMethod.egyptian:
        return 'মিশরীয় সাধারণ জরিপ কর্তৃপক্ষ';
      case CalculationMethod.north_america:
        return 'ইসলামিক সোসাইটি অব নর্থ আমেরিকা (ISNA)';
      case CalculationMethod.dubai:
        return 'দুবাই ইসলামিক কর্তৃপক্ষ';
      case CalculationMethod.qatar:
        return 'কাতার ধর্ম মন্ত্রণালয়';
      case CalculationMethod.kuwait:
        return 'কুয়েত ধর্ম বিষয়ক কর্তৃপক্ষ';
      case CalculationMethod.singapore:
        return 'মুইস (সিঙ্গাপুর)';
      case CalculationMethod.turkey:
        return 'তুরস্ক দিয়ানেত';
      case CalculationMethod.moon_sighting_committee:
        return 'মুনসাইটিং কমিটি';
      case CalculationMethod.tehran:
        return 'তেহরান জিওফিজিক্স';
      case CalculationMethod.other:
        return 'অন্যান্য';
    }
  }
}

/// User friendly names for Madhabs.
extension MadhabExtension on Madhab {
  String get titleEn {
    switch (this) {
      case Madhab.hanafi:
        return 'Hanafi (Shadow factor 2 — Later Asr)';
      case Madhab.shafi:
        return "Shafi'i, Maliki, Hanbali (Shadow factor 1 — Standard Asr)";
    }
  }

  String get titleBn {
    switch (this) {
      case Madhab.hanafi:
        return 'হানাফী (ছায়া দ্বিগুণ — আসর কিছু পরে)';
      case Madhab.shafi:
        return 'শাফেঈ, মালেকী, হাম্বলী (ছায়া সমপরিমাণ — প্রমিত আসর)';
    }
  }
}
