import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import 'hadith_detail_screen.dart';
import 'hadith_provider.dart';

/// Flattened, intuitive Hadith Screen:
/// - Quick horizontal book switcher for the 6 Major Collections
/// - Daily Hadith Hero Card
/// - Direct chapter & section list without multi-level nested hops
class HadithScreen extends ConsumerWidget {
  const HadithScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBookId = ref.watch(selectedBookProvider);
    final sectionsAsync = ref.watch(hadithSectionsProvider(selectedBookId));
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = ref.watch(currentHourProvider);

    return CustomScrollView(
      slivers: [
        // ── 1. Daily Hadith Hero ──
        SliverToBoxAdapter(
          child: _DailyHadithCard(hour: hour, s: s),
        ),

        // ── 2. Six Canonical Books Horizontal Switcher ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.browseByCollection,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.adaptiveTextPrimary(hour),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: hadithBooks.length,
                    itemBuilder: (context, index) {
                      final book = hadithBooks[index];
                      final isSelected = book.id == selectedBookId;
                      final name = locale == AppLocale.bangla
                          ? book.nameBengali
                          : book.nameEnglish;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : NekiColors.adaptiveTextPrimary(hour),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: NekiColors.emeraldPrimary,
                          backgroundColor: NekiColors.adaptiveCardColor(hour),
                          side: BorderSide(
                            color: isSelected
                                ? NekiColors.emeraldLight
                                : NekiColors.adaptiveCardBorder(hour),
                          ),
                          onSelected: (_) {
                            ref.read(selectedBookProvider.notifier).state = book.id;
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 3. Sections & Chapters Header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              'Chapters & Topics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: NekiColors.adaptiveTextSecondary(hour),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),

        // ── 4. Chapters List for Selected Book ──
        sectionsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: NekiColors.emeraldLight),
              ),
            ),
          ),
          error: (_, _) => SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load chapters.',
                  style: TextStyle(color: NekiColors.adaptiveTextSecondary(hour)),
                ),
              ),
            ),
          ),
          data: (sections) => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final section = sections[index];
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: Text(
                            '${section.sectionNumber}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: NekiColors.emeraldLight,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        section.name,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.adaptiveTextPrimary(hour),
                        ),
                      ),
                      subtitle: Text(
                        '${section.hadithCount} Hadiths',
                        style: TextStyle(
                          fontSize: 11.5,
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
                },
                childCount: sections.length,
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }
}

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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: NekiColors.goldLight.withValues(alpha: 0.2),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NekiColors.emeraldPrimary.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: dailyAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: NekiColors.emeraldLight),
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (hadith) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories_rounded, size: 16, color: NekiColors.goldLight),
                  const SizedBox(width: 8),
                  Text(
                    s.hadithOfTheDay,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: NekiColors.goldLight,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    hadith.bookName,
                    style: TextStyle(
                      fontSize: 11,
                      color: NekiColors.adaptiveTextSecondary(hour),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
              ),
              const SizedBox(height: 8),
              Text(
                hadith.translation,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.85),
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
