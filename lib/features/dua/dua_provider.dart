import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────

class Dua {
  final int id;
  final String category;
  final String title;
  final String description;
  final String arabic;
  final String transliteration; // English pronunciation
  final List<String> emotions;

  const Dua({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.arabic,
    required this.transliteration,
    this.emotions = const [],
  });

  factory Dua.fromJson(Map<String, dynamic> json) {
    return Dua(
      id: json['id'] as int? ?? 0,
      category: (json['category'] as String? ?? 'daily').toLowerCase(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      arabic: json['dua'] as String? ?? json['arabic'] as String? ?? '',
      transliteration: json['transliteration'] as String? ?? '',
      emotions: (json['emotions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
  'daily': {'en': 'Daily', 'bn': 'দৈনিক'},
  'prayer': {'en': 'Prayer', 'bn': 'নামাজ'},
  'travel': {'en': 'Travel', 'bn': 'ভ্রমণ'},
  'family': {'en': 'Family', 'bn': 'পরিবার'},
  'hardship': {'en': 'Hardship & Distress', 'bn': 'কষ্ট ও বিপদ'},
  'protection': {'en': 'Protection', 'bn': 'সুরক্ষা'},
  'social': {'en': 'Social', 'bn': 'সামাজিক'},
  'ramadan': {'en': 'Ramadan', 'bn': 'রমজান'},
  'death': {'en': 'Death & Funeral', 'bn': 'মৃত্যু ও জানাযা'},
};

// ─────────────────────────────────────────────────────
//  Providers
// ─────────────────────────────────────────────────────

/// Fetches all duas from the Naikiyah API (100+ categorized duas).
final duaListProvider = FutureProvider<List<Dua>>((ref) async {
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
  } catch (_) {
    // Fall through to empty list
  }
  return [];
});

/// Extracts unique categories with counts from the loaded duas.
final duaCategoriesProvider = FutureProvider<List<DuaCategory>>((ref) async {
  final duas = await ref.watch(duaListProvider.future);
  final categoryMap = <String, int>{};

  for (final dua in duas) {
    categoryMap[dua.category] = (categoryMap[dua.category] ?? 0) + 1;
  }

  // Order categories based on our defined order
  const categoryOrder = [
    'daily', 'prayer', 'travel', 'family',
    'hardship', 'protection', 'social', 'ramadan', 'death',
  ];

  final categories = <DuaCategory>[];
  for (final id in categoryOrder) {
    if (categoryMap.containsKey(id)) {
      final meta = _categoryMeta[id];
      categories.add(DuaCategory(
        id: id,
        nameEn: meta?['en'] ?? id,
        nameBn: meta?['bn'] ?? id,
        count: categoryMap[id]!,
      ));
    }
  }

  // Add any remaining categories not in our order
  for (final entry in categoryMap.entries) {
    if (!categoryOrder.contains(entry.key)) {
      categories.add(DuaCategory(
        id: entry.key,
        nameEn: entry.key,
        nameBn: entry.key,
        count: entry.value,
      ));
    }
  }

  return categories;
});

/// Currently selected dua category.
final selectedDuaCategoryProvider = StateProvider<String?>((ref) => null);

/// Duas filtered by selected category.
final filteredDuasProvider = FutureProvider<List<Dua>>((ref) async {
  final duas = await ref.watch(duaListProvider.future);
  final category = ref.watch(selectedDuaCategoryProvider);
  if (category == null) return duas;
  return duas.where((d) => d.category == category).toList();
});

/// Duas for a specific category (used by DuaListScreen).
final duasByCategoryProvider =
    FutureProvider.family<List<Dua>, String>((ref, categoryId) async {
  final duas = await ref.watch(duaListProvider.future);
  return duas.where((d) => d.category == categoryId).toList();
});
