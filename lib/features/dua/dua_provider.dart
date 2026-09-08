import 'dart:convert';

import 'package:flutter/services.dart';
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
  final String description; // English translation
  final String? bengali;
  final String arabic;
  final String transliteration; // Pronunciation
  final String? transliterationBn; // Bengali Pronunciation
  final String? reference;
  final List<String> emotions;

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
    this.emotions = const [],
  });

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
  'morning': {'en': 'Morning', 'bn': 'সকাল'},
  'evening': {'en': 'Evening', 'bn': 'সন্ধ্যা'},
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
    'daily', 'morning', 'evening', 'prayer', 'travel', 'family',
    'hardship', 'protection', 'social', 'ramadan', 'death',
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
