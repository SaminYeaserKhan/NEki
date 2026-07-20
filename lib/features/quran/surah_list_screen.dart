import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import 'quran_provider.dart';
import 'surah_reader_screen.dart';

/// Full list of all 114 surahs with search, tap to read.
class SurahListScreen extends ConsumerStatefulWidget {
  const SurahListScreen({super.key});

  @override
  ConsumerState<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends ConsumerState<SurahListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final surahs = ref.watch(surahListProvider);
    final progress = ref.watch(readingProgressProvider);
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = DateTime.now().hour;

    final filtered = _searchQuery.isEmpty
        ? surahs
        : surahs.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.nameEnglish.toLowerCase().contains(q) ||
                s.nameArabic.contains(q) ||
                s.number.toString() == q;
          }).toList();

    // When embedded in RecitationsScreen, no background/header needed.
    // The parent provides the gradient and tab bar.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Resume reading card ──
        if (progress.surahNumber > 1 || progress.verseNumber > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _ResumeCard(progress: progress, hour: hour, s: s),
          ),

        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: NekiColors.adaptiveCardColor(hour),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NekiColors.adaptiveCardBorder(hour)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: NekiColors.adaptiveTextPrimary(hour),
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
              decoration: InputDecoration(
                hintText: s.searchSurah,
                hintStyle: TextStyle(
                  color: NekiColors.adaptiveTextSecondary(hour),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: NekiColors.adaptiveTextSecondary(hour),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        // ── Surah list ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return _SurahTile(surah: filtered[index], hour: hour, s: s);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
//  Resume Reading Card
// ─────────────────────────────────────────────────────

class _ResumeCard extends ConsumerWidget {
  final ReadingProgress progress;
  final int hour;
  final S s;

  const _ResumeCard({required this.progress, required this.hour, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(surahListProvider);
    final surah = surahs[progress.surahNumber - 1];

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SurahReaderScreen(
              surahNumber: progress.surahNumber,
              initialVerse: progress.verseNumber,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              NekiColors.emeraldPrimary.withValues(alpha: 0.3),
              NekiColors.goldLight.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: NekiColors.goldLight.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.bookmark_rounded, color: NekiColors.goldLight, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.resume,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NekiColors.goldLight,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    '${surah.nameEnglish} • ${s.verses} ${progress.verseNumber}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.adaptiveTextPrimary(hour),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: NekiColors.adaptiveTextSecondary(hour),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Individual Surah Tile
// ─────────────────────────────────────────────────────

class _SurahTile extends StatelessWidget {
  final SurahInfo surah;
  final int hour;
  final S s;

  const _SurahTile({required this.surah, required this.hour, required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SurahReaderScreen(surahNumber: surah.number),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NekiColors.adaptiveCardBorder(hour)),
            ),
            child: Row(
              children: [
                // Surah number badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${surah.number}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.emeraldLight,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name + metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.nameEnglish,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: NekiColors.adaptiveTextPrimary(hour),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${surah.placeOfRevelation == "Mecca" ? s.meccan : s.medinan} • ${surah.verseCount} ${s.verses}',
                        style: TextStyle(
                          fontSize: 12,
                          color: NekiColors.adaptiveTextSecondary(hour),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arabic name
                Text(
                  surah.nameArabic,
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.adaptiveTextPrimary(hour)
                        .withValues(alpha: 0.8),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
