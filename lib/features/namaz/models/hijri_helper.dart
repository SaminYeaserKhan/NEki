/// Lightweight, accurate astronomical Gregorian to Hijri calendar converter.
class HijriDate {
  final int day;
  final int month;
  final int year;

  const HijriDate({
    required this.day,
    required this.month,
    required this.year,
  });

  static const List<String> monthNamesEn = [
    'Muharram',
    'Safar',
    "Rabi' al-Awwal",
    "Rabi' al-Thani",
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    "Sha'ban",
    'Ramadan',
    'Shawwal',
    "Dhu al-Qi'dah",
    'Dhu al-Hijjah',
  ];

  static const List<String> monthNamesBn = [
    'মুহাররম',
    'সফর',
    'রবিউল আউয়াল',
    'রবিউস সানি',
    'জমাদিউল আউয়াল',
    'জমাদিউস সানি',
    'রজব',
    'শা\'বান',
    'রমজান',
    'শাওয়াল',
    'জিলকদ',
    'জিলহজ',
  ];

  String get monthNameEn =>
      (month >= 1 && month <= 12) ? monthNamesEn[month - 1] : '';

  String get monthNameBn =>
      (month >= 1 && month <= 12) ? monthNamesBn[month - 1] : '';

  String formatEn() => '$day $monthNameEn $year AH';

  String formatBn() {
    final bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String toBn(int num) {
      return num.toString().split('').map((char) {
        final d = int.tryParse(char);
        return d != null ? bnDigits[d] : char;
      }).join();
    }

    return '${toBn(day)} $monthNameBn ${toBn(year)} হিজরি';
  }

  /// Converts a Gregorian DateTime to approximate Lunar Hijri Date.
  /// Uses the standard astronomical Julian Day Number algorithm.
  factory HijriDate.fromGregorian(DateTime date) {
    int y = date.year;
    int m = date.month;
    int d = date.day;

    if (m < 3) {
      y -= 1;
      m += 12;
    }

    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    final jd = (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524.5;

    // Islamic epoch Julian Day Number is 1948439.5
    final z = jd - 1948439.5;
    final cyc = (z / 10631).floor();
    final r = z - 10631 * cyc;
    final j = ((r - 0.5) / 354.36667).floor();
    final yH = 30 * cyc + j;
    final r2 = r - ((j * 354.36667) + 0.5).floor();
    final mH = (((r2 - 0.5) / 29.5).floor()).clamp(0, 11) + 1;
    final dH = (r2 - ((mH - 1) * 29.5) + 0.5).floor().clamp(1, 30);

    return HijriDate(day: dH, month: mH, year: yH);
  }
}
