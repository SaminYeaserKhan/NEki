import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/widgets/animated_gradient_bg.dart';
import 'hadith_detail_screen.dart';
import 'hadith_provider.dart';

/// Browse hadiths within a collection, organized by section/chapter.
class HadithBrowseScreen extends ConsumerWidget {
  final String bookId;

  const HadithBrowseScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(hadithSectionsProvider(bookId));
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = DateTime.now().hour;

    // Find book name
    final book = hadithBooks.firstWhere((b) => b.id == bookId);
    final bookName =
        locale == AppLocale.bangla ? book.nameBengali : book.nameEnglish;

    return AnimatedGradientBackground(
      showMosque: false,
      showStars: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded,
                          color: NekiColors.adaptiveTextPrimary(hour),
                          size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookName,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: NekiColors.adaptiveTextPrimary(hour),
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${book.hadithCount} hadiths • ${s.sections}',
                            style: TextStyle(
                              fontSize: 12,
                              color: NekiColors.adaptiveTextSecondary(hour),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Sections List ──
              Expanded(
                child: sectionsAsync.when(
                  loading: () => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                            color: NekiColors.emeraldLight),
                        const SizedBox(height: 12),
                        Text(
                          s.loadingCollection,
                          style: TextStyle(
                            color: NekiColors.adaptiveTextSecondary(hour),
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      s.failedToLoad,
                      style: TextStyle(
                        color: NekiColors.adaptiveTextSecondary(hour),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  data: (sections) {
                    if (sections.isEmpty) {
                      return Center(
                        child: Text(
                          'No sections available.',
                          style: TextStyle(
                            color: NekiColors.adaptiveTextSecondary(hour),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return _SectionTile(
                          section: section,
                          bookId: bookId,
                          hour: hour,
                          s: s,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HadithDetailScreen(
                                bookId: bookId,
                                section: section,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
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
//  Section Tile
// ─────────────────────────────────────────────────────

class _SectionTile extends StatelessWidget {
  final HadithSection section;
  final String bookId;
  final int hour;
  final S s;
  final VoidCallback onTap;

  const _SectionTile({
    required this.section,
    required this.bookId,
    required this.hour,
    required this.s,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NekiColors.adaptiveCardBorder(hour)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '${section.sectionNumber}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.emeraldLight,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: NekiColors.adaptiveTextPrimary(hour),
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${section.hadithCount} hadiths',
                    style: TextStyle(
                      fontSize: 12,
                      color: NekiColors.adaptiveTextSecondary(hour),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: NekiColors.adaptiveTextSecondary(hour),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
