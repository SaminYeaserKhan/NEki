import 'locale_provider.dart';

/// All user-facing strings in both English and Bangla.
///
/// Usage:
/// ```dart
/// final locale = ref.watch(localeProvider);
/// final s = S.of(locale);
/// Text(s.goodMorning);
/// ```
class S {
  final AppLocale _locale;
  const S._(this._locale);

  factory S.of(AppLocale locale) => S._(locale);

  bool get isBangla => _locale == AppLocale.bangla;

  // ── Greetings ──
  String get assalamuAlaikum =>
      isBangla ? 'আসসালামু আলাইকুম' : 'Assalamu Alaikum';
  String get goodMorning => isBangla ? 'সুপ্রভাত' : 'Good Morning';
  String get goodAfternoon => isBangla ? 'শুভ অপরাহ্ন' : 'Good Afternoon';
  String get goodEvening => isBangla ? 'শুভ সন্ধ্যা' : 'Good Evening';
  String get goodNight => isBangla ? 'শুভ রাত্রি' : 'Good Night';

  // ── Navigation (bottom bar) ──
  String get home => isBangla ? 'হোম' : 'Home';
  String get recitations => isBangla ? 'পাঠ' : 'Recitations';
  String get socialNav => isBangla ? 'সামাজিক' : 'Social';
  String get profile => isBangla ? 'প্রোফাইল' : 'Profile';
  String get settings => isBangla ? 'সেটিংস' : 'Settings';

  // ── Recitations sub-tabs ──
  String get quranTab => isBangla ? 'কুরআন' : 'Quran';
  String get duaTab => isBangla ? 'দু\'আ' : "Du'a";
  String get hadithTab => isBangla ? 'হাদিস' : 'Hadith';

  // ── Home section headers ──
  String get recitationsSection => isBangla ? '📖 পাঠ' : '📖 Recitations';
  String get namazSection => isBangla ? '🕌 নামাজ' : '🕌 Namaz';
  String get zakatSection => isBangla ? '💰 যাকাত' : '💰 Zakat';
  String get educationSection => isBangla ? '📚 শিক্ষা' : '📚 Education';
  String get achievementsSection => isBangla ? '🏆 অর্জন' : '🏆 Achievements';
  String get socialSection => isBangla ? '👥 সামাজিক' : '👥 Social';
  String get toolsSection => isBangla ? '🛠 টুলস' : '🛠 Tools';

  // ── Quran ──
  String get allSurahs => isBangla ? 'সকল সূরা' : 'All Surahs';
  String get surahCount => isBangla ? '১১৪ সূরা অডিও সহ' : '114 surahs with audio';
  String get resume => isBangla ? 'চালিয়ে যান' : 'Resume';
  String get verses => isBangla ? 'আয়াত' : 'Verses';
  String get playSurah => isBangla ? 'সূরা চালান' : 'Play Surah';
  String get searchSurah => isBangla ? 'সূরা খুঁজুন...' : 'Search surah...';
  String get meccan => isBangla ? 'মক্কী' : 'Meccan';
  String get medinan => isBangla ? 'মাদানী' : 'Medinan';

  // ── Dua ──
  String get duasTitle =>
      isBangla ? 'দু\'আ ও মুনাজাত' : 'Duas & Supplications';
  String get duaCategories => isBangla ? 'বিভাগসমূহ' : 'Categories';
  String get daily => isBangla ? 'দৈনিক' : 'Daily';
  String get prayer => isBangla ? 'নামাজ' : 'Prayer';
  String get travel => isBangla ? 'ভ্রমণ' : 'Travel';
  String get family => isBangla ? 'পরিবার' : 'Family';
  String get hardship => isBangla ? 'কষ্ট ও বিপদ' : 'Hardship';
  String get protection => isBangla ? 'সুরক্ষা' : 'Protection';
  String get social => isBangla ? 'সামাজিক' : 'Social';
  String get ramadan => isBangla ? 'রমজান' : 'Ramadan';
  String get death => isBangla ? 'মৃত্যু' : 'Death';
  String get all => isBangla ? 'সব' : 'All';

  // ── Hadith ──
  String get hadithCollections =>
      isBangla ? 'হাদিস সংকলন' : 'Hadith Collections';
  String get hadithOfTheDay =>
      isBangla ? 'আজকের হাদিস' : 'Hadith of the Day';
  String get browseByCollection =>
      isBangla ? 'সংকলন অনুসারে' : 'Browse by Collection';
  String get browseByTopic =>
      isBangla ? 'বিষয় অনুসারে' : 'Browse by Topic';
  String get hadithsLoaded =>
      isBangla ? 'হাদিস লোড হয়েছে' : 'hadiths loaded';
  String get loadingCollection =>
      isBangla ? 'সম্পূর্ণ হাদিস লোড হচ্ছে...' : 'Loading complete hadith collection...';
  String get chapter => isBangla ? 'অধ্যায়' : 'Chapter';
  String get sections => isBangla ? 'অধ্যায়সমূহ' : 'Sections';

  // ── Tools ──
  String get tasbih => isBangla ? 'তাসবিহ' : 'Tasbih';
  String get counter => isBangla ? 'গণনা' : 'Counter';
  String get qibla => isBangla ? 'কিবলা' : 'Qibla';
  String get calendar => isBangla ? 'ক্যালেন্ডার' : 'Calendar';
  String get hijri => isBangla ? 'হিজরি' : 'Hijri';
  String get comingSoon => isBangla ? 'শীঘ্রই আসছে' : 'Coming soon';

  // ── Namaz ──
  String get namazTitle => isBangla ? 'নামাজ ও ইবাদত' : 'Namaz & Worship';
  String get prayerTracker => isBangla ? 'নামাজ ট্র্যাকার' : 'Prayer Tracker';
  String get prayerReminder => isBangla ? 'রিমাইন্ডার' : 'Reminder';
  String get personalTracker => isBangla ? 'ব্যক্তিগত ট্র্যাকার' : 'Personal Tracker';

  // ── Zakat ──
  String get zakatTitle => isBangla ? 'যাকাত' : 'Zakat';
  String get zakatCalculator => isBangla ? 'যাকাত ক্যালকুলেটর' : 'Zakat Calculator';
  String get zakatRecipients => isBangla ? 'যাকাত গ্রহীতা' : 'Zakat Recipients';
  String get verifiedDonations => isBangla ? 'যাচাইকৃত দান' : 'Verified Donations';
  String get localMadrashas => isBangla ? 'স্থানীয় মাদ্রাসা' : 'Local Madrashas';

  // ── Education ──
  String get educationTitle => isBangla ? 'শিক্ষা ও কুইজ' : 'Education & Quiz';
  String get quiz => isBangla ? 'কুইজ' : 'Quiz';
  String get topicWiseTest => isBangla ? 'বিষয়ভিত্তিক পরীক্ষা' : 'Topic-wise Test';
  String get quizzes => isBangla ? 'কুইজসমূহ' : 'Quizzes';

  // ── Achievements ──
  String get achievementsTitle => isBangla ? 'অর্জনসমূহ' : 'Achievements';
  String get leaderboard => isBangla ? 'লিডারবোর্ড' : 'Leaderboard';
  String get dailyPrayers => isBangla ? 'দৈনিক নামাজ' : 'Daily Prayers';
  String get finishQuran => isBangla ? 'কুরআন সমাপ্তি' : 'Finish Quran';

  // ── Social ──
  String get socialTitle => isBangla ? 'সামাজিক' : 'Social';
  String get forum => isBangla ? 'ফোরাম' : 'Forum';
  String get janazah => isBangla ? 'জানাজা' : 'Janazah';
  String get eventsNearby => isBangla ? 'কাছের ইভেন্ট' : 'Events Nearby';

  // ── Prayer times ──
  String get prayerTimes => isBangla ? 'নামাজের সময়' : 'Prayer Times';
  String get next => isBangla ? 'পরবর্তী' : 'Next';
  String get endsAt => isBangla ? 'শেষ' : 'Ends at';
  String get enableLocation =>
      isBangla ? 'নামাজের সময়ের জন্য লোকেশন চালু করুন' : 'Enable location for prayer times';

  // ── Common ──
  String get arabic => isBangla ? 'আরবি' : 'Arabic';
  String get pronunciation => isBangla ? 'উচ্চারণ' : 'Pronunciation';
  String get translation => isBangla ? 'অনুবাদ' : 'Translation';
  String get bangla => isBangla ? 'বাংলা' : 'Bangla';
  String get english => isBangla ? 'ইংরেজি' : 'English';
  String get language => isBangla ? 'ভাষা' : 'Language';
  String get bookmarked => isBangla ? 'বুকমার্ক করা হয়েছে' : 'Bookmarked';
  String get failedToLoad => isBangla ? 'লোড করতে ব্যর্থ' : 'Failed to load';
  String get noInternet =>
      isBangla ? 'ইন্টারনেট সংযোগ পরীক্ষা করুন' : 'Check your internet connection';
  String get reference => isBangla ? 'রেফারেন্স' : 'Reference';

  // ── Dua category display names ──
  String duaCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'daily':
        return daily;
      case 'prayer':
        return prayer;
      case 'travel':
        return travel;
      case 'family':
        return family;
      case 'hardship':
        return hardship;
      case 'protection':
        return protection;
      case 'social':
        return social;
      case 'ramadan':
        return ramadan;
      case 'death':
        return death;
      default:
        return category;
    }
  }

  /// Dua category icons
  static IconDataMap duaCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'daily':
        return IconDataMap.sunFilled;
      case 'prayer':
        return IconDataMap.mosque;
      case 'travel':
        return IconDataMap.flight;
      case 'family':
        return IconDataMap.family;
      case 'hardship':
        return IconDataMap.heart;
      case 'protection':
        return IconDataMap.shield;
      case 'social':
        return IconDataMap.people;
      case 'ramadan':
        return IconDataMap.crescent;
      case 'death':
        return IconDataMap.book;
      default:
        return IconDataMap.star;
    }
  }
}

/// Simple icon map for dua categories (avoids importing material in this file).
enum IconDataMap {
  sunFilled,
  mosque,
  flight,
  family,
  heart,
  shield,
  people,
  crescent,
  book,
  star,
}
