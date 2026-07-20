import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/neki_colors.dart';
import '../../core/widgets/animated_gradient_bg.dart';
import 'hadith_provider.dart';

/// Full-screen hadith reader for a section/chapter.
class HadithDetailScreen extends ConsumerWidget {
  final String bookId;
  final HadithSection section;

  const HadithDetailScreen({
    super.key,
    required this.bookId,
    required this.section,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hadithsAsync = ref.watch(
      hadithBySectionProvider((bookId: bookId, sectionNumber: section.sectionNumber)),
    );
    final hour = DateTime.now().hour;

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
                          color: NekiColors.adaptiveTextPrimary(hour), size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: NekiColors.adaptiveTextPrimary(hour),
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Hadith List ──
              Expanded(
                child: hadithsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: NekiColors.emeraldLight),
                  ),
                  error: (_, __) => Center(
                    child: Text(
                      'Failed to load hadiths.',
                      style: TextStyle(
                        color: NekiColors.adaptiveTextSecondary(hour),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  data: (hadiths) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: hadiths.length,
                    itemBuilder: (context, index) => _HadithCard(
                      hadith: hadiths[index],
                      bookId: bookId,
                      hour: hour,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HadithCard extends ConsumerWidget {
  final HadithEntry hadith;
  final String bookId;
  final int hour;

  const _HadithCard({
    required this.hadith,
    required this.bookId,
    required this.hour,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(hadithBookmarkProvider);
    final isBookmarked = bookmarks.contains('$bookId:${hadith.number}');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NekiColors.adaptiveCardColor(hour),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NekiColors.adaptiveCardBorder(hour)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${hadith.number}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (hadith.grade != null) ...[
                const SizedBox(width: 8),
                Text(
                  hadith.grade!,
                  style: TextStyle(
                    fontSize: 11,
                    color: NekiColors.adaptiveTextSecondary(hour),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => ref
                    .read(hadithBookmarkProvider.notifier)
                    .toggle(bookId, hadith.number),
                child: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isBookmarked
                      ? NekiColors.goldLight
                      : NekiColors.adaptiveTextSecondary(hour),
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Arabic
          if (hadith.arabic.isNotEmpty)
            Text(
              hadith.arabic,
              style: GoogleFonts.amiri(
                fontSize: 18,
                height: 1.8,
                color: NekiColors.adaptiveTextPrimary(hour),
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),

          if (hadith.arabic.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: NekiColors.adaptiveTextSecondary(hour).withValues(alpha: 0.15)),
            const SizedBox(height: 8),
          ],

          // Translation
          Text(
            hadith.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.85),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
