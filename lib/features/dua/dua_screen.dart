import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/bengali_phonetic_helper.dart';
import '../recitations/providers/reading_settings_provider.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/global_reading_control_bar.dart';
import '../recitations/widgets/pronunciation_checker_modal.dart';
import 'dua_detail_screen.dart';
import 'dua_list_screen.dart';
import 'dua_provider.dart';

/// Redesigned Devotional Dua Screen:
/// - 4 Intuitive Segmented Modes: Explore (For You), Categories, Short Duas (to Memorize), Saved
/// - "I am feeling..." Emotion-based Dua filter carousel
/// - Daily Featured reflection supplication
/// - Instant multi-lingual search across Arabic, English, and Bengali
class DuaScreen extends ConsumerWidget {
  const DuaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(duaViewModeProvider);
    final searchQuery = ref.watch(duaSearchQueryProvider);
    final searchedDuasAsync = ref.watch(searchedDuasProvider);
    final locale = ref.watch(localeProvider);
    final isBn = locale == AppLocale.bangla;
    final hour = ref.watch(currentHourProvider);

    final isSearching = searchQuery.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Header Search Bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: TextField(
            onChanged: (val) {
              ref.read(duaSearchQueryProvider.notifier).state = val;
            },
            style: TextStyle(
              fontSize: 13.5,
              color: NekiColors.adaptiveTextPrimary(hour),
            ),
            decoration: InputDecoration(
              hintText: isBn
                  ? 'দো‘আ, অর্থ বা আরবি অনুসন্ধান...'
                  : 'Search Duas, meaning or Arabic...',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: NekiColors.adaptiveTextSecondary(hour),
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: NekiColors.emeraldLight),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white60),
                      onPressed: () {
                        ref.read(duaSearchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              filled: true,
              fillColor: NekiColors.adaptiveCardColor(hour),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: NekiColors.adaptiveCardBorder(hour)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: NekiColors.adaptiveCardBorder(hour)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: NekiColors.emeraldLight, width: 1.2),
              ),
            ),
          ),
        ),

        // ── 2. Segmented Navigation Bar (Hidden when actively searching) ──
        if (!isSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _NavigationPill(
                    label: isBn ? 'আপনার জন্য' : 'For You',
                    icon: Icons.explore_rounded,
                    isSelected: viewMode == DuaViewMode.explore,
                    hour: hour,
                    onTap: () => ref.read(duaViewModeProvider.notifier).state = DuaViewMode.explore,
                  ),
                  const SizedBox(width: 8),
                  _NavigationPill(
                    label: isBn ? 'বিষয়সমূহ' : 'Categories',
                    icon: Icons.grid_view_rounded,
                    isSelected: viewMode == DuaViewMode.categories,
                    hour: hour,
                    onTap: () => ref.read(duaViewModeProvider.notifier).state = DuaViewMode.categories,
                  ),
                  const SizedBox(width: 8),
                  _NavigationPill(
                    label: isBn ? 'ছোট দো‘আ' : 'Short Duas',
                    icon: Icons.auto_stories_rounded,
                    isSelected: viewMode == DuaViewMode.shortDuas,
                    hour: hour,
                    onTap: () => ref.read(duaViewModeProvider.notifier).state = DuaViewMode.shortDuas,
                  ),
                  const SizedBox(width: 8),
                  _NavigationPill(
                    label: isBn ? 'সংরক্ষিত' : 'Saved',
                    icon: Icons.bookmark_rounded,
                    isSelected: viewMode == DuaViewMode.saved,
                    hour: hour,
                    onTap: () => ref.read(duaViewModeProvider.notifier).state = DuaViewMode.saved,
                  ),
                ],
              ),
            ),
          ),

        // ── 2.5. Universal Reading Control Bar ──
        const GlobalReadingControlBar(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
        ),

        // ── 3. Dynamic Body View ──
        Expanded(
          child: isSearching
              ? _buildSearchResults(ref, searchedDuasAsync, searchQuery, hour, locale, isBn)
              : _buildSegmentedView(context, ref, viewMode, hour, locale, isBn),
        ),
      ],
    );
  }

  Widget _buildSearchResults(
    WidgetRef ref,
    AsyncValue<List<Dua>> searchedDuasAsync,
    String searchQuery,
    int hour,
    AppLocale locale,
    bool isBn,
  ) {
    return searchedDuasAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NekiColors.emeraldLight),
      ),
      error: (_, _) => Center(
        child: Text(
          'Failed to search duas.',
          style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
        ),
      ),
      data: (duas) {
        if (duas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                isBn
                    ? '"$searchQuery" দিয়ে কোনো দো‘আ পাওয়া যায়নি।'
                    : 'No duas found matching "$searchQuery".',
                style: TextStyle(
                  fontSize: 13,
                  color: NekiColors.adaptiveTextSecondary(hour),
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          itemCount: duas.length,
          itemBuilder: (context, index) => _DuaStreamCard(
            dua: duas[index],
            allDuas: duas,
            index: index,
            hour: hour,
            locale: locale,
          ),
        );
      },
    );
  }

  Widget _buildSegmentedView(
    BuildContext context,
    WidgetRef ref,
    DuaViewMode mode,
    int hour,
    AppLocale locale,
    bool isBn,
  ) {
    switch (mode) {
      case DuaViewMode.explore:
        return _ExploreView(hour: hour, locale: locale, isBn: isBn);
      case DuaViewMode.categories:
        return _CategoriesView(hour: hour, locale: locale, isBn: isBn);
      case DuaViewMode.shortDuas:
        return _ShortDuasView(hour: hour, locale: locale, isBn: isBn);
      case DuaViewMode.saved:
        return _SavedDuasView(hour: hour, locale: locale, isBn: isBn);
    }
  }
}

// ─────────────────────────────────────────────────────
//  1. Explore View (Emotions + Featured Supplications)
// ─────────────────────────────────────────────────────

class _ExploreView extends ConsumerWidget {
  final int hour;
  final AppLocale locale;
  final bool isBn;

  const _ExploreView({
    required this.hour,
    required this.locale,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEmotion = ref.watch(selectedEmotionProvider);
    final emotionDuasAsync = ref.watch(duasByEmotionProvider);
    final dailyDuaAsync = ref.watch(dailyFeaturedDuaProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        // ── "I am feeling..." Emotion Carousel ──
        Text(
          isBn ? 'আপনার মনের অনুভূতি অনুযায়ী দো‘আ' : 'I am feeling...',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: NekiColors.adaptiveTextPrimary(hour),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: duaEmotions.length,
            itemBuilder: (context, index) {
              final emotion = duaEmotions[index];
              final isSelected = selectedEmotion == emotion.id;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  avatar: Icon(
                    emotion.icon,
                    size: 16,
                    color: isSelected ? Colors.white : emotion.color,
                  ),
                  label: Text(
                    isBn ? emotion.nameBn : emotion.nameEn,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : NekiColors.adaptiveTextPrimary(hour),
                    ),
                  ),
                  selectedColor: emotion.color.withValues(alpha: 0.85),
                  backgroundColor: NekiColors.adaptiveCardColor(hour),
                  side: BorderSide(
                    color: isSelected ? emotion.color : NekiColors.adaptiveCardBorder(hour),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    ref.read(selectedEmotionProvider.notifier).state = val ? emotion.id : null;
                  },
                ),
              );
            },
          ),
        ),

        // ── C. Emotion Filtered Results OR Daily Featured Supplication ──
        if (selectedEmotion != null) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBn ? 'অনুভূতির সাথে সম্পর্কিত দো‘আ' : 'Supplications for your heart',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: NekiColors.adaptiveTextSecondary(hour),
                ),
              ),
              TextButton.icon(
                onPressed: () => ref.read(selectedEmotionProvider.notifier).state = null,
                icon: const Icon(Icons.close_rounded, size: 14, color: Colors.white60),
                label: Text(
                  isBn ? 'সব দেখুন' : 'Reset Filter',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          emotionDuasAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: NekiColors.emeraldLight),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (duas) {
              if (duas.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      isBn ? 'এই অনুভূতির জন্য কোনো দো‘আ পাওয়া যায়নি।' : 'No duas found for this emotion.',
                      style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour), fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                children: List.generate(
                  duas.length,
                  (i) => _DuaStreamCard(
                    dua: duas[i],
                    allDuas: duas,
                    index: i,
                    hour: hour,
                    locale: locale,
                  ),
                ),
              );
            },
          ),
        ] else ...[
          // ── D. Daily Featured Dua Card ──
          const SizedBox(height: 20),
          Text(
            isBn ? 'দৈনিক ভাবনার দো‘আ' : 'Daily Reflection Supplication',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: NekiColors.adaptiveTextPrimary(hour),
            ),
          ),
          const SizedBox(height: 10),
          dailyDuaAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (dua) {
              if (dua == null) return const SizedBox.shrink();
              return _DuaStreamCard(
                dua: dua,
                allDuas: [dua],
                index: 0,
                hour: hour,
                locale: locale,
                isFeatured: true,
              );
            },
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
//  2. Categories View
// ─────────────────────────────────────────────────────

class _CategoriesView extends ConsumerWidget {
  final int hour;
  final AppLocale locale;
  final bool isBn;

  const _CategoriesView({
    required this.hour,
    required this.locale,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(duaCategoriesProvider);
    final s = S.of(locale);

    return categoriesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NekiColors.emeraldLight),
      ),
      error: (_, _) => Center(
        child: Text(
          s.failedToLoad,
          style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
        ),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Text(
              'No categories found.',
              style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return _CategoryCard(
              category: cat,
              locale: locale,
              hour: hour,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DuaListScreen(categoryId: cat.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
//  3. Popular Short Duas to Memorize View
// ─────────────────────────────────────────────────────

class _ShortDuasView extends ConsumerStatefulWidget {
  final int hour;
  final AppLocale locale;
  final bool isBn;

  const _ShortDuasView({
    required this.hour,
    required this.locale,
    required this.isBn,
  });

  @override
  ConsumerState<_ShortDuasView> createState() => _ShortDuasViewState();
}

class _ShortDuasViewState extends ConsumerState<_ShortDuasView> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final shortDuasAsync = ref.watch(popularShortDuasProvider);

    return shortDuasAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NekiColors.emeraldLight),
      ),
      error: (_, _) => Center(
        child: Text(
          widget.isBn ? 'ছোট দো‘আ লোড করা যায়নি।' : 'Failed to load Short Duas.',
          style: TextStyle(color: NekiColors.adaptiveTextSecondary(widget.hour)),
        ),
      ),
      data: (allShortDuas) {
        if (allShortDuas.isEmpty) {
          return Center(
            child: Text(
              widget.isBn ? 'কোনো ছোট দো‘আ পাওয়া যায়নি।' : 'No short duas found.',
              style: TextStyle(color: NekiColors.adaptiveTextSecondary(widget.hour)),
            ),
          );
        }

        final filtered = allShortDuas.where((d) {
          if (_selectedFilter == 'all') return true;
          if (_selectedFilter == 'daily') {
            return d.category == 'daily' || d.category == 'social';
          }
          if (_selectedFilter == 'prayer') {
            return d.category == 'prayer';
          }
          if (_selectedFilter == 'quranic') {
            return d.isQuranic;
          }
          if (_selectedFilter == 'protection') {
            return d.category == 'protection' || d.category == 'hardship';
          }
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [
            // ── Inspiring Header Card ──
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NekiColors.emeraldPrimary.withValues(alpha: 0.22),
                    NekiColors.adaptiveCardColor(widget.hour),
                  ],
                ),
                border: Border.all(
                  color: NekiColors.emeraldLight.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: NekiColors.emeraldLight,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isBn ? 'মুখস্থ করার মতো ছোট দো‘আ' : 'Popular Short Duas to Memorize',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: NekiColors.adaptiveTextPrimary(widget.hour),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.isBn
                              ? 'দৈনন্দিন জীবনে বহুল পঠিত ও সহজে মুখস্থযোগ্য বিশুদ্ধ দো‘আসমূহ'
                              : 'Essential, authentic short supplications for daily life and prayer',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: NekiColors.adaptiveTextSecondary(widget.hour),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Category Filters ──
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip('all', widget.isBn ? 'সব দো‘আ (${allShortDuas.length})' : 'All (${allShortDuas.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('daily', widget.isBn ? 'দৈনন্দিন জীবন' : 'Daily Life'),
                  const SizedBox(width: 8),
                  _buildFilterChip('prayer', widget.isBn ? 'সালাত ও যিকির' : 'Salah & Prayer'),
                  const SizedBox(width: 8),
                  _buildFilterChip('quranic', widget.isBn ? 'কুরআনের দো‘আ' : 'Quranic'),
                  const SizedBox(width: 8),
                  _buildFilterChip('protection', widget.isBn ? 'সুরক্ষা ও বিপদ' : 'Protection'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Dua Cards Stream ──
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    widget.isBn
                        ? 'এই বিভাগে কোনো দো‘আ পাওয়া যায়নি।'
                        : 'No duas found in this category.',
                    style: TextStyle(color: NekiColors.adaptiveTextSecondary(widget.hour)),
                  ),
                ),
              )
            else
              ...List.generate(
                filtered.length,
                (i) => _DuaStreamCard(
                  dua: filtered[i],
                  allDuas: filtered,
                  index: i,
                  hour: widget.hour,
                  locale: widget.locale,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String id, String label) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? NekiColors.emeraldPrimary
              : NekiColors.adaptiveCardColor(widget.hour),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? NekiColors.emeraldLight : NekiColors.adaptiveCardBorder(widget.hour),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : NekiColors.adaptiveTextPrimary(widget.hour),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  4. Saved Duas (Bookmarks) View
// ─────────────────────────────────────────────────────

class _SavedDuasView extends ConsumerWidget {
  final int hour;
  final AppLocale locale;
  final bool isBn;

  const _SavedDuasView({
    required this.hour,
    required this.locale,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedDuasAsync = ref.watch(bookmarkedDuasProvider);

    return savedDuasAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NekiColors.emeraldLight),
      ),
      error: (_, _) => Center(
        child: Text(
          'Failed to load saved duas.',
          style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
        ),
      ),
      data: (duas) {
        if (duas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_border_rounded,
                      size: 40,
                      color: NekiColors.emeraldLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isBn ? 'এখনো কোনো দো‘আ সংরক্ষণ করা হয়নি' : 'No Bookmarked Duas Yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.adaptiveTextPrimary(hour),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isBn
                        ? 'যেকোনো দো‘আ পড়ার সময় বুকমার্ক আইকনে চাপ দিয়ে এখানে সংরক্ষণ করুন।'
                        : 'Tap the bookmark icon on any supplication to save it here for fast daily access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: NekiColors.adaptiveTextSecondary(hour),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(duaViewModeProvider.notifier).state = DuaViewMode.explore;
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NekiColors.emeraldPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.explore_rounded, size: 16),
                    label: Text(
                      isBn ? 'দো‘আ খুঁজুন' : 'Explore Duas',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          itemCount: duas.length,
          itemBuilder: (context, index) => _DuaStreamCard(
            dua: duas[index],
            allDuas: duas,
            index: index,
            hour: hour,
            locale: locale,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
//  Reusable Navigation Pill
// ─────────────────────────────────────────────────────

class _NavigationPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final int hour;
  final VoidCallback onTap;

  const _NavigationPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? NekiColors.emeraldPrimary
              : NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? NekiColors.emeraldLight
                : NekiColors.adaptiveCardBorder(hour),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : NekiColors.emeraldLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : NekiColors.adaptiveTextPrimary(hour),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Reusable Dua Stream Card
// ─────────────────────────────────────────────────────

class _DuaStreamCard extends ConsumerWidget {
  final Dua dua;
  final List<Dua> allDuas;
  final int index;
  final int hour;
  final AppLocale locale;
  final bool isFeatured;

  const _DuaStreamCard({
    required this.dua,
    required this.allDuas,
    required this.index,
    required this.hour,
    required this.locale,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readingSettingsProvider);
    final audioState = ref.watch(recitationAudioProvider);
    final isPlaying = audioState.isPlaying &&
        audioState.type == RecitationType.dua &&
        audioState.currentVerse == dua.id;

    final bookmarks = ref.watch(duaBookmarkProvider);
    final isSaved = bookmarks.contains(dua.id);

    final translationText = locale == AppLocale.bangla && dua.bengali != null
        ? dua.bengali!
        : dua.description;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPlaying
            ? NekiColors.emeraldPrimary.withValues(alpha: 0.18)
            : NekiColors.adaptiveCardColor(hour),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaying
              ? NekiColors.emeraldLight
              : (isFeatured
                  ? NekiColors.goldLight.withValues(alpha: 0.35)
                  : NekiColors.adaptiveCardBorder(hour)),
          width: isPlaying || isFeatured ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dua.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: NekiColors.emeraldLight,
                  ),
                ),
              ),
              if (dua.isQuranic) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: NekiColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: NekiColors.goldLight.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'Quranic',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.goldLight,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                icon: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 19,
                  color: isSaved ? NekiColors.goldLight : Colors.white38,
                ),
                onPressed: () {
                  ref.read(duaBookmarkProvider.notifier).toggle(dua.id);
                },
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white38),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DuaDetailScreen(
                        duas: allDuas,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dua.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: NekiColors.adaptiveTextPrimary(hour),
            ),
          ),
          if (settings.showArabic) ...[
            const SizedBox(height: 10),
            Text(
              dua.arabic,
              style: settings.arabicScript == ArabicScript.uthmanic
                  ? GoogleFonts.amiriQuran(
                      fontSize: settings.arabicFontSize,
                      height: 1.9,
                      color: isPlaying ? const Color(0xFFFFFBEA) : NekiColors.adaptiveTextPrimary(hour),
                    )
                  : GoogleFonts.scheherazadeNew(
                      fontSize: settings.arabicFontSize,
                      height: 1.9,
                      color: isPlaying ? const Color(0xFFFFFBEA) : NekiColors.adaptiveTextPrimary(hour),
                    ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ],
          if (settings.showTransliteration && dua.transliteration.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              locale == AppLocale.bangla
                  ? (dua.transliterationBn ??
                      BengaliPhoneticHelper.toBengaliPronunciation(dua.transliteration))
                  : dua.transliteration,
              style: TextStyle(
                fontSize: (settings.translationFontSize - 1.5).clamp(11.0, 18.0),
                fontStyle: locale == AppLocale.bangla ? FontStyle.normal : FontStyle.italic,
                color: NekiColors.goldLight,
                height: 1.45,
              ),
            ),
          ],
          if (settings.showTranslation) ...[
            const SizedBox(height: 8),
            Text(
              translationText,
              style: TextStyle(
                fontSize: settings.translationFontSize,
                height: 1.5,
                color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.88),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    PronunciationCheckerModal.show(
                      context,
                      title: dua.title,
                      arabicText: dua.arabic,
                      transliteration: dua.transliteration,
                      translation: translationText,
                      dua: dua,
                      surahNumber: dua.surahNumber,
                      verseNumber: dua.verseNumber,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.goldLight,
                    side: BorderSide(color: NekiColors.goldLight.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 15),
                  label: const Text('Recite & Check', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isPlaying) {
                      ref.read(recitationAudioProvider.notifier).togglePlayPause();
                    } else {
                      ref.read(recitationAudioProvider.notifier).playDua(dua);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: settings.audioTrackMode == AudioTrackMode.translation
                        ? NekiColors.gold
                        : NekiColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : (settings.audioTrackMode == AudioTrackMode.translation
                            ? Icons.record_voice_over_rounded
                            : Icons.volume_up_rounded),
                    size: 15,
                  ),
                  label: Text(
                    isPlaying
                        ? (locale == AppLocale.bangla ? 'থামান' : 'Pause')
                        : (settings.audioTrackMode == AudioTrackMode.translation
                            ? (locale == AppLocale.bangla ? 'অনুবাদ' : 'Translation')
                            : (locale == AppLocale.bangla ? 'তিলাওয়াত' : (dua.isQuranic ? 'Alafasy' : 'Recitation'))),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Category Card
// ─────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final DuaCategory category;
  final AppLocale locale;
  final int hour;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.locale,
    required this.hour,
    required this.onTap,
  });

  IconData _iconForCategory(String id) {
    switch (id) {
      case 'daily':
        return Icons.wb_sunny_rounded;
      case 'prayer':
        return Icons.mosque_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'hardship':
        return Icons.favorite_rounded;
      case 'protection':
        return Icons.shield_rounded;
      case 'social':
        return Icons.people_rounded;
      case 'ramadan':
        return Icons.nightlight_round;
      case 'death':
        return Icons.menu_book_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  Color _colorForCategory(String id) {
    switch (id) {
      case 'daily':
        return const Color(0xFFFFB74D);
      case 'prayer':
        return NekiColors.emeraldLight;
      case 'travel':
        return const Color(0xFF4FC3F7);
      case 'family':
        return const Color(0xFFE57373);
      case 'hardship':
        return const Color(0xFF9575CD);
      case 'protection':
        return const Color(0xFF4DB6AC);
      case 'social':
        return const Color(0xFF81C784);
      case 'ramadan':
        return NekiColors.goldLight;
      case 'death':
        return const Color(0xFFBDBDBD);
      default:
        return NekiColors.emeraldMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(category.id);
    final name = locale == AppLocale.bangla ? category.nameBn : category.nameEn;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconForCategory(category.id), color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.adaptiveTextPrimary(hour),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.count} duas',
                  style: TextStyle(
                    fontSize: 12,
                    color: NekiColors.adaptiveTextSecondary(hour),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
