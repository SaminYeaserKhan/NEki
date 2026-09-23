import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/bengali_phonetic_helper.dart';
import '../../core/utils/hadith_text_sanitizer.dart';
import '../recitations/providers/reading_settings_provider.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/global_reading_control_bar.dart';
import '../recitations/widgets/pronunciation_checker_modal.dart';
import 'hadith_detail_screen.dart';
import 'hadith_provider.dart';


/// Redesigned Hadith Screen:
/// - 4 Segmented Views: Daily & Wisdom, Bukhari & Collections, Thematic Topics, Saved
/// - Full Bukhari Sharif Integration: 97 chapters with 7,563 hadiths, bilingual metadata
/// - Six Canonical Collections (Sihah Sittah) with direct chapter browsing and chapter search
/// - 7 Prophetic Thematic Topics (Character, Faith, Patience, Charity, Knowledge, Repentance, Family)
/// - Daily Hadith with dynamic "Discover Another / Shuffle" wisdom generator
/// - Instant live search across Hadiths, narrators, topics, Arabic, English, and Bengali
class HadithScreen extends ConsumerWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(hadithViewModeProvider);
    final searchQuery = ref.watch(hadithSearchQueryProvider);
    final searchedHadithsAsync = ref.watch(searchedHadithsProvider);
    final locale = ref.watch(localeProvider);
    final isBn = locale == AppLocale.bangla;
    final hour = ref.watch(currentHourProvider);

    final isSearching = searchQuery.trim().isNotEmpty;

    return CustomScrollView(
      slivers: [
        // ── 1. Global Search Bar ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TextField(
              onChanged: (val) {
                ref.read(hadithSearchQueryProvider.notifier).state = val;
              },
              style: TextStyle(
                fontSize: 13.5,
                color: NekiColors.adaptiveTextPrimary(hour),
              ),
              decoration: InputDecoration(
                hintText: isBn
                    ? 'হাদিস নম্বর, বর্ণনাকারী, বিষয় বা আরবি অনুসন্ধান...'
                    : 'Search Hadith, narrator, topic, Arabic or English...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: NekiColors.adaptiveTextSecondary(hour),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: NekiColors.emeraldLight),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white60),
                        onPressed: () {
                          ref.read(hadithSearchQueryProvider.notifier).state = '';
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
        ),

        // ── 2. Segmented Navigation Bar ──
        if (!isSearching)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _NavigationPill(
                      label: isBn ? 'দৈনিক হেদায়েত' : 'Daily & Wisdom',
                      icon: Icons.auto_awesome_rounded,
                      isSelected: viewMode == HadithViewMode.wisdom,
                      hour: hour,
                      onTap: () => ref.read(hadithViewModeProvider.notifier).state = HadithViewMode.wisdom,
                    ),
                    const SizedBox(width: 8),
                    _NavigationPill(
                      label: isBn ? 'বুখারী ও গ্রন্থসমূহ' : 'Bukhari & Books',
                      icon: Icons.menu_book_rounded,
                      isSelected: viewMode == HadithViewMode.collections,
                      hour: hour,
                      onTap: () => ref.read(hadithViewModeProvider.notifier).state = HadithViewMode.collections,
                    ),
                    const SizedBox(width: 8),
                    _NavigationPill(
                      label: isBn ? 'বিষয়ভিত্তিক' : 'Thematic Topics',
                      icon: Icons.category_rounded,
                      isSelected: viewMode == HadithViewMode.topics,
                      hour: hour,
                      onTap: () => ref.read(hadithViewModeProvider.notifier).state = HadithViewMode.topics,
                    ),
                    const SizedBox(width: 8),
                    _NavigationPill(
                      label: isBn ? 'সংরক্ষিত' : 'Saved',
                      icon: Icons.bookmark_rounded,
                      isSelected: viewMode == HadithViewMode.saved,
                      hour: hour,
                      onTap: () => ref.read(hadithViewModeProvider.notifier).state = HadithViewMode.saved,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── 3. Universal Reading Control Bar ──
        const SliverToBoxAdapter(
          child: GlobalReadingControlBar(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
          ),
        ),

        // ── 4. Dynamic Slivers ──
        if (isSearching)
          ..._buildSearchResultsSlivers(ref, searchedHadithsAsync, searchQuery, hour, locale, isBn)
        else
          ..._buildSegmentedViewSlivers(context, ref, viewMode, hour, locale, isBn),
      ],
    );
  }

  List<Widget> _buildSearchResultsSlivers(
    WidgetRef ref,
    AsyncValue<List<HadithEntry>> searchedHadithsAsync,
    String searchQuery,
    int hour,
    AppLocale locale,
    bool isBn,
  ) {
    return searchedHadithsAsync.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(
              child: CircularProgressIndicator(color: NekiColors.emeraldLight),
            ),
          ),
        ),
      ],
      error: (_, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Failed to search hadiths.',
                style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
              ),
            ),
          ),
        ),
      ],
      data: (hadiths) {
        if (hadiths.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    isBn
                        ? '"$searchQuery" দিয়ে কোনো হাদিস পাওয়া যায়নি।'
                        : 'No hadiths found matching "$searchQuery".',
                    style: TextStyle(
                      fontSize: 13,
                      color: NekiColors.adaptiveTextSecondary(hour),
                    ),
                  ),
                ),
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _HadithStreamCard(
                  hadith: hadiths[index],
                  hour: hour,
                  locale: locale,
                ),
                childCount: hadiths.length,
              ),
            ),
          ),
        ];
      },
    );
  }

  List<Widget> _buildSegmentedViewSlivers(
    BuildContext context,
    WidgetRef ref,
    HadithViewMode mode,
    int hour,
    AppLocale locale,
    bool isBn,
  ) {
    switch (mode) {
      case HadithViewMode.wisdom:
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverToBoxAdapter(
              child: _DailyWisdomContent(hour: hour, locale: locale, isBn: isBn),
            ),
          ),
        ];
      case HadithViewMode.collections:
        return _buildCollectionsSlivers(context, ref, hour, locale, isBn);
      case HadithViewMode.topics:
        return _buildThematicTopicsSlivers(context, ref, hour, locale, isBn);
      case HadithViewMode.saved:
        return _buildSavedHadithsSlivers(context, ref, hour, locale, isBn);
    }
  }

  List<Widget> _buildCollectionsSlivers(
    BuildContext context,
    WidgetRef ref,
    int hour,
    AppLocale locale,
    bool isBn,
  ) {
    final selectedBookId = ref.watch(selectedBookProvider);
    final sectionsAsync = ref.watch(hadithSectionsProvider(selectedBookId));
    final chapterSearch = ref.watch(hadithChapterSearchProvider).trim().toLowerCase();

    final isBukhari = selectedBookId == 'bukhari';
    final selectedBook = hadithBooks.firstWhere(
      (b) => b.id == selectedBookId,
      orElse: () => hadithBooks.first,
    );

    return [
      // ── Canonical Books Switcher ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: hadithBooks.length,
              itemBuilder: (context, index) {
                final book = hadithBooks[index];
                final isSelected = book.id == selectedBookId;
                final name = isBn ? book.nameBengali : book.nameEnglish;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : NekiColors.adaptiveTextPrimary(hour),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: NekiColors.emeraldPrimary,
                    backgroundColor: NekiColors.adaptiveCardColor(hour),
                    side: BorderSide(
                      color: isSelected ? NekiColors.emeraldLight : NekiColors.adaptiveCardBorder(hour),
                    ),
                    onSelected: (_) {
                      ref.read(selectedBookProvider.notifier).state = book.id;
                      ref.read(hadithChapterSearchProvider.notifier).state = '';
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),

      // ── Flagship Book Header Card (Sahih al-Bukhari Highlight) ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isBukhari
                  ? NekiColors.emeraldPrimary.withValues(alpha: 0.16)
                  : NekiColors.adaptiveCardColor(hour),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isBukhari
                    ? NekiColors.goldLight.withValues(alpha: 0.4)
                    : NekiColors.adaptiveCardBorder(hour),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isBukhari
                        ? NekiColors.goldLight.withValues(alpha: 0.2)
                        : NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBukhari ? Icons.stars_rounded : Icons.auto_stories_rounded,
                    color: isBukhari ? NekiColors.goldLight : NekiColors.emeraldLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isBn ? selectedBook.nameBengali : selectedBook.nameEnglish,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: NekiColors.adaptiveTextPrimary(hour),
                            ),
                          ),
                          if (isBukhari) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: NekiColors.gold.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isBn ? 'পূর্ণাঙ্গ ৯৭ অধ্যায়' : 'Full 97 Chapters',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: NekiColors.goldLight,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBukhari
                            ? (isBn
                                ? '৭,৫৬৩টি হাদিস • ইমাম বুখারী (রহ.) • প্রামাণ্য সংকলন'
                                : '7,563 Hadiths • Imam al-Bukhari • 100% Authentic Directory')
                            : (isBn
                                ? '${selectedBook.hadithCount}টি হাদিস • সিহাহ সিত্তাহ'
                                : '${selectedBook.hadithCount} Hadiths • Canonical Six Books'),
                        style: TextStyle(
                          fontSize: 11,
                          color: NekiColors.adaptiveTextSecondary(hour),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ── Filter Chapters Search Box ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (val) {
              ref.read(hadithChapterSearchProvider.notifier).state = val;
            },
            style: TextStyle(
              fontSize: 12.5,
              color: NekiColors.adaptiveTextPrimary(hour),
            ),
            decoration: InputDecoration(
              hintText: isBn
                  ? 'অধ্যায় বা বিষয় খুঁজুন (যেমন: ওহী, সালাত, রোজা)...'
                  : 'Filter chapters (e.g. Revelation, Prayer, Fasting)...',
              hintStyle: TextStyle(
                fontSize: 11.5,
                color: NekiColors.adaptiveTextSecondary(hour),
              ),
              prefixIcon: const Icon(Icons.filter_list_rounded, size: 18, color: NekiColors.emeraldLight),
              suffixIcon: chapterSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white60),
                      onPressed: () {
                        ref.read(hadithChapterSearchProvider.notifier).state = '';
                      },
                    )
                  : null,
              filled: true,
              fillColor: NekiColors.adaptiveCardColor(hour),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: NekiColors.adaptiveCardBorder(hour)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: NekiColors.adaptiveCardBorder(hour)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: NekiColors.emeraldLight, width: 1.1),
              ),
            ),
          ),
        ),
      ),

      // ── Chapters List ──
      ...sectionsAsync.when(
        loading: () => const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: NekiColors.emeraldLight),
              ),
            ),
          ),
        ],
        error: (_, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Failed to load chapters.',
                  style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
                ),
              ),
            ),
          ),
        ],
        data: (sections) {
          final filtered = chapterSearch.isEmpty
              ? sections
              : sections.where((s) {
                  final name = s.name.toLowerCase();
                  final numStr = s.sectionNumber.toString();
                  return name.contains(chapterSearch) || numStr == chapterSearch;
                }).toList();

          if (filtered.isEmpty) {
            return [
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      isBn ? 'কোনো অধ্যায় পাওয়া যায়নি।' : 'No chapters match "$chapterSearch".',
                      style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour), fontSize: 13),
                    ),
                  ),
                ),
              ),
            ];
          }

          return [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final section = filtered[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: NekiColors.adaptiveCardColor(hour),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: NekiColors.adaptiveCardBorder(hour)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HadithDetailScreen(
                                  bookId: selectedBookId,
                                  section: section,
                                ),
                              ),
                            );
                          },
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isBukhari
                                    ? NekiColors.goldLight.withValues(alpha: 0.35)
                                    : NekiColors.emeraldLight.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${section.sectionNumber}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isBukhari ? NekiColors.goldLight : NekiColors.emeraldLight,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            section.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: NekiColors.adaptiveTextPrimary(hour),
                            ),
                          ),
                          subtitle: Text(
                            section.firstHadith == section.lastHadith
                                ? 'Hadith #${section.firstHadith}'
                                : 'Hadiths ${section.firstHadith} – ${section.lastHadith} (${section.hadithCount})',
                            style: TextStyle(
                              fontSize: 11,
                              color: NekiColors.adaptiveTextSecondary(hour),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
          ];
        },
      ),
    ];
  }

  List<Widget> _buildThematicTopicsSlivers(
    BuildContext context,
    WidgetRef ref,
    int hour,
    AppLocale locale,
    bool isBn,
  ) {
    final selectedTopicId = ref.watch(selectedThematicTopicProvider) ?? thematicTopics.first.id;
    final topicHadithsAsync = ref.watch(thematicHadithsProvider(selectedTopicId));

    return [
      // ── Topics Horizontal Selector ──
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: thematicTopics.length,
              itemBuilder: (context, index) {
                final topic = thematicTopics[index];
                final isSelected = topic.id == selectedTopicId;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    avatar: Icon(
                      topic.icon,
                      size: 15,
                      color: isSelected ? Colors.white : topic.color,
                    ),
                    label: Text(
                      isBn ? topic.nameBn : topic.nameEn,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : NekiColors.adaptiveTextPrimary(hour),
                      ),
                    ),
                    selectedColor: topic.color.withValues(alpha: 0.85),
                    backgroundColor: NekiColors.adaptiveCardColor(hour),
                    side: BorderSide(
                      color: isSelected ? topic.color : NekiColors.adaptiveCardBorder(hour),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (_) {
                      ref.read(selectedThematicTopicProvider.notifier).state = topic.id;
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),

      // ── Topic Hadiths List ──
      ...topicHadithsAsync.when(
        loading: () => const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: NekiColors.emeraldLight),
              ),
            ),
          ),
        ],
        error: (_, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Failed to load topic hadiths.',
                  style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
                ),
              ),
            ),
          ),
        ],
        data: (hadiths) {
          if (hadiths.isEmpty) {
            return [
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      isBn ? 'এই বিষয়ের কোনো হাদিস পাওয়া যায়নি।' : 'No hadiths found for this topic.',
                      style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour), fontSize: 13),
                    ),
                  ),
                ),
              ),
            ];
          }

          return [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _HadithStreamCard(
                    hadith: hadiths[index],
                    hour: hour,
                    locale: locale,
                  ),
                  childCount: hadiths.length,
                ),
              ),
            ),
          ];
        },
      ),
    ];
  }

  List<Widget> _buildSavedHadithsSlivers(
    BuildContext context,
    WidgetRef ref,
    int hour,
    AppLocale locale,
    bool isBn,
  ) {
    final savedHadithsAsync = ref.watch(bookmarkedHadithsProvider);

    return savedHadithsAsync.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: NekiColors.emeraldLight),
            ),
          ),
        ),
      ],
      error: (_, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Failed to load saved hadiths.',
                style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
              ),
            ),
          ),
        ),
      ],
      data: (hadiths) {
        if (hadiths.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Center(
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
                        isBn ? 'এখনো কোনো হাদিস সংরক্ষণ করা হয়নি' : 'No Bookmarked Hadiths Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.adaptiveTextPrimary(hour),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isBn
                            ? 'যেকোনো হাদিস পড়ার সময় বুকমার্ক আইকনে চাপ দিয়ে এখানে সংরক্ষণ করুন।'
                            : 'Tap the bookmark icon on any prophetic hadith to save it here for fast reflection.',
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
                          ref.read(hadithViewModeProvider.notifier).state = HadithViewMode.collections;
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NekiColors.emeraldPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(
                          isBn ? 'হাদিস গ্রন্থসমূহ দেখুন' : 'Explore Collections',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _HadithStreamCard(
                  hadith: hadiths[index],
                  hour: hour,
                  locale: locale,
                ),
                childCount: hadiths.length,
              ),
            ),
          ),
        ];
      },
    );
  }
}

// ─────────────────────────────────────────────────────
//  1. Daily & Wisdom View
// ─────────────────────────────────────────────────────

class _DailyWisdomContent extends ConsumerWidget {
  final int hour;
  final AppLocale locale;
  final bool isBn;

  const _DailyWisdomContent({
    required this.hour,
    required this.locale,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(locale);
    final wisdomAsync = ref.watch(dynamicWisdomHadithProvider);
    final audioState = ref.watch(recitationAudioProvider);
    final settings = ref.watch(readingSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Daily Hadith Hero Card with Discovery Shuffle ──
        wisdomAsync.when(
          loading: () => Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NekiColors.adaptiveCardColor(hour),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const CircularProgressIndicator(color: NekiColors.emeraldLight),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (hadith) {
            if (hadith == null) return const SizedBox.shrink();

            final isPlaying = audioState.isPlaying &&
                audioState.type == RecitationType.hadith &&
                audioState.currentVerse == hadith.number;

            final resolvedTranslation = HadithTextSanitizer.resolveTranslation(
              bengali: hadith.bengali,
              english: hadith.english,
              fallbackText: hadith.text,
              locale: locale,
            );

            final resolvedTransliteration = isBn
                ? (hadith.transliterationBn ??
                    (hadith.transliteration != null
                        ? BengaliPhoneticHelper.toBengaliPronunciation(hadith.transliteration!)
                        : ''))
                : (hadith.transliteration ?? '');

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: NekiColors.adaptiveCardColor(hour),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: NekiColors.goldLight.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NekiColors.emeraldPrimary.withValues(alpha: 0.22),
                    NekiColors.adaptiveCardColor(hour),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: NekiColors.goldLight.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_stories_rounded, size: 16, color: NekiColors.goldLight),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.hadithOfTheDay,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: NekiColors.goldLight,
                        ),
                      ),
                      const Spacer(),
                      // Discover Another / Shuffle Button
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(randomHadithSeedProvider.notifier).state++;
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NekiColors.emeraldLight,
                          side: BorderSide(color: NekiColors.emeraldLight.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.shuffle_rounded, size: 13),
                        label: Text(
                          isBn ? 'অন্য হাদিস' : 'Discover',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Narrator attribution
                  if ((hadith.narrator != null && hadith.narrator!.isNotEmpty) ||
                      resolvedTranslation.narrator != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 13, color: NekiColors.goldLight),
                        const SizedBox(width: 5),
                        Text(
                          hadith.narrator?.isNotEmpty == true
                              ? hadith.narrator!
                              : resolvedTranslation.narrator!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: NekiColors.goldLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Translation Prominent & Immediate
                  if (settings.showTranslation && resolvedTranslation.text.isNotEmpty) ...[
                    Text(
                      resolvedTranslation.text,
                      style: TextStyle(
                        fontSize: settings.translationFontSize,
                        height: 1.6,
                        color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Transliteration / Pronunciation
                  if (settings.showTransliteration && resolvedTransliteration.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(top: 2, right: 8),
                            decoration: BoxDecoration(
                              color: NekiColors.goldLight.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isBn ? 'উচ্চারণ' : 'Pronunciation',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: NekiColors.goldLight,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              resolvedTransliteration,
                              style: TextStyle(
                                fontSize: settings.translationFontSize * 0.95,
                                height: 1.5,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFC7E6D5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Arabic Scripture (Clean and compact)
                  if (settings.showArabic && hadith.arabic.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Text(
                        hadith.arabic,
                        style: settings.arabicScript == ArabicScript.uthmanic
                            ? GoogleFonts.amiri(
                                fontSize: settings.arabicFontSize,
                                height: 1.85,
                                color: isPlaying ? const Color(0xFFFFFBEA) : NekiColors.adaptiveTextPrimary(hour),
                              )
                            : GoogleFonts.scheherazadeNew(
                                fontSize: settings.arabicFontSize,
                                height: 1.85,
                                color: isPlaying ? const Color(0xFFFFFBEA) : NekiColors.adaptiveTextPrimary(hour),
                              ),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hadith.reference ?? 'Hadith #${hadith.number}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: NekiColors.emeraldLight,
                          ),
                        ),
                      ),
                      if (hadith.narrator != null && hadith.narrator!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hadith.narrator!,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: NekiColors.adaptiveTextSecondary(hour),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            PronunciationCheckerModal.show(
                              context,
                              title: hadith.reference ?? 'Hadith #${hadith.number}',
                              arabicText: hadith.arabic,
                              transliteration: resolvedTransliteration,
                              translation: resolvedTranslation.text,
                              hadith: hadith,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NekiColors.goldLight,
                            side: BorderSide(color: NekiColors.goldLight.withValues(alpha: 0.45)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.mic_rounded, size: 15),
                          label: Text(
                            isBn ? 'উচ্চারণ যাচাই' : 'Recite & Check',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (isPlaying) {
                              ref.read(recitationAudioProvider.notifier).togglePlayPause();
                            } else {
                              ref.read(recitationAudioProvider.notifier).playHadith(
                                hadith,
                                trackMode: settings.audioTrackMode,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NekiColors.emeraldPrimary,
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
                                ? (isBn ? 'বিরতি' : 'Pause')
                                : (settings.audioTrackMode == AudioTrackMode.translation
                                    ? (isBn ? 'অনুবাদ' : 'Translation')
                                    : (isBn ? 'তিলাওয়াত' : 'Listen')),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        // ── Quick Prophetic Themes Link ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isBn ? 'মূল নবুওয়াতী বিষয়সমূহ' : 'Prophetic Themes',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: NekiColors.adaptiveTextPrimary(hour),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(hadithViewModeProvider.notifier).state = HadithViewMode.topics,
              child: Text(
                isBn ? 'সব দেখুন →' : 'View All →',
                style: const TextStyle(fontSize: 12, color: NekiColors.emeraldLight, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: thematicTopics.length,
            itemBuilder: (context, index) {
              final topic = thematicTopics[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () {
                    ref.read(selectedThematicTopicProvider.notifier).state = topic.id;
                    ref.read(hadithViewModeProvider.notifier).state = HadithViewMode.topics;
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NekiColors.adaptiveCardColor(hour),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: topic.color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(topic.icon, color: topic.color, size: 22),
                        const SizedBox(height: 6),
                        Text(
                          isBn ? topic.nameBn : topic.nameEn,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: NekiColors.adaptiveTextPrimary(hour),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Bukhari Sharif Quick Banner ──
        const SizedBox(height: 20),
        InkWell(
          onTap: () {
            ref.read(selectedBookProvider.notifier).state = 'bukhari';
            ref.read(hadithViewModeProvider.notifier).state = HadithViewMode.collections;
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NekiColors.adaptiveCardColor(hour),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.3)),
              gradient: LinearGradient(
                colors: [
                  NekiColors.gold.withValues(alpha: 0.15),
                  NekiColors.adaptiveCardColor(hour),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: NekiColors.goldLight.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: NekiColors.goldLight, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBn ? 'সহীহ আল-বুখারী (সম্পূর্ণ ৯৭ অধ্যায়)' : 'Sahih al-Bukhari (Complete 97 Chapters)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.adaptiveTextPrimary(hour),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBn ? '৭,৫৬৩টি প্রামাণ্য হাদিসের সম্পূর্ণ ক্যাটালগ' : 'Browse all 7,563 authentic prophetic traditions',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: NekiColors.adaptiveTextSecondary(hour),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: NekiColors.goldLight),
              ],
            ),
          ),
        ),
      ],
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
          color: isSelected ? NekiColors.emeraldPrimary : NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? NekiColors.emeraldLight : NekiColors.adaptiveCardBorder(hour),
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
//  Reusable Hadith Stream Card
// ─────────────────────────────────────────────────────

class _HadithStreamCard extends ConsumerStatefulWidget {
  final HadithEntry hadith;
  final int hour;
  final AppLocale locale;

  const _HadithStreamCard({
    required this.hadith,
    required this.hour,
    required this.locale,
  });

  @override
  ConsumerState<_HadithStreamCard> createState() => _HadithStreamCardState();
}

class _HadithStreamCardState extends ConsumerState<_HadithStreamCard> {
  bool _isArabicExpanded = false;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(recitationAudioProvider);
    final isPlaying = audioState.isPlaying &&
        audioState.type == RecitationType.hadith &&
        audioState.currentVerse == widget.hadith.number;

    final bookmarks = ref.watch(hadithBookmarkProvider);
    final isSaved = bookmarks.contains('${widget.hadith.bookId}:${widget.hadith.number}');
    final isBangla = widget.locale == AppLocale.bangla;
    final settings = ref.watch(readingSettingsProvider);

    final resolved = HadithTextSanitizer.resolveTranslation(
      bengali: widget.hadith.bengali,
      english: widget.hadith.english,
      fallbackText: widget.hadith.text,
      locale: widget.locale,
    );

    final resolvedTransliteration = isBangla
        ? (widget.hadith.transliterationBn ??
            (widget.hadith.transliteration != null
                ? BengaliPhoneticHelper.toBengaliPronunciation(widget.hadith.transliteration!)
                : ''))
        : (widget.hadith.transliteration ?? '');

    final isLongArabic = widget.hadith.arabic.length > 180;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPlaying
            ? NekiColors.emeraldPrimary.withValues(alpha: 0.18)
            : NekiColors.adaptiveCardColor(widget.hour),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaying ? NekiColors.emeraldLight : NekiColors.adaptiveCardBorder(widget.hour),
          width: isPlaying ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.hadith.reference ?? 'Hadith #${widget.hadith.number}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                  ),
                ),
              ),
              if (widget.hadith.grade != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.hadith.grade!,
                    style: const TextStyle(
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
                  ref.read(hadithBookmarkProvider.notifier).toggle(widget.hadith.bookId, widget.hadith.number);
                },
              ),
            ],
          ),

          // ── Narrator attribution ──
          if ((widget.hadith.narrator != null && widget.hadith.narrator!.isNotEmpty) ||
              resolved.narrator != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.hadith.narrator?.isNotEmpty == true
                  ? widget.hadith.narrator!
                  : resolved.narrator!,
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: NekiColors.goldLight.withValues(alpha: 0.9),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Translation First (Prominent & Clean) ──
          if (settings.showTranslation && resolved.text.isNotEmpty) ...[
            Text(
              resolved.text,
              style: TextStyle(
                fontSize: settings.translationFontSize,
                height: 1.6,
                color: NekiColors.adaptiveTextPrimary(widget.hour).withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Transliteration / Pronunciation ──
          if (settings.showTransliteration && resolvedTransliteration.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(top: 2, right: 8),
                    decoration: BoxDecoration(
                      color: NekiColors.goldLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isBangla ? 'উচ্চারণ' : 'Pronunciation',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: NekiColors.goldLight,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      resolvedTransliteration,
                      style: TextStyle(
                        fontSize: settings.translationFontSize * 0.95,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFFC7E6D5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Collapsible Arabic Scripture ──
          if (settings.showArabic && widget.hadith.arabic.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.hadith.arabic,
                    style: settings.arabicScript == ArabicScript.uthmanic
                        ? GoogleFonts.amiri(
                            fontSize: settings.arabicFontSize,
                            height: 1.8,
                            color: isPlaying ? const Color(0xFFFFFBEA) : NekiColors.adaptiveTextPrimary(widget.hour),
                          )
                        : GoogleFonts.scheherazadeNew(
                            fontSize: settings.arabicFontSize,
                            height: 1.8,
                            color: isPlaying ? const Color(0xFFFFFBEA) : NekiColors.adaptiveTextPrimary(widget.hour),
                          ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    maxLines: (_isArabicExpanded || !isLongArabic) ? null : 2,
                    overflow: (_isArabicExpanded || !isLongArabic) ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                  if (isLongArabic) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => setState(() => _isArabicExpanded = !_isArabicExpanded),
                      child: Text(
                        _isArabicExpanded
                            ? (isBangla ? 'সংক্ষেপ করুন ▲' : 'Collapse ▲')
                            : (isBangla ? 'মূল আরবী দেখুন ▼' : 'Show Arabic ▼'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.emeraldLight,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    PronunciationCheckerModal.show(
                      context,
                      title: widget.hadith.reference ?? 'Hadith #${widget.hadith.number}',
                      arabicText: widget.hadith.arabic,
                      transliteration: resolvedTransliteration,
                      translation: resolved.text,
                      hadith: widget.hadith,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.goldLight,
                    side: BorderSide(color: NekiColors.goldLight.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 15),
                  label: Text(
                    isBangla ? 'উচ্চারণ যাচাই' : 'Recite & Check',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isPlaying) {
                      ref.read(recitationAudioProvider.notifier).togglePlayPause();
                    } else {
                      ref.read(recitationAudioProvider.notifier).playHadith(
                        widget.hadith,
                        trackMode: settings.audioTrackMode,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NekiColors.emeraldPrimary,
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
                        ? (isBangla ? 'বিরতি' : 'Pause')
                        : (settings.audioTrackMode == AudioTrackMode.translation
                            ? (isBangla ? 'অনুবাদ' : 'Translation')
                            : (isBangla ? 'তিলাওয়াত' : 'Listen')),
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
