import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────

class Dua {
  final int id;
  final String category;
  final String title;
  final String description; // English translation
  final String? bengali;
  final String arabic;
  final String transliteration; // Pronunciation
  final String? transliterationBn; // Bengali Pronunciation
  final String? reference;
  final int? surahNumber;
  final int? verseNumber;
  final List<String> emotions;
  final String? audioUrl;

  const Dua({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.bengali,
    required this.arabic,
    required this.transliteration,
    this.transliterationBn,
    this.reference,
    this.surahNumber,
    this.verseNumber,
    this.emotions = const [],
    this.audioUrl,
  });

  bool get isQuranic => surahNumber != null && verseNumber != null;

  /// Returns recommended dhikr repetitions (e.g. 3 for "Recite 3 times", default 1).
  int get recommendedRepetitions {
    final text = '$title $description ${bengali ?? ""}';
    final matchEn = RegExp(r'(\d+)\s*times', caseSensitive: false).firstMatch(text);
    if (matchEn != null) {
      final parsed = int.tryParse(matchEn.group(1)!);
      if (parsed != null && parsed > 0 && parsed <= 1000) return parsed;
    }
    final matchBn = RegExp(r'([০-৯\d]+)\s*বার').firstMatch(text);
    if (matchBn != null) {
      final raw = matchBn.group(1)!;
      final converted = raw
          .replaceAll('০', '0')
          .replaceAll('১', '1')
          .replaceAll('২', '2')
          .replaceAll('৩', '3')
          .replaceAll('৪', '4')
          .replaceAll('৫', '5')
          .replaceAll('৬', '6')
          .replaceAll('৭', '7')
          .replaceAll('৮', '8')
          .replaceAll('৯', '9');
      final parsed = int.tryParse(converted);
      if (parsed != null && parsed > 0 && parsed <= 1000) return parsed;
    }
    return 1;
  }

  /// Dynamic emotion and devotional intent tags for this Dua.
  List<String> get resolvedEmotions {
    if (emotions.isNotEmpty) return emotions;
    final list = <String>[];
    final text = '$title $description ${bengali ?? ""}'.toLowerCase();
    if (category == 'hardship' ||
        text.contains('anxiety') ||
        text.contains('worry') ||
        text.contains('distress') ||
        text.contains('দুশ্চিন্তা') ||
        text.contains('বিপদ') ||
        text.contains('কষ্ট')) {
      list.add('anxious');
      list.add('hardship');
    }
    if (category == 'forgiveness' ||
        text.contains('forgive') ||
        text.contains('sin') ||
        text.contains('repent') ||
        text.contains('pardon') ||
        text.contains('তওবা') ||
        text.contains('ক্ষমা') ||
        text.contains('পাপ') ||
        text.contains('ইস্তিগফার')) {
      list.add('forgiveness');
    }
    if (text.contains('praise') ||
        text.contains('gratitude') ||
        text.contains('thank') ||
        text.contains('শুকরিয়া') ||
        text.contains('প্রশংসা')) {
      list.add('grateful');
    }
    if (category == 'protection' ||
        text.contains('evil') ||
        text.contains('harm') ||
        text.contains('আশ্রয়') ||
        text.contains('রক্ষা') ||
        text.contains('অনিষ্ট')) {
      list.add('protection');
    }
    if (text.contains('guidance') ||
        text.contains('light') ||
        text.contains('হিদায়াত') ||
        text.contains('পথ')) {
      list.add('guidance');
    }
    if (category == 'family' ||
        text.contains('parent') ||
        text.contains('child') ||
        text.contains('স্ত্রী') ||
        text.contains('পিতা') ||
        text.contains('মাতা') ||
        text.contains('সন্তান')) {
      list.add('family');
    }
    if (text.contains('health') ||
        text.contains('cure') ||
        text.contains('disease') ||
        text.contains('রোগ') ||
        text.contains('সুস্থতা') ||
        text.contains('শিফা')) {
      list.add('health');
    }
    return list;
  }

  factory Dua.fromJson(Map<String, dynamic> json) {
    final catRaw = (json['category'] as String? ?? 'daily').trim().toLowerCase();
    final trans = json['transliteration'] as String? ?? '';
    final transBn = json['transliterationBn'] as String?;
    return Dua(
      id: json['id'] as int? ?? 0,
      category: catRaw.isEmpty ? 'daily' : catRaw,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? json['english'] as String? ?? '',
      bengali: json['bengali'] as String?,
      arabic: json['dua'] as String? ?? json['arabic'] as String? ?? '',
      transliteration: trans,
      transliterationBn: transBn,
      reference: json['reference'] as String?,
      surahNumber: json['surahNumber'] as int?,
      verseNumber: json['verseNumber'] as int?,
      emotions: (json['emotions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      audioUrl: json['audioUrl'] as String?,
    );
  }
}

/// A category group with name and list of duas.
class DuaCategory {
  final String id;
  final String nameEn;
  final String nameBn;
  final int count;

  const DuaCategory({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.count,
  });
}

// ─────────────────────────────────────────────────────
//  Category metadata
// ─────────────────────────────────────────────────────

const _categoryMeta = <String, Map<String, String>>{
  'daily': {'en': 'Daily Life', 'bn': 'দৈনন্দিন জীবন'},
  'morning': {'en': 'Morning', 'bn': 'সকালের দো‘আ'},
  'evening': {'en': 'Evening', 'bn': 'সন্ধ্যার দো‘আ'},
  'prayer': {'en': 'Prayer (Salah)', 'bn': 'নামাজ ও সালাত'},
  'travel': {'en': 'Travel', 'bn': 'ভ্রমণ ও সফর'},
  'family': {'en': 'Family & Spouse', 'bn': 'পরিবার ও সন্তান'},
  'hardship': {'en': 'Hardship & Relief', 'bn': 'বিপদ ও মুক্তি'},
  'protection': {'en': 'Protection & Shield', 'bn': 'সুরক্ষা ও আশ্রয়'},
  'social': {'en': 'Social & Gathering', 'bn': 'সামাজিক ও মজলিস'},
  'ramadan': {'en': 'Ramadan & Fasting', 'bn': 'রমজান ও রোজা'},
  'death': {'en': 'Funeral & Death', 'bn': 'জানাযা ও কবর'},
};

// ─────────────────────────────────────────────────────
//  Providers
// ─────────────────────────────────────────────────────

/// Fetches duas from local assets first with fallback to remote API.
final duaListProvider = FutureProvider<List<Dua>>((ref) async {
  // 1. Try local offline assets first
  try {
    final assetString = await rootBundle.loadString('assets/data/duas.json');
    final list = jsonDecode(assetString) as List;
    final duas = list.map((e) => Dua.fromJson(e as Map<String, dynamic>)).toList();
    if (duas.isNotEmpty) return duas;
  } catch (_) {}

  // 2. Fallback to API if assets unavailable
  try {
    final response = await http.get(
      Uri.parse('https://dua-data-api.vercel.app/api/usefulDuas'),
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .map((e) => Dua.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  } catch (_) {}

  return [];
});

/// Search query for Duas.
final duaSearchQueryProvider = StateProvider<String>((ref) => '');

/// Duas filtered by search query across Title, Arabic, English, and Bengali text.
final searchedDuasProvider = FutureProvider<List<Dua>>((ref) async {
  final all = await ref.watch(duaListProvider.future);
  final query = ref.watch(duaSearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) return all;

  return all.where((d) {
    final title = d.title.toLowerCase();
    final desc = d.description.toLowerCase();
    final bn = (d.bengali ?? '').toLowerCase();
    final arabic = d.arabic;
    final trans = d.transliteration.toLowerCase();
    final refStr = (d.reference ?? '').toLowerCase();

    return title.contains(query) ||
        desc.contains(query) ||
        bn.contains(query) ||
        arabic.contains(query) ||
        trans.contains(query) ||
        refStr.contains(query);
  }).toList();
});

/// Extracts unique categories with counts from the loaded duas.
final duaCategoriesProvider = FutureProvider<List<DuaCategory>>((ref) async {
  final duas = await ref.watch(duaListProvider.future);
  final categoryMap = <String, int>{};

  for (final dua in duas) {
    final cat = dua.category.toLowerCase();
    categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
  }

  // Order categories based on our defined order
  const categoryOrder = [
    'morning', 'evening', 'daily', 'prayer', 'hardship', 'protection',
    'travel', 'family', 'social', 'ramadan', 'death',
  ];

  final categories = <DuaCategory>[];
  for (final id in categoryOrder) {
    if (categoryMap.containsKey(id)) {
      final meta = _categoryMeta[id];
      categories.add(DuaCategory(
        id: id,
        nameEn: meta?['en'] ?? _capitalize(id),
        nameBn: meta?['bn'] ?? _capitalize(id),
        count: categoryMap[id]!,
      ));
    }
  }

  // Add any remaining categories
  for (final entry in categoryMap.entries) {
    if (!categoryOrder.contains(entry.key)) {
      categories.add(DuaCategory(
        id: entry.key,
        nameEn: _capitalize(entry.key),
        nameBn: _capitalize(entry.key),
        count: entry.value,
      ));
    }
  }

  return categories;
});

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Currently selected dua category.
final selectedDuaCategoryProvider = StateProvider<String?>((ref) => null);

/// Duas filtered by selected category.
final filteredDuasProvider = FutureProvider<List<Dua>>((ref) async {
  final duas = await ref.watch(duaListProvider.future);
  final category = ref.watch(selectedDuaCategoryProvider);
  if (category == null) return duas;
  return duas.where((d) => d.category == category.toLowerCase()).toList();
});

/// Duas for a specific category (used by DuaListScreen).
final duasByCategoryProvider =
    FutureProvider.family<List<Dua>, String>((ref, categoryId) async {
  final duas = await ref.watch(duaListProvider.future);
  final cat = categoryId.toLowerCase();
  return duas.where((d) => d.category == cat).toList();
});

// ─────────────────────────────────────────────────────
//  Dua Bookmarks (Persistent with SharedPreferences)
// ─────────────────────────────────────────────────────

class DuaBookmarkNotifier extends Notifier<Set<int>> {
  static const _key = 'neki_bookmarked_duas';

  @override
  Set<int> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    state = list.map((id) => int.tryParse(id)).whereType<int>().toSet();
  }

  Future<void> toggle(int duaId) async {
    final updated = Set<int>.from(state);
    if (updated.contains(duaId)) {
      updated.remove(duaId);
    } else {
      updated.add(duaId);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated.map((id) => id.toString()).toList());
  }

  bool isBookmarked(int duaId) => state.contains(duaId);
}

final duaBookmarkProvider =
    NotifierProvider<DuaBookmarkNotifier, Set<int>>(DuaBookmarkNotifier.new);

// ─────────────────────────────────────────────────────
//  Dynamic Navigation & Filtering Engine
// ─────────────────────────────────────────────────────

enum DuaViewMode { explore, categories, shortDuas, saved }

final duaViewModeProvider =
    StateProvider<DuaViewMode>((ref) => DuaViewMode.explore);

class DuaEmotion {
  final String id;
  final String nameEn;
  final String nameBn;
  final IconData icon;
  final Color color;

  const DuaEmotion({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.icon,
    required this.color,
  });
}

const List<DuaEmotion> duaEmotions = [
  DuaEmotion(
    id: 'anxious',
    nameEn: 'Anxious / Stressed',
    nameBn: 'উদ্বিগ্ন ও দুশ্চিন্তা',
    icon: Icons.spa_rounded,
    color: Color(0xFF66BB6A),
  ),
  DuaEmotion(
    id: 'grateful',
    nameEn: 'Grateful & Blessed',
    nameBn: 'কৃতজ্ঞ ও শোকরগুজার',
    icon: Icons.favorite_rounded,
    color: Color(0xFFFFA726),
  ),
  DuaEmotion(
    id: 'forgiveness',
    nameEn: 'Seeking Forgiveness',
    nameBn: 'ক্ষমা ও তওবা',
    icon: Icons.waves_rounded,
    color: Color(0xFF42A5F5),
  ),
  DuaEmotion(
    id: 'hardship',
    nameEn: 'In Pain / Hardship',
    nameBn: 'বিপদ ও সংকট',
    icon: Icons.shield_rounded,
    color: Color(0xFFEF5350),
  ),
  DuaEmotion(
    id: 'guidance',
    nameEn: 'Seeking Guidance',
    nameBn: 'হিদায়াত ও সঠিক পথ',
    icon: Icons.lightbulb_rounded,
    color: Color(0xFFFFCA28),
  ),
  DuaEmotion(
    id: 'family',
    nameEn: 'Family & Children',
    nameBn: 'পরিবার ও সন্তান',
    icon: Icons.family_restroom_rounded,
    color: Color(0xFFAB47BC),
  ),
  DuaEmotion(
    id: 'health',
    nameEn: 'Health & Healing',
    nameBn: 'রোগমুক্তি ও শিফা',
    icon: Icons.healing_rounded,
    color: Color(0xFF26A69A),
  ),
];

final selectedEmotionProvider = StateProvider<String?>((ref) => null);

/// Duas filtered by currently selected emotion.
final duasByEmotionProvider = FutureProvider<List<Dua>>((ref) async {
  final all = await ref.watch(duaListProvider.future);
  final emotion = ref.watch(selectedEmotionProvider);
  if (emotion == null) return all;
  return all.where((d) => d.resolvedEmotions.contains(emotion)).toList();
});

/// Dedicated stream of the 40 Quranic Rabbana Supplications.
final quranicDuasProvider = FutureProvider<List<Dua>>((ref) async {
  final all = await ref.watch(duaListProvider.future);
  return all.where((d) => d.isQuranic).toList();
});

/// Curated list of IDs for popular short supplications that people commonly
/// memorise for daily routine habits, prayer, and protection.
const popularShortDuaIds = <int>[
  19, // Before Eating (Bismillah)
  20, // After Finishing a Meal
  21, // Entering Restroom
  22, // Leaving Restroom (Ghufranak)
  13, // Upon Waking Up
  14, // Before Sleeping
  15, // When Leaving House
  16, // When Entering House
  17, // Entering Mosque
  18, // Leaving Mosque
  78, // When Sneezing & Responding
  79, // When Experiencing Anger
  76, // When it Rains
  77, // Looking into the Mirror
  80, // Drinking Milk
  81, // Wearing Clothes
  26, // Supplication in Ruku
  27, // Rising from Ruku
  28, // Supplication in Sujud
  29, // Between Two Prostrations
  65, // Rabbi Zidnee 'Ilma (Increase in Knowledge)
  37, // Supplication of Prophet Yunus
  43, // Hasbunallahu wa Ni'mal Wakeel
  49, // Supplication for Parents
  61, // Rabbana Atina fid-Dunya Hasanah
  54, // Breaking Fast (Iftar)
  55, // Supplication for Laylatul Qadr
  66, // Prophet Ayyub (Illness)
  69, // Prophet Musa (Faqeer)
  8,  // Subhanallahi wa bihamdih
  5,  // Radheetu billahi Rabba
  11, // A'udhu bikalimatillahit-tammati...
  41, // When a Matter Becomes Difficult
  53, // Expiation of Assembly (Kaffaratul Majlis)
  39, // Visiting the Sick
  46, // When Boarding Transport
  48, // Returning from Travel
  60, // Rabbana Taqabbal Minna
  62, // Rabbana La Tuzigh Quloobana
  63, // Rabbana Zhalamna Anfusana
  64, // Rabbana Atina mil-Ladunka Rahmah
  50, // Spouse & Offspring (Qurrata A'yun)
  51, // Zakariya (Dhurriyyatan Tayyibah)
  40, // Overcoming Debt
  71, // Parents & Believers on Reckoning Day
  4,  // Protection from All Harm
  44, // Protection of Children
];

/// Dedicated stream of popular short supplications to memorise.
final popularShortDuasProvider = FutureProvider<List<Dua>>((ref) async {
  final all = await ref.watch(duaListProvider.future);
  final map = {for (final d in all) d.id: d};

  final list = <Dua>[];
  for (final id in popularShortDuaIds) {
    final d = map[id];
    if (d != null) list.add(d);
  }

  // Include any other short duas (<= 14 words in Arabic) not explicitly in list
  for (final d in all) {
    if (!popularShortDuaIds.contains(d.id)) {
      final wordCount = d.arabic.trim().split(RegExp(r'\s+')).length;
      if (wordCount <= 14 && wordCount > 0) {
        list.add(d);
      }
    }
  }

  return list;
});

/// Reactive stream of currently bookmarked Duas.
final bookmarkedDuasProvider = FutureProvider<List<Dua>>((ref) async {
  final all = await ref.watch(duaListProvider.future);
  final bookmarks = ref.watch(duaBookmarkProvider);
  return all.where((d) => bookmarks.contains(d.id)).toList();
});

/// Daily Featured Dua for spiritual reflection.
final dailyFeaturedDuaProvider = FutureProvider<Dua?>((ref) async {
  final all = await ref.watch(duaListProvider.future);
  if (all.isEmpty) return null;
  final dayOfYear =
      DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
  return all[dayOfYear % all.length];
});


