import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────

class HadithBook {
  final String id;
  final String nameEnglish;
  final String nameBengali;
  final int hadithCount;

  const HadithBook({
    required this.id,
    required this.nameEnglish,
    required this.nameBengali,
    required this.hadithCount,
  });
}

class HadithEntry {
  final int number;
  final String bookId;
  final String chapter;
  final String arabic;
  final String text; // Translation based on active language
  final String? english;
  final String? bengali;
  final String? transliteration;
  final String? narrator;
  final String? grade;
  final String? reference;

  const HadithEntry({
    required this.number,
    this.bookId = 'bukhari',
    this.chapter = 'General',
    required this.arabic,
    required this.text,
    this.english,
    this.bengali,
    this.transliteration,
    this.narrator,
    this.grade,
    this.reference,
  });

  factory HadithEntry.fromJson(Map<String, dynamic> json) {
    return HadithEntry(
      number: json['hadithNumber'] as int? ?? json['id'] as int? ?? json['number'] as int? ?? 1,
      bookId: json['bookId'] as String? ?? 'bukhari',
      chapter: json['chapter'] as String? ?? 'General',
      arabic: json['arabic'] as String? ?? '',
      text: json['bengali'] as String? ?? json['english'] as String? ?? json['text'] as String? ?? '',
      english: json['english'] as String?,
      bengali: json['bengali'] as String?,
      transliteration: json['transliteration'] as String?,
      narrator: json['narrator'] as String?,
      grade: json['grade'] as String? ?? 'Sahih',
      reference: json['reference'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────
//  Available books
// ─────────────────────────────────────────────────────

const hadithBooks = [
  HadithBook(
    id: 'bukhari',
    nameEnglish: 'Sahih al-Bukhari',
    nameBengali: 'সহীহ আল-বুখারী',
    hadithCount: 7563,
  ),
  HadithBook(
    id: 'muslim',
    nameEnglish: 'Sahih Muslim',
    nameBengali: 'সহীহ মুসলিম',
    hadithCount: 7453,
  ),
  HadithBook(
    id: 'tirmidhi',
    nameEnglish: 'Jami at-Tirmidhi',
    nameBengali: 'জামে আত-তিরমিযী',
    hadithCount: 3956,
  ),
  HadithBook(
    id: 'abudawud',
    nameEnglish: 'Sunan Abu Dawud',
    nameBengali: 'সুনানে আবু দাউদ',
    hadithCount: 5274,
  ),
  HadithBook(
    id: 'ibnmajah',
    nameEnglish: 'Sunan Ibn Majah',
    nameBengali: 'সুনানে ইবনে মাজাহ',
    hadithCount: 4341,
  ),
  HadithBook(
    id: 'nasai',
    nameEnglish: "Sunan an-Nasa'i",
    nameBengali: "সুনানে আন-নাসা'ঈ",
    hadithCount: 5758,
  ),
];

// ─────────────────────────────────────────────────────
//  Local & CDN Providers
// ─────────────────────────────────────────────────────

final allLocalHadithsProvider = FutureProvider<List<HadithEntry>>((ref) async {
  try {
    final assetString = await rootBundle.loadString('assets/data/hadiths.json');
    final list = jsonDecode(assetString) as List;
    return list.map((e) => HadithEntry.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

// ─────────────────────────────────────────────────────
//  Hadith of the Day provider
// ─────────────────────────────────────────────────────

class DailyHadith {
  final String arabic;
  final String translation;
  final String? transliteration;
  final String bookName;
  final int hadithNumber;

  const DailyHadith({
    required this.arabic,
    required this.translation,
    this.transliteration,
    required this.bookName,
    required this.hadithNumber,
  });
}

final dailyHadithProvider = FutureProvider<DailyHadith>((ref) async {
  final hadiths = await ref.watch(allLocalHadithsProvider.future);
  if (hadiths.isNotEmpty) {
    // Pick based on day of year for stable daily hadith
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final hadith = hadiths[dayOfYear % hadiths.length];
    return DailyHadith(
      arabic: hadith.arabic,
      translation: hadith.bengali ?? hadith.english ?? hadith.text,
      transliteration: hadith.transliteration,
      bookName: hadith.reference ?? 'Sahih al-Bukhari',
      hadithNumber: hadith.number,
    );
  }

  return const DailyHadith(
    arabic: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
    translation: 'নিশ্চয়ই প্রতিটি কাজ নিয়তের উপর নির্ভরশীল।',
    transliteration: 'Innamal a\'maalu bin-niyyaat',
    bookName: 'Sahih al-Bukhari',
    hadithNumber: 1,
  );
});

// ─────────────────────────────────────────────────────
//  Fetch hadiths from a specific book
// ─────────────────────────────────────────────────────

final selectedBookProvider = StateProvider<String>((ref) => 'bukhari');

final hadithListProvider =
    FutureProvider.family<List<HadithEntry>, String>((ref, bookId) async {
  final all = await ref.watch(allLocalHadithsProvider.future);
  final filtered = all.where((h) => h.bookId == bookId).toList();
  if (filtered.isNotEmpty) return filtered;

  // Fallback to all if specific book has none
  return all;
});

// ─────────────────────────────────────────────────────
//  Hadith Sections (Chapters/Topics)
// ─────────────────────────────────────────────────────

class HadithSection {
  final int sectionNumber;
  final String name;
  final int firstHadith;
  final int lastHadith;

  const HadithSection({
    required this.sectionNumber,
    required this.name,
    required this.firstHadith,
    required this.lastHadith,
  });

  int get hadithCount => lastHadith - firstHadith + 1;
}

/// Fetch sections/chapters for a given hadith book.
final hadithSectionsProvider =
    FutureProvider.family<List<HadithSection>, String>((ref, bookId) async {
  final all = await ref.watch(allLocalHadithsProvider.future);
  final bookHadiths = all.where((h) => h.bookId == bookId).toList();

  if (bookHadiths.isNotEmpty) {
    // Group by chapter
    final chapterMap = <String, List<HadithEntry>>{};
    for (final h in bookHadiths) {
      chapterMap.putIfAbsent(h.chapter, () => []).add(h);
    }

    int secIndex = 1;
    final sections = <HadithSection>[];
    for (final entry in chapterMap.entries) {
      final numbers = entry.value.map((e) => e.number).toList()..sort();
      sections.add(HadithSection(
        sectionNumber: secIndex++,
        name: entry.key,
        firstHadith: numbers.first,
        lastHadith: numbers.last,
      ));
    }
    return sections;
  }

  // Fallback default chapters if empty
  return [
    const HadithSection(
      sectionNumber: 1,
      name: 'Essential Wisdom',
      firstHadith: 1,
      lastHadith: 1,
    ),
  ];
});

/// Browse mode: by collection or by section/topic.
enum HadithBrowseMode { collection, section }

final hadithBrowseModeProvider =
    StateProvider<HadithBrowseMode>((ref) => HadithBrowseMode.section);

/// Fetch hadiths for a specific section of a book.
final hadithBySectionProvider = FutureProvider.family<List<HadithEntry>,
    ({String bookId, int sectionNumber})>((ref, params) async {
  final all = await ref.watch(allLocalHadithsProvider.future);
  final bookHadiths = all.where((h) => h.bookId == params.bookId).toList();

  if (bookHadiths.isNotEmpty) {
    final sections = await ref.watch(hadithSectionsProvider(params.bookId).future);
    final targetSection = sections.firstWhere(
      (s) => s.sectionNumber == params.sectionNumber,
      orElse: () => sections.first,
    );
    return bookHadiths.where((h) => h.chapter == targetSection.name).toList();
  }

  // Fallback to all local
  return all;
});

// ─────────────────────────────────────────────────────
//  Bookmark support
// ─────────────────────────────────────────────────────

class HadithBookmarkNotifier extends Notifier<Set<String>> {
  static const _key = 'neki_hadith_bookmarks';

  @override
  Set<String> build() {
    _loadPersisted();
    return {};
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    if (stored != null) state = stored.toSet();
  }

  Future<void> toggle(String bookId, int hadithNumber) async {
    final key = '$bookId:$hadithNumber';
    final updated = Set<String>.from(state);
    if (updated.contains(key)) {
      updated.remove(key);
    } else {
      updated.add(key);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated.toList());
  }

  bool isBookmarked(String bookId, int hadithNumber) {
    return state.contains('$bookId:$hadithNumber');
  }
}

final hadithBookmarkProvider =
    NotifierProvider<HadithBookmarkNotifier, Set<String>>(
        HadithBookmarkNotifier.new);
