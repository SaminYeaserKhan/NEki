import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
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
  final String arabic;
  final String text; // Translation
  final String? narrator;
  final String? grade;

  const HadithEntry({
    required this.number,
    required this.arabic,
    required this.text,
    this.narrator,
    this.grade,
  });
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
    id: 'abudawud',
    nameEnglish: 'Sunan Abu Dawud',
    nameBengali: 'সুনানে আবু দাউদ',
    hadithCount: 5274,
  ),
  HadithBook(
    id: 'tirmidhi',
    nameEnglish: 'Jami at-Tirmidhi',
    nameBengali: 'জামে আত-তিরমিযী',
    hadithCount: 3956,
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
//  CDN base URLs (fawazahmed0/hadith-api)
// ─────────────────────────────────────────────────────

const _cdnBase =
    'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1';

String _hadithUrl(String bookId, String lang) =>
    '$_cdnBase/editions/$lang-$bookId.json';

// ─────────────────────────────────────────────────────
//  Hadith of the Day provider
// ─────────────────────────────────────────────────────

class DailyHadith {
  final String arabic;
  final String translation;
  final String bookName;
  final int hadithNumber;

  const DailyHadith({
    required this.arabic,
    required this.translation,
    required this.bookName,
    required this.hadithNumber,
  });
}

final dailyHadithProvider = FutureProvider<DailyHadith>((ref) async {
  // Use today's date as seed for consistent daily rotation
  final today = DateTime.now();
  final seed = today.year * 10000 + today.month * 100 + today.day;
  final rng = Random(seed);

  // Pick a random hadith from Bukhari (most widely known)
  final hadithNum = rng.nextInt(300) + 1; // First 300 are most popular

  try {
    // Fetch Bengali translation
    final bnResponse = await http.get(
      Uri.parse(_hadithUrl('bukhari', 'ben')),
    );

    // Fetch Arabic
    final arResponse = await http.get(
      Uri.parse(_hadithUrl('bukhari', 'ara')),
    );

    if (bnResponse.statusCode == 200 && arResponse.statusCode == 200) {
      final bnData = jsonDecode(bnResponse.body);
      final arData = jsonDecode(arResponse.body);

      final bnHadiths = bnData['hadiths'] as List;
      final arHadiths = arData['hadiths'] as List;

      final index = hadithNum.clamp(0, bnHadiths.length - 1);

      return DailyHadith(
        arabic: arHadiths[index]['text'] ?? '',
        translation: bnHadiths[index]['text'] ?? '',
        bookName: 'Sahih al-Bukhari',
        hadithNumber: hadithNum,
      );
    }
  } catch (_) {
    // Fallback
  }

  return const DailyHadith(
    arabic: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
    translation:
        'নিশ্চয়ই প্রতিটি কাজ নিয়তের উপর নির্ভরশীল।',
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
  try {
    final bnResponse = await http.get(
      Uri.parse(_hadithUrl(bookId, 'ben')),
    );
    final arResponse = await http.get(
      Uri.parse(_hadithUrl(bookId, 'ara')),
    );

    if (bnResponse.statusCode == 200 && arResponse.statusCode == 200) {
      final bnData = jsonDecode(bnResponse.body);
      final arData = jsonDecode(arResponse.body);

      final bnHadiths = bnData['hadiths'] as List;
      final arHadiths = arData['hadiths'] as List;

      final count = bnHadiths.length < arHadiths.length
          ? bnHadiths.length
          : arHadiths.length;

      return List.generate(count, (i) {
        return HadithEntry(
          number: i + 1,
          arabic: arHadiths[i]['text'] ?? '',
          text: bnHadiths[i]['text'] ?? '',
          grade: bnHadiths[i]['grades'] != null &&
                  (bnHadiths[i]['grades'] as List).isNotEmpty
              ? (bnHadiths[i]['grades'] as List)[0]['grade']
              : null,
        );
      });
    }
  } catch (_) {
    // Network error
  }

  return [];
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
  try {
    // Fetch the English edition to get section names
    final response = await http.get(
      Uri.parse('$_cdnBase/editions/eng-$bookId.json'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final metadata = data['metadata'];

      if (metadata != null) {
        final sectionNames =
            metadata['section'] as Map<String, dynamic>? ?? {};
        final sectionDetails =
            metadata['section_detail'] as Map<String, dynamic>? ?? {};

        final sections = <HadithSection>[];
        for (final entry in sectionNames.entries) {
          final num = int.tryParse(entry.key) ?? 0;
          final detail = sectionDetails[entry.key] as Map<String, dynamic>?;

          sections.add(HadithSection(
            sectionNumber: num,
            name: entry.value.toString(),
            firstHadith: detail?['hadithnumber_first'] as int? ?? 0,
            lastHadith: detail?['hadithnumber_last'] as int? ?? 0,
          ));
        }

        sections.sort((a, b) => a.sectionNumber.compareTo(b.sectionNumber));
        return sections;
      }
    }
  } catch (_) {
    // Network error
  }

  return [];
});

/// Browse mode: by collection or by section/topic.
enum HadithBrowseMode { collection, section }

final hadithBrowseModeProvider =
    StateProvider<HadithBrowseMode>((ref) => HadithBrowseMode.section);

/// Fetch hadiths for a specific section of a book.
final hadithBySectionProvider = FutureProvider.family<List<HadithEntry>,
    ({String bookId, int sectionNumber})>((ref, params) async {
  try {
    // Fetch section-specific data
    final engResponse = await http.get(
      Uri.parse(
          '$_cdnBase/editions/eng-${params.bookId}/sections/${params.sectionNumber}.json'),
    );
    final arResponse = await http.get(
      Uri.parse(
          '$_cdnBase/editions/ara-${params.bookId}/sections/${params.sectionNumber}.json'),
    );

    if (engResponse.statusCode == 200 && arResponse.statusCode == 200) {
      final engData = jsonDecode(engResponse.body);
      final arData = jsonDecode(arResponse.body);

      final engHadiths = engData['hadiths'] as List;
      final arHadiths = arData['hadiths'] as List;

      final count = engHadiths.length < arHadiths.length
          ? engHadiths.length
          : arHadiths.length;

      return List.generate(count, (i) {
        return HadithEntry(
          number: engHadiths[i]['hadithnumber'] as int? ?? (i + 1),
          arabic: arHadiths[i]['text'] ?? '',
          text: engHadiths[i]['text'] ?? '',
          grade: engHadiths[i]['grades'] != null &&
                  (engHadiths[i]['grades'] as List).isNotEmpty
              ? (engHadiths[i]['grades'] as List)[0]['grade']
              : null,
        );
      });
    }
  } catch (_) {
    // Network error
  }

  return [];
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
