import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import 'quran_provider.dart';
import 'surah_reader_screen.dart';

/// Redesigned Quran Browser with 3 sub-tabs:
/// 1. Surah (1–114)
/// 2. Juz / Para (1–30)
/// 3. Bookmarks (Saved reading points)
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
            tabs: const [
              Tab(text: 'Surahs (114)'),
              Tab(text: 'Juz / Para (30)'),
              Tab(text: 'Bookmarks'),
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
              _BookmarksView(progress: progress, hour: hour),
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
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 20,
                          color: isPlaying ? Colors.white : NekiColors.emeraldLight,
                        ),
                ),
                onPressed: () {
                  if (isPlaying) {
                    ref.read(recitationAudioProvider.notifier).togglePlayPause();
                  } else if (isThisSurah && audio.currentVerse != null) {
                    ref.read(recitationAudioProvider.notifier).togglePlayPause();
                  } else {
                    ref.read(recitationAudioProvider.notifier).playSurah(surah.number);
                  }
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

class _BookmarksView extends StatelessWidget {
  final ReadingProgress progress;
  final int hour;

  const _BookmarksView({required this.progress, required this.hour});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                NekiColors.emeraldPrimary.withValues(alpha: 0.25),
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
                  const Icon(Icons.bookmark_added_rounded, color: NekiColors.goldLight, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Last Saved Reading Point',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Surah ${progress.surahNumber} • Verse ${progress.verseNumber}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NekiColors.emeraldLight,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SurahReaderScreen(
                        surahNumber: progress.surahNumber,
                        initialVerse: progress.verseNumber,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: NekiColors.emeraldPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.menu_book_rounded, size: 16),
                label: const Text('Resume Reading'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
