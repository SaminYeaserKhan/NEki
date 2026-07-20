import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import 'hadith_browse_screen.dart';
import 'hadith_provider.dart';

/// Hadith collections screen — shows 6 book cards + Daily Hadith hero.
class HadithScreen extends ConsumerWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = DateTime.now().hour;

    // Embedded in RecitationsScreen — parent provides gradient/header.
    return CustomScrollView(
      slivers: [
        // ── Hadith of the Day ──
        SliverToBoxAdapter(
          child: _DailyHadithCard(hour: hour, s: s),
        ),

        // ── Collections section header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              s.browseByCollection,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: NekiColors.adaptiveTextPrimary(hour),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),

        // ── Collection Grid ──
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final book = hadithBooks[index];
                return _BookCard(
                  book: book,
                  locale: locale,
                  hour: hour,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          HadithBrowseScreen(bookId: book.id),
                    ),
                  ),
                );
              },
              childCount: hadithBooks.length,
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
//  Daily Hadith Hero Card
// ─────────────────────────────────────────────────────

class _DailyHadithCard extends ConsumerWidget {
  final int hour;
  final S s;

  const _DailyHadithCard({required this.hour, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyHadithProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: NekiColors.goldLight.withValues(alpha: 0.15),
          ),
        ),
        child: dailyAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: NekiColors.goldLight),
            ),
          ),
          error: (_, __) => Text(
            'Unable to load daily hadith.',
            style: TextStyle(
              color: NekiColors.adaptiveTextSecondary(hour),
              decoration: TextDecoration.none,
            ),
          ),
          data: (hadith) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded,
                      color: NekiColors.goldLight, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    s.hadithOfTheDay,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: NekiColors.goldLight,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${hadith.hadithNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: NekiColors.adaptiveTextSecondary(hour),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                hadith.arabic,
                style: GoogleFonts.amiri(
                  fontSize: 20,
                  height: 1.8,
                  color: NekiColors.adaptiveTextPrimary(hour),
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Divider(
                  color: NekiColors.adaptiveTextSecondary(hour)
                      .withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              Text(
                hadith.translation,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: NekiColors.adaptiveTextPrimary(hour)
                      .withValues(alpha: 0.85),
                  decoration: TextDecoration.none,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                '— ${hadith.bookName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: NekiColors.adaptiveTextSecondary(hour),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Book Card
// ─────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final HadithBook book;
  final AppLocale locale;
  final int hour;
  final VoidCallback onTap;

  const _BookCard({
    required this.book,
    required this.locale,
    required this.hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = locale == AppLocale.bangla ? book.nameBengali : book.nameEnglish;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: NekiColors.emeraldLight.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.auto_stories_rounded,
                  color: NekiColors.emeraldLight, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.adaptiveTextPrimary(hour),
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${book.hadithCount} hadiths',
                  style: TextStyle(
                    fontSize: 11,
                    color: NekiColors.adaptiveTextSecondary(hour),
                    decoration: TextDecoration.none,
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
