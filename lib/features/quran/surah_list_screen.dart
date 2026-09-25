import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/neki_snack_bar.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/audio_visualizer_widget.dart';
import 'quran_provider.dart';
import 'surah_reader_screen.dart';

/// Redesigned Quran Browser with 3 sub-tabs:
/// 1. Surah (1–114)
/// 2. Juz / Para (1–30)
/// 3. Bookmarks (Saved verses, surahs & reading points)
class SurahListScreen extends ConsumerStatefulWidget {
  const SurahListScreen({super.key});

  @override
  ConsumerState<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends ConsumerState<SurahListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(surahListProvider);
    final juzs = ref.watch(juzListProvider);
    final progress = ref.watch(readingProgressProvider);
    final locale = ref.watch(localeProvider);
    final isBn = locale == AppLocale.bangla;
    final bookmarks = ref.watch(quranBookmarkProvider);
    final bookmarkCount = bookmarks.length;
    final s = S.of(locale);
    final hour = ref.watch(currentHourProvider);

    final filteredSurahs = _searchQuery.isEmpty
        ? surahs
        : surahs.where((surah) {
            final q = _searchQuery.toLowerCase();
            return surah.nameEnglish.toLowerCase().contains(q) ||
                surah.nameArabic.contains(q) ||
                surah.nameTranslation.toLowerCase().contains(q) ||
                surah.number.toString() == q;
          }).toList();

    return Column(
      children: [
        // ── Fully Rounded Capsule Search & Filter Input ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0C2217).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: NekiColors.emeraldLight.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: NekiColors.adaptiveTextPrimary(hour),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
              decoration: InputDecoration(
                filled: false,
                fillColor: Colors.transparent,
                hintText: s.searchSurah,
                hintStyle: TextStyle(
                  color: NekiColors.adaptiveTextSecondary(hour).withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: NekiColors.emeraldLight,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white60),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        // ── Fully Rounded Sub-Tab Selector: Surah / Juz / Bookmarks ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: NekiColors.emeraldPrimary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.35)),
            ),
            dividerColor: Colors.transparent,
            labelColor: NekiColors.emeraldLight,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 12.5),
            tabs: [
              Tab(text: isBn ? 'সূরা (১১৪)' : 'Surahs (114)'),
              Tab(text: isBn ? 'পারা (৩০)' : 'Juz / Para (30)'),
              Tab(
                text: isBn
                    ? (bookmarkCount > 0 ? 'সংরক্ষিত ($bookmarkCount)' : 'সংরক্ষিত')
                    : (bookmarkCount > 0 ? 'Bookmarks ($bookmarkCount)' : 'Bookmarks'),
              ),
            ],
          ),
        ),

        // ── Content Tab Views ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Surah List
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                itemCount: filteredSurahs.length,
                itemBuilder: (context, index) {
                  final surah = filteredSurahs[index];
                  return _SurahTile(surah: surah, hour: hour);
                },
              ),

              // Tab 2: Juz List
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                itemCount: juzs.length,
                itemBuilder: (context, index) {
                  final juz = juzs[index];
                  return _JuzTile(juz: juz, hour: hour);
                },
              ),

              // Tab 3: Saved Bookmarks
              _BookmarksView(
                progress: progress,
                hour: hour,
                locale: locale,
                onExploreTap: () => _tabController.animateTo(0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SurahTile extends ConsumerWidget {
  final SurahInfo surah;
  final int hour;

  const _SurahTile({required this.surah, required this.hour});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(recitationAudioProvider);
    final isThisSurah = audio.currentSurah == surah.number && audio.hasAudio;
    final isPlaying = isThisSurah && audio.isPlaying;
    final isLoading = isThisSurah && audio.isLoading;
    final bookmarks = ref.watch(quranBookmarkProvider);
    final isBookmarked = bookmarks.contains('surah:${surah.number}');
    final isBn = ref.watch(localeProvider) == AppLocale.bangla;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: NekiColors.adaptiveCardColor(hour),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isPlaying
                ? NekiColors.emeraldLight.withValues(alpha: 0.6)
                : NekiColors.adaptiveCardBorder(hour),
            width: isPlaying ? 1.4 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SurahReaderScreen(surahNumber: surah.number),
              ),
            );
          },
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPlaying
                  ? NekiColors.emeraldPrimary.withValues(alpha: 0.4)
                  : NekiColors.emeraldPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPlaying ? NekiColors.goldLight : NekiColors.emeraldLight.withValues(alpha: 0.35),
                width: isPlaying ? 1.5 : 1.0,
              ),
            ),
            child: Center(
              child: Text(
                '${surah.number}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                ),
              ),
            ),
          ),
          title: Text(
            surah.nameEnglish,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isPlaying ? NekiColors.goldLight : NekiColors.adaptiveTextPrimary(hour),
            ),
          ),
          subtitle: Text(
            '${surah.placeOfRevelation} • ${surah.verseCount} Ayahs',
            style: TextStyle(
              fontSize: 11,
              color: NekiColors.adaptiveTextSecondary(hour),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                surah.nameArabic,
                style: GoogleFonts.amiri(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isPlaying ? NekiColors.goldLight : NekiColors.goldLight.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 8),
              // Play Surah Button
              IconButton(
                tooltip: isPlaying ? 'Pause ${surah.nameEnglish}' : 'Play ${surah.nameEnglish}',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? NekiColors.emeraldPrimary
                        : NekiColors.emeraldPrimary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPlaying
                          ? NekiColors.goldLight
                          : NekiColors.emeraldLight.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: isPlaying
                        ? [
                            BoxShadow(
                              color: NekiColors.emeraldPrimary.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: NekiColors.goldLight,
                            ),
                          ),
                        )
                      : Icon(
                          (isThisSurah && audio.autoAdvance && isPlaying) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 20,
                          color: (isThisSurah && audio.autoAdvance && isPlaying) ? Colors.white : NekiColors.emeraldLight,
                        ),
                ),
                onPressed: () {
                  if (isThisSurah && audio.autoAdvance) {
                    ref.read(recitationAudioProvider.notifier).togglePlayPause();
                  } else {
                    ref.read(recitationAudioProvider.notifier).playSurah(surah.number);
                  }
                },
              ),
              const SizedBox(width: 4),
              // Bookmark Surah Button
              IconButton(
                tooltip: isBookmarked
                    ? (isBn ? 'বুকমার্ক সরান' : 'Remove Bookmark')
                    : (isBn ? 'সূরা বুকমার্ক করুন' : 'Bookmark Surah'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 20,
                  color: isBookmarked ? NekiColors.goldLight : Colors.white38,
                ),
                onPressed: () {
                  final willBeBookmarked = !isBookmarked;
                  ref.read(quranBookmarkProvider.notifier).toggle(surah.number);
                  NekiSnackBar.showBookmark(
                    context,
                    isSaved: willBeBookmarked,
                    message: willBeBookmarked
                        ? (isBn
                            ? '${surah.nameEnglish} বুকমার্কে সংরক্ষণ করা হয়েছে'
                            : 'Saved ${surah.nameEnglish} to bookmarks')
                        : (isBn
                            ? '${surah.nameEnglish} বুকমার্ক থেকে সরানো হয়েছে'
                            : 'Removed ${surah.nameEnglish} from bookmarks'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JuzTile extends StatelessWidget {
  final JuzInfo juz;
  final int hour;

  const _JuzTile({required this.juz, required this.hour});

  @override
  Widget build(BuildContext context) {
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SurahReaderScreen(
                  surahNumber: juz.startSurahNumber,
                  initialVerse: juz.startVerse,
                ),
              ),
            );
          },
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: NekiColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                '${juz.number}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: NekiColors.goldLight,
                ),
              ),
            ),
          ),
          title: Text(
            'Juz ${juz.number}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: NekiColors.adaptiveTextPrimary(hour),
            ),
          ),
          subtitle: Text(
            'Starts at ${juz.startSurahName} : Verse ${juz.startVerse}',
            style: TextStyle(
              fontSize: 11,
              color: NekiColors.adaptiveTextSecondary(hour),
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.white38,
          ),
        ),
      ),
    );
  }
}

class _BookmarksView extends ConsumerStatefulWidget {
  final ReadingProgress progress;
  final int hour;
  final AppLocale locale;
  final VoidCallback onExploreTap;

  const _BookmarksView({
    required this.progress,
    required this.hour,
    required this.locale,
    required this.onExploreTap,
  });

  @override
  ConsumerState<_BookmarksView> createState() => _BookmarksViewState();
}

class _BookmarksViewState extends ConsumerState<_BookmarksView> {
  int _filterIndex = 0; // 0: All, 1: Ayahs, 2: Surahs

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkedQuranProvider);
    final isBn = widget.locale == AppLocale.bangla;
    final progressSurahName = quran.getSurahName(widget.progress.surahNumber);
    final progressSurahArabic = quran.getSurahNameArabic(widget.progress.surahNumber);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
      children: [
        // ── 1. Last Saved Reading Point (Resume Card) ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NekiColors.emeraldPrimary.withValues(alpha: 0.22),
                NekiColors.goldLight.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark_added_rounded, color: NekiColors.goldLight, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isBn ? 'সর্বশেষ পড়ার / শোনার অবস্থান' : 'Last Played / Reading Position',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.goldLight,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    progressSurahArabic,
                    style: GoogleFonts.amiri(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.goldLight.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$progressSurahName • ${isBn ? "আয়াত ${widget.progress.verseNumber}" : "Verse ${widget.progress.verseNumber}"}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SurahReaderScreen(
                              surahNumber: widget.progress.surahNumber,
                              initialVerse: widget.progress.verseNumber,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NekiColors.emeraldPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.menu_book_rounded, size: 16),
                      label: Text(
                        isBn ? 'পড়া শুরু করুন' : 'Resume Reading',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(recitationAudioProvider.notifier).playVerse(
                              widget.progress.surahNumber,
                              widget.progress.verseNumber,
                            );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NekiColors.goldLight,
                        side: BorderSide(color: NekiColors.goldLight.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        isBn ? 'তেলাওয়াত শুনুন' : 'Play Ayah',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 2. Saved Bookmarks Content ──
        bookmarksAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: NekiColors.emeraldLight),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                isBn ? 'বুকমার্ক লোড করা যায়নি।' : 'Failed to load bookmarks.',
                style: TextStyle(color: NekiColors.adaptiveTextSecondary(widget.hour)),
              ),
            ),
          ),
          data: (bookmarks) {
            if (bookmarks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
                        isBn ? 'এখনো কোনো আয়াত বা সূরা সংরক্ষণ করা হয়নি' : 'No Bookmarks Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.adaptiveTextPrimary(widget.hour),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isBn
                            ? 'যেকোনো আয়াত বা সূরা পড়ার সময় বুকমার্ক আইকনে চাপ দিয়ে এখানে সংরক্ষণ করুন।'
                            : 'Tap the bookmark icon on any verse or surah while reading to save it here for fast daily access.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: NekiColors.adaptiveTextSecondary(widget.hour),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: widget.onExploreTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NekiColors.emeraldPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.explore_rounded, size: 16),
                        label: Text(
                          isBn ? 'কোরআন খুঁজুন' : 'Explore Surahs',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final ayahs = bookmarks.where((b) => b.isAyah).toList();
            final surahs = bookmarks.where((b) => b.isSurah).toList();

            final displayedItems = _filterIndex == 1
                ? ayahs
                : _filterIndex == 2
                    ? surahs
                    : bookmarks;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row with count
                Row(
                  children: [
                    Text(
                      isBn ? 'সংরক্ষিত বুকমার্ক' : 'Saved Bookmarks',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: NekiColors.adaptiveTextPrimary(widget.hour),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${bookmarks.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.emeraldLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Sub-filter pills if both exist
                if (ayahs.isNotEmpty && surahs.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: isBn ? 'সকল (${bookmarks.length})' : 'All (${bookmarks.length})',
                          isSelected: _filterIndex == 0,
                          onTap: () => setState(() => _filterIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: isBn ? 'আয়াত (${ayahs.length})' : 'Ayahs (${ayahs.length})',
                          isSelected: _filterIndex == 1,
                          onTap: () => setState(() => _filterIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: isBn ? 'সূরা (${surahs.length})' : 'Surahs (${surahs.length})',
                          isSelected: _filterIndex == 2,
                          onTap: () => setState(() => _filterIndex = 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // List of bookmarked cards
                ...displayedItems.map((b) {
                  if (b.isAyah) {
                    return _BookmarkedAyahCard(
                      key: ValueKey('ayah_${b.surahNumber}_${b.verseNumber}'),
                      bookmark: b,
                      hour: widget.hour,
                      locale: widget.locale,
                      isBn: isBn,
                    );
                  } else {
                    return _BookmarkedSurahCard(
                      key: ValueKey('surah_${b.surahNumber}'),
                      bookmark: b,
                      hour: widget.hour,
                      locale: widget.locale,
                      isBn: isBn,
                    );
                  }
                }),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? NekiColors.emeraldPrimary
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? NekiColors.emeraldLight.withValues(alpha: 0.4)
                : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _BookmarkedAyahCard extends ConsumerWidget {
  final QuranBookmark bookmark;
  final int hour;
  final AppLocale locale;
  final bool isBn;

  const _BookmarkedAyahCard({
    super.key,
    required this.bookmark,
    required this.hour,
    required this.locale,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(recitationAudioProvider);
    final isPlaying = audio.isPlaying &&
        audio.type == RecitationType.quran &&
        audio.currentSurah == bookmark.surahNumber &&
        audio.currentVerse == bookmark.verseNumber;

    final translationText = isBn
        ? (bookmark.translationBn ?? bookmark.translationEn ?? '')
        : (bookmark.translationEn ?? bookmark.translationBn ?? '');

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
              : NekiColors.adaptiveCardBorder(hour),
          width: isPlaying ? 1.4 : 1.0,
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
                  '${bookmark.surahNameEn} ${bookmark.surahNumber}:${bookmark.verseNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: NekiColors.emeraldLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bookmark.surahNameAr,
                style: GoogleFonts.amiri(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.goldLight.withValues(alpha: 0.85),
                ),
              ),
              if (isPlaying) ...[
                const SizedBox(width: 8),
                const AudioVisualizerWidget(
                  isPlaying: true,
                  barCount: 3,
                  height: 13,
                  barWidth: 2,
                  color: NekiColors.emeraldLight,
                ),
              ],
              const Spacer(),
              // Remove Bookmark
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: isBn ? 'বুকমার্ক সরান' : 'Remove Bookmark',
                icon: const Icon(
                  Icons.bookmark_rounded,
                  size: 20,
                  color: NekiColors.goldLight,
                ),
                onPressed: () {
                  ref.read(quranBookmarkProvider.notifier).toggle(
                        bookmark.surahNumber,
                        bookmark.verseNumber,
                      );
                  NekiSnackBar.showBookmark(
                    context,
                    isSaved: false,
                    message: isBn
                        ? '${bookmark.surahNameEn} আয়াত ${bookmark.verseNumber} বুকমার্ক থেকে সরানো হয়েছে'
                        : 'Removed ${bookmark.surahNameEn} Verse ${bookmark.verseNumber} from bookmarks',
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Arabic Verse ──
          if (bookmark.arabicText != null && bookmark.arabicText!.isNotEmpty)
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                bookmark.arabicText!,
                style: GoogleFonts.amiriQuran(
                  fontSize: 22,
                  height: 2.1,
                  color: const Color(0xFFFFFBEA),
                  fontWeight: FontWeight.normal,
                ),
                textAlign: TextAlign.right,
              ),
            ),

          if (translationText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              translationText,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: NekiColors.adaptiveTextSecondary(hour),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Action Footer ──
          Row(
            children: [
              // Read in Surah button
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SurahReaderScreen(
                        surahNumber: bookmark.surahNumber,
                        initialVerse: bookmark.verseNumber ?? 1,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: NekiColors.emeraldPrimary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: NekiColors.emeraldLight.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 14, color: NekiColors.emeraldLight),
                      const SizedBox(width: 5),
                      Text(
                        isBn ? 'সূরা পড়ুন' : 'Read in Surah',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.emeraldLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Copy Action
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                tooltip: isBn ? 'কপি করুন' : 'Copy Ayah',
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white54),
                onPressed: () {
                  final textToCopy =
                      '${bookmark.arabicText ?? ""}\n\n$translationText\n(${bookmark.surahNameEn} ${bookmark.surahNumber}:${bookmark.verseNumber})';
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  NekiSnackBar.showSuccess(
                    context,
                    message: isBn ? 'আয়াত কপি করা হয়েছে' : 'Ayah copied to clipboard',
                  );
                },
              ),
              const SizedBox(width: 4),

              // Audio Play/Pause Action
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                tooltip: isPlaying ? 'Pause' : 'Play Ayah',
                icon: Icon(
                  isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_fill_rounded,
                  size: 24,
                  color: isPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                ),
                onPressed: () {
                  if (isPlaying) {
                    ref.read(recitationAudioProvider.notifier).togglePlayPause();
                  } else {
                    ref.read(recitationAudioProvider.notifier).playVerse(
                          bookmark.surahNumber,
                          bookmark.verseNumber!,
                          autoAdvance: false,
                        );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookmarkedSurahCard extends ConsumerWidget {
  final QuranBookmark bookmark;
  final int hour;
  final AppLocale locale;
  final bool isBn;

  const _BookmarkedSurahCard({
    super.key,
    required this.bookmark,
    required this.hour,
    required this.locale,
    required this.isBn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(recitationAudioProvider);
    final isThisSurah = audio.currentSurah == bookmark.surahNumber && audio.hasAudio;
    final isPlaying = isThisSurah && audio.isPlaying;
    final isLoading = isThisSurah && audio.isLoading;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: NekiColors.adaptiveCardColor(hour),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isPlaying
                ? NekiColors.emeraldLight.withValues(alpha: 0.6)
                : NekiColors.adaptiveCardBorder(hour),
            width: isPlaying ? 1.4 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SurahReaderScreen(surahNumber: bookmark.surahNumber),
              ),
            );
          },
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPlaying
                  ? NekiColors.emeraldPrimary.withValues(alpha: 0.4)
                  : NekiColors.emeraldPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: isPlaying ? NekiColors.goldLight : NekiColors.emeraldLight.withValues(alpha: 0.35),
                width: isPlaying ? 1.5 : 1.0,
              ),
            ),
            child: Center(
              child: Text(
                '${bookmark.surahNumber}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                ),
              ),
            ),
          ),
          title: Text(
            bookmark.surahNameEn,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isPlaying ? NekiColors.goldLight : NekiColors.adaptiveTextPrimary(hour),
            ),
          ),
          subtitle: Text(
            '${bookmark.surahNameTranslation} • ${bookmark.totalVerses} Ayahs',
            style: TextStyle(
              fontSize: 11,
              color: NekiColors.adaptiveTextSecondary(hour),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bookmark.surahNameAr,
                style: GoogleFonts.amiri(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isPlaying ? NekiColors.goldLight : NekiColors.goldLight.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 8),
              // Play Surah Button
              IconButton(
                tooltip: isPlaying ? 'Pause' : 'Play',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? NekiColors.emeraldPrimary
                        : NekiColors.emeraldPrimary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPlaying
                          ? NekiColors.goldLight
                          : NekiColors.emeraldLight.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: NekiColors.goldLight,
                            ),
                          ),
                        )
                      : Icon(
                          (isThisSurah && audio.autoAdvance && isPlaying) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 18,
                          color: (isThisSurah && audio.autoAdvance && isPlaying) ? Colors.white : NekiColors.emeraldLight,
                        ),
                ),
                onPressed: () {
                  if (isThisSurah && audio.autoAdvance) {
                    ref.read(recitationAudioProvider.notifier).togglePlayPause();
                  } else {
                    ref.read(recitationAudioProvider.notifier).playSurah(bookmark.surahNumber);
                  }
                },
              ),
              const SizedBox(width: 4),
              // Remove Bookmark Button
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: isBn ? 'বুকমার্ক সরান' : 'Remove Bookmark',
                icon: const Icon(
                  Icons.bookmark_rounded,
                  size: 20,
                  color: NekiColors.goldLight,
                ),
                onPressed: () {
                  ref.read(quranBookmarkProvider.notifier).toggle(bookmark.surahNumber);
                  NekiSnackBar.showBookmark(
                    context,
                    isSaved: false,
                    message: isBn
                        ? '${bookmark.surahNameEn} বুকমার্ক থেকে সরানো হয়েছে'
                        : 'Removed ${bookmark.surahNameEn} from bookmarks',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
