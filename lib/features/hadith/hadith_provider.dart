import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/locale/locale_provider.dart';
import '../../core/utils/hadith_text_sanitizer.dart';
import 'data/bukhari_sections_data.dart';

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
  final int? id;
  final int number;
  final String bookId;
  final String chapter;
  final String arabic;
  final String text; // Translation based on active language
  final String? english;
  final String? bengali;
  final String? transliteration;
  final String? transliterationBn;
  final String? narrator;
  final String? grade;
  final String? reference;
  final String? audioAsset;

  const HadithEntry({
    this.id,
    required this.number,
    this.bookId = 'bukhari',
    this.chapter = 'General',
    required this.arabic,
    required this.text,
    this.english,
    this.bengali,
    this.transliteration,
    this.transliterationBn,
    this.narrator,
    this.grade,
    this.reference,
    this.audioAsset,
  });

  String get bookName {
    for (final b in hadithBooks) {
      if (b.id == bookId) return b.nameEnglish;
    }
    return 'Hadith';
  }

  factory HadithEntry.fromJson(Map<String, dynamic> json) {
    return HadithEntry(
      id: json['id'] as int?,
      number: json['hadithNumber'] as int? ??
          json['hadithnumber'] as int? ??
          json['id'] as int? ??
          json['number'] as int? ??
          1,
      bookId: json['bookId'] as String? ?? 'bukhari',
      chapter: json['chapter'] as String? ?? 'General',
      arabic: json['arabic'] as String? ?? '',
      text: json['bengali'] as String? ??
          json['english'] as String? ??
          json['text'] as String? ??
          '',
      english: json['english'] as String?,
      bengali: json['bengali'] as String?,
      transliteration: json['transliteration'] as String?,
      transliterationBn: json['transliterationBn'] as String?,
      narrator: json['narrator'] as String?,
      grade: json['grade'] as String? ?? 'Sahih',
      reference: json['reference'] is String
          ? json['reference'] as String
          : json['reference'] is Map
              ? 'Hadith ${json['hadithNumber'] ?? json['hadithnumber'] ?? ''}'
              : null,
      audioAsset: json['audioAsset'] as String? ?? (json['id'] != null ? 'assets/audio/hadiths/h${json['id']}.mp3' : null),
    );
  }

  HadithEntry copyWith({
    int? id,
    int? number,
    String? bookId,
    String? chapter,
    String? arabic,
    String? text,
    String? english,
    String? bengali,
    String? transliteration,
    String? transliterationBn,
    String? narrator,
    String? grade,
    String? reference,
    String? audioAsset,
  }) {
    return HadithEntry(
      id: id ?? this.id,
      number: number ?? this.number,
      bookId: bookId ?? this.bookId,
      chapter: chapter ?? this.chapter,
      arabic: arabic ?? this.arabic,
      text: text ?? this.text,
      english: english ?? this.english,
      bengali: bengali ?? this.bengali,
      transliteration: transliteration ?? this.transliteration,
      transliterationBn: transliterationBn ?? this.transliterationBn,
      narrator: narrator ?? this.narrator,
      grade: grade ?? this.grade,
      reference: reference ?? this.reference,
      audioAsset: audioAsset ?? this.audioAsset,
    );
  }
}

// ─────────────────────────────────────────────────────
//  Available books (The Six Canonical Collections)
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
    id: 'nasai',
    nameEnglish: "Sunan an-Nasa'i",
    nameBengali: "সুনানে আন-নাসা'ঈ",
    hadithCount: 5758,
  ),
  HadithBook(
    id: 'ibnmajah',
    nameEnglish: 'Sunan Ibn Majah',
    nameBengali: 'সুনানে ইবনে মাজাহ',
    hadithCount: 4341,
  ),
];

// ─────────────────────────────────────────────────────
//  Local Offline Core Provider
// ─────────────────────────────────────────────────────

final allLocalHadithsProvider = FutureProvider<List<HadithEntry>>((ref) async {
  try {
    final assetString = await rootBundle.loadString('assets/data/hadiths.json');
    final list = jsonDecode(assetString) as List;
    return list
        .map((e) => HadithEntry.fromJson(e as Map<String, dynamic>))
        .toList();
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
  final String? transliterationBn;
  final String bookName;
  final int hadithNumber;
  final HadithEntry? entry;

  const DailyHadith({
    required this.arabic,
    required this.translation,
    this.transliteration,
    this.transliterationBn,
    required this.bookName,
    required this.hadithNumber,
    this.entry,
  });
}

final dailyHadithProvider = FutureProvider<DailyHadith>((ref) async {
  final hadiths = await ref.watch(allLocalHadithsProvider.future);
  if (hadiths.isNotEmpty) {
    // Pick based on day of year for stable daily hadith
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final hadith = hadiths[dayOfYear % hadiths.length];
    return DailyHadith(
      arabic: hadith.arabic,
      translation: hadith.bengali ?? hadith.english ?? hadith.text,
      transliteration: hadith.transliteration,
      transliterationBn: hadith.transliterationBn,
      bookName: hadith.reference ?? 'Sahih al-Bukhari',
      hadithNumber: hadith.number,
      entry: hadith,
    );
  }

  return const DailyHadith(
    arabic:
        'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى',
    translation:
        'নিশ্চয়ই প্রতিটি কাজ নিয়তের ওপর নির্ভরশীল। আর প্রত্যেক ব্যক্তি যা নিয়ত করবে তাই পাবে।',
    transliteration: 'Innamal a\'maalu bin-niyyaat',
    bookName: 'Sahih al-Bukhari',
    hadithNumber: 1,
  );
});

// ─────────────────────────────────────────────────────
//  Selected Book & Search Query Providers
// ─────────────────────────────────────────────────────

final selectedBookProvider = StateProvider<String>((ref) => 'bukhari');

final hadithSearchQueryProvider = StateProvider<String>((ref) => '');

final hadithChapterSearchProvider = StateProvider<String>((ref) => '');

/// Search Hadiths locally across Arabic, English, Bengali, or Narrator
final searchedHadithsProvider = FutureProvider<List<HadithEntry>>((ref) async {
  final all = await ref.watch(allLocalHadithsProvider.future);
  final query = ref.watch(hadithSearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) return all;

  return all.where((h) {
    final text = h.text.toLowerCase();
    final eng = (h.english ?? '').toLowerCase();
    final bn = (h.bengali ?? '').toLowerCase();
    final narrator = (h.narrator ?? '').toLowerCase();
    final refStr = (h.reference ?? '').toLowerCase();
    final arabic = h.arabic;

    return text.contains(query) ||
        eng.contains(query) ||
        bn.contains(query) ||
        narrator.contains(query) ||
        refStr.contains(query) ||
        arabic.contains(query);
  }).toList();
});

// ─────────────────────────────────────────────────────
//  Hadith Sections (Chapters/Topics) with Cloud CDN & Offline Fallback
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

  int get hadithCount {
    if (lastHadith >= firstHadith && firstHadith > 0) {
      return lastHadith - firstHadith + 1;
    }
    return 1;
  }
}

// In-memory cache for book sections from CDN
final Map<String, List<HadithSection>> _cachedSections = {};

/// Fetch sections/chapters for a given hadith book (from CDN info.json or local fallback).
final hadithSectionsProvider =
    FutureProvider.family<List<HadithSection>, String>((ref, bookId) async {
  // 1. Full authentic Bukhari Sharif directory directly from curated metadata (100% offline & instant)
  if (bookId == 'bukhari') {
    final isBn = ref.watch(localeProvider) == AppLocale.bangla;
    return allBukhariSections
        .map((s) => HadithSection(
              sectionNumber: s.sectionNumber,
              name: isBn ? s.nameBn : s.nameEn,
              firstHadith: s.firstHadith,
              lastHadith: s.lastHadith,
            ))
        .toList();
  }

  // Check memory cache first for other books
  if (_cachedSections.containsKey(bookId) &&
      _cachedSections[bookId]!.isNotEmpty) {
    return _cachedSections[bookId]!;
  }

  // 2. Try fetching live sections from CDN metadata
  try {
    final url =
        Uri.parse('https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/info.json');
    final res = await http.get(url).timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json.containsKey(bookId)) {
        final bookData = json[bookId] as Map<String, dynamic>;
        final meta = bookData['metadata'] as Map<String, dynamic>?;
        final sectionsMap = meta?['sections'] as Map<String, dynamic>?;
        final detailsMap = (meta?['section_details'] ?? meta?['section_detail'])
            as Map<String, dynamic>?;

        if (sectionsMap != null && sectionsMap.isNotEmpty) {
          final sections = <HadithSection>[];
          sectionsMap.forEach((key, val) {
            final secNum = int.tryParse(key);
            final secName = val?.toString() ?? '';
            if (secNum != null && secNum > 0 && secName.trim().isNotEmpty) {
              final detail = detailsMap?[key] as Map<String, dynamic>?;
              final first = detail?['hadithnumber_first'] as int? ?? 1;
              final last = detail?['hadithnumber_last'] as int? ?? first;
              sections.add(HadithSection(
                sectionNumber: secNum,
                name: secName.trim(),
                firstHadith: first,
                lastHadith: last,
              ));
            }
          });

          if (sections.isNotEmpty) {
            sections.sort((a, b) => a.sectionNumber.compareTo(b.sectionNumber));
            _cachedSections[bookId] = sections;
            return sections;
          }
        }
      }
    }
  } catch (_) {
    // Network failed or timed out — fall back to local offline chapters
  }

  // 2. Offline fallback: Group local hadiths by chapter
  final all = await ref.watch(allLocalHadithsProvider.future);
  final bookHadiths = all.where((h) => h.bookId == bookId).toList();

  if (bookHadiths.isNotEmpty) {
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

  // 3. Fallback default chapters if empty
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

// ─────────────────────────────────────────────────────
//  Hadith Section Content Loader (CDN with Offline Core Fallback)
// ─────────────────────────────────────────────────────

// Cache for section hadiths
final Map<String, List<HadithEntry>> _cachedSectionHadiths = {};

/// Fetch hadiths for a specific section of a book.
final hadithBySectionProvider = FutureProvider.family<List<HadithEntry>,
    ({String bookId, int sectionNumber})>((ref, params) async {
  final cacheKey = '${params.bookId}:${params.sectionNumber}';
  if (_cachedSectionHadiths.containsKey(cacheKey) &&
      _cachedSectionHadiths[cacheKey]!.isNotEmpty) {
    return _cachedSectionHadiths[cacheKey]!;
  }

  // 1. Try loading from High-Performance CDN API
  try {
    final araUrl = Uri.parse(
        'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-${params.bookId}/sections/${params.sectionNumber}.json');
    final engUrl = Uri.parse(
        'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/eng-${params.bookId}/sections/${params.sectionNumber}.json');
    final benUrl = Uri.parse(
        'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ben-${params.bookId}/sections/${params.sectionNumber}.json');

    final responses = await Future.wait([
      http.get(araUrl).timeout(const Duration(seconds: 4)),
      http.get(engUrl).timeout(const Duration(seconds: 4)),
      http.get(benUrl).timeout(const Duration(seconds: 4)),
    ]);

    if (responses[0].statusCode == 200) {
      final araData = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final araList = (araData['hadiths'] as List?) ?? [];

      Map<int, String> engMap = {};
      if (responses[1].statusCode == 200) {
        final engData = jsonDecode(responses[1].body) as Map<String, dynamic>;
        final engList = (engData['hadiths'] as List?) ?? [];
        for (final item in engList) {
          final num = item['hadithnumber'] as int?;
          if (num != null) engMap[num] = item['text'] as String? ?? '';
        }
      }

      Map<int, String> benMap = {};
      if (responses[2].statusCode == 200) {
        final benData = jsonDecode(responses[2].body) as Map<String, dynamic>;
        final benList = (benData['hadiths'] as List?) ?? [];
        for (final item in benList) {
          final num = item['hadithnumber'] as int?;
          if (num != null) benMap[num] = item['text'] as String? ?? '';
        }
      }

      final bookName = hadithBooks
          .firstWhere((b) => b.id == params.bookId,
              orElse: () => hadithBooks.first)
          .nameEnglish;

      final result = <HadithEntry>[];
      for (final item in araList) {
        final num = item['hadithnumber'] as int? ?? 1;
        final arabic = (item['text'] as String? ?? '').trim();
        final eng = engMap[num];
        final ben = benMap[num];

        if (arabic.isNotEmpty) {
          final cleanBen = ben != null ? HadithTextSanitizer.cleanBengaliText(ben) : null;
          final cleanEng = eng != null ? HadithTextSanitizer.cleanEnglishText(eng) : null;

          result.add(HadithEntry(
            number: num,
            bookId: params.bookId,
            chapter: 'Section ${params.sectionNumber}',
            arabic: arabic,
            text: cleanBen?.isNotEmpty == true
                ? cleanBen!
                : (cleanEng?.isNotEmpty == true ? cleanEng! : ''),
            english: cleanEng,
            bengali: cleanBen,
            reference: '$bookName $num',
          ));
        }
      }

      if (result.isNotEmpty) {
        _cachedSectionHadiths[cacheKey] = result;
        return result;
      }
    }
  } catch (_) {
    // Network unavailable or timed out; seamlessly fall back to local offline data
  }

  // 2. Offline Fallback: match from local assets
  final all = await ref.watch(allLocalHadithsProvider.future);
  final bookHadiths = all.where((h) => h.bookId == params.bookId).toList();

  if (bookHadiths.isNotEmpty) {
    final sections =
        await ref.watch(hadithSectionsProvider(params.bookId).future);
    final targetSection = sections.firstWhere(
      (s) => s.sectionNumber == params.sectionNumber,
      orElse: () => sections.first,
    );
    final matched =
        bookHadiths.where((h) => h.chapter == targetSection.name).toList();
    if (matched.isNotEmpty) return matched;
    return bookHadiths;
  }

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

// ─────────────────────────────────────────────────────
//  Dynamic Navigation & Thematic Topics Engine
// ─────────────────────────────────────────────────────

enum HadithReadingMode {
  translationFirst, // Default: Translation on top, collapsible Arabic below
  dual,             // Both Arabic and Translation visible, with Arabic collapse guard
  arabicOnly,       // Arabic on top with typography controls
}

final hadithReadingModeProvider =
    StateProvider<HadithReadingMode>((ref) => HadithReadingMode.translationFirst);

enum HadithViewMode { wisdom, collections, topics, saved }

final hadithViewModeProvider =
    StateProvider<HadithViewMode>((ref) => HadithViewMode.wisdom);

class ThematicTopic {
  final String id;
  final String nameEn;
  final String nameBn;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  const ThematicTopic({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.icon,
    required this.color,
    required this.keywords,
  });
}

const List<ThematicTopic> thematicTopics = [
  ThematicTopic(
    id: 'akhlaq',
    nameEn: 'Character & Manners',
    nameBn: 'সচ্চরিত্র ও শিষ্টাচার',
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFF10B981),
    keywords: [
      'manner', 'character', 'adab', 'akhlaq', 'good', 'kind', 'anger',
      'truth', 'চরিত্র', 'শিষ্টাচার', 'সৎ', 'নম্র', 'রাগ', 'সততা'
    ],
  ),
  ThematicTopic(
    id: 'sincerity',
    nameEn: 'Sincerity & Faith',
    nameBn: 'ইখলাস ও ঈমান',
    icon: Icons.favorite_rounded,
    color: Color(0xFFF59E0B),
    keywords: [
      'intention', 'niyyah', 'iman', 'faith', 'sincere', 'allah', 'believe',
      'ইখলাস', 'নিয়ত', 'ঈমান', 'বিশ্বাস', 'আল্লাহ'
    ],
  ),
  ThematicTopic(
    id: 'patience',
    nameEn: 'Patience & Gratitude',
    nameBn: 'ধৈর্য ও কৃতজ্ঞতা',
    icon: Icons.spa_rounded,
    color: Color(0xFF8B5CF6),
    keywords: [
      'patience', 'sabr', 'gratitude', 'shukr', 'test', 'affliction',
      'ধৈর্য', 'সবর', 'শোকর', 'কৃতজ্ঞতা', 'বিপদ'
    ],
  ),
  ThematicTopic(
    id: 'charity',
    nameEn: 'Charity & Giving',
    nameBn: 'দান ও সদকা',
    icon: Icons.handshake_rounded,
    color: Color(0xFF3B82F6),
    keywords: [
      'charity', 'sadaqah', 'zakat', 'give', 'wealth', 'poor', 'needy',
      'দান', 'সদকা', 'যাকাত', 'সাহায্য', 'দরিদ্র'
    ],
  ),
  ThematicTopic(
    id: 'knowledge',
    nameEn: 'Seeking Knowledge',
    nameBn: 'জ্ঞান ও ইলম অর্জন',
    icon: Icons.school_rounded,
    color: Color(0xFF06B6D4),
    keywords: [
      'knowledge', 'ilm', 'learn', 'scholar', 'teach', 'wisdom',
      'জ্ঞান', 'ইলম', 'শিক্ষা', 'আলেম', 'প্রজ্ঞা'
    ],
  ),
  ThematicTopic(
    id: 'repentance',
    nameEn: 'Repentance & Mercy',
    nameBn: 'তওবা ও আল্লাহর রহমত',
    icon: Icons.waves_rounded,
    color: Color(0xFFEC4899),
    keywords: [
      'repent', 'tawbah', 'mercy', 'forgive', 'sin', 'rahmah',
      'তওবা', 'ক্ষমা', 'রহমত', 'গুনাহ', 'পাপ'
    ],
  ),
  ThematicTopic(
    id: 'family',
    nameEn: 'Parents & Family',
    nameBn: 'পিতামাতা ও আত্মীয়তা',
    icon: Icons.family_restroom_rounded,
    color: Color(0xFF14B8A6),
    keywords: [
      'parent', 'mother', 'father', 'family', 'kinship', 'relative', 'children',
      'পিতামাতা', 'মা', 'বাবা', 'পরিবার', 'আত্মীয়'
    ],
  ),
];

final selectedThematicTopicProvider = StateProvider<String?>((ref) => null);

/// Hadiths matching the selected thematic topic.
final thematicHadithsProvider =
    FutureProvider.family<List<HadithEntry>, String>((ref, topicId) async {
  final all = await ref.watch(allLocalHadithsProvider.future);
  final topic = thematicTopics.firstWhere(
    (t) => t.id == topicId,
    orElse: () => thematicTopics.first,
  );

  return all.where((h) {
    final text = '${h.text} ${h.arabic} ${h.english ?? ""} ${h.bengali ?? ""}'.toLowerCase();
    return topic.keywords.any((k) => text.contains(k.toLowerCase()));
  }).toList();
});

/// Reactive stream of currently bookmarked Hadiths with authentic entries.
final bookmarkedHadithsProvider =
    FutureProvider<List<HadithEntry>>((ref) async {
  final bookmarks = ref.watch(hadithBookmarkProvider);
  if (bookmarks.isEmpty) return [];

  final all = await ref.watch(allLocalHadithsProvider.future);
  final result = <HadithEntry>[];

  for (final key in bookmarks) {
    final parts = key.split(':');
    if (parts.length == 2) {
      final bId = parts[0];
      final num = int.tryParse(parts[1]);
      if (num != null) {
        final match = all.where((h) => h.bookId == bId && h.number == num).firstOrNull;
        if (match != null) {
          result.add(match);
        } else {
          // Construct lightweight entry for bookmarked CDN item
          result.add(HadithEntry(
            number: num,
            bookId: bId,
            arabic: '',
            text: 'Hadith $num from $bId',
            reference: '$bId $num',
          ));
        }
      }
    }
  }

  return result;
});

/// Seed for dynamic random discovery of Hadiths
final randomHadithSeedProvider = StateProvider<int>((ref) => 0);

/// Dynamic Hadith discovery provider (can be refreshed/shuffled on demand)
final dynamicWisdomHadithProvider = FutureProvider<HadithEntry?>((ref) async {
  final all = await ref.watch(allLocalHadithsProvider.future);
  if (all.isEmpty) return null;
  final seed = ref.watch(randomHadithSeedProvider);
  final dayOfYear =
      DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
  final index = (dayOfYear + seed) % all.length;
  return all[index];
});

