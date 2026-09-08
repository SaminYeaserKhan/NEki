import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/painters/islamic_pattern_painter.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../dua/dua_screen.dart';
import '../hadith/hadith_screen.dart';
import '../quran/quran_provider.dart';
import '../quran/surah_list_screen.dart';
import '../quran/surah_reader_screen.dart';
import '../quran/utils/quran_verse_helper.dart';
import 'widgets/persistent_recitation_player.dart';
import 'widgets/pronunciation_checker_modal.dart';

/// Redesigned Recitations Hub:
/// - Clean, uncluttered layout with sacred Islamic geometry
/// - Sliding glass tab switcher for Quran, Dua, and Hadith
/// - Compact Resume Reading pill and Vocalize Studio shortcut
/// - Floating persistent audio dock above bottom navigation
class RecitationsScreen extends ConsumerWidget {
  const RecitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(recitationsTabProvider);
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = ref.watch(currentHourProvider);
    final progress = ref.watch(readingProgressProvider);
    final surahs = ref.watch(surahListProvider);

    final currentSurahName = surahs.isNotEmpty && progress.surahNumber <= surahs.length
        ? surahs[progress.surahNumber - 1].nameEnglish
        : 'Al-Fatihah';

    return DefaultTabController(
      length: 3,
      initialIndex: tabIndex,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          controller.addListener(() {
            if (!controller.indexIsChanging) {
              ref.read(recitationsTabProvider.notifier).state = controller.index;
            }
          });

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // ── 1. Background Time Gradient & Sacred Geometry ──
                const _RecitationsBackground(),

                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: IslamicPatternPainter(
                        hour: hour,
                        opacity: 0.035,
                        tileSize: 96.0,
                      ),
                    ),
                  ),
                ),

                // ── 2. Content Structure ──
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Header Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 16, 6),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.recitations,
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: NekiColors.adaptiveTextPrimary(hour),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                Text(
                                  'Holy Quran • Authentic Duas • Hadiths',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: NekiColors.adaptiveTextSecondary(hour),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),

                            // Vocalize Studio Quick Shortcut
                            IconButton(
                              tooltip: 'Open Vocalize Studio',
                              icon: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: NekiColors.emeraldLight.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.mic_external_on_rounded,
                                  color: NekiColors.emeraldLight,
                                  size: 18,
                                ),
                              ),
                              onPressed: () {
                                final arabic = QuranVerseHelper.getCleanVerseText(
                                  progress.surahNumber,
                                  progress.verseNumber,
                                  verseEndSymbol: false,
                                );
                                final trans = QuranVerseHelper.getVerseTranslation(
                                  progress.surahNumber,
                                  progress.verseNumber,
                                  ref.read(translationProvider),
                                );
                                PronunciationCheckerModal.show(
                                  context,
                                  title: '$currentSurahName • Ayah ${progress.verseNumber}',
                                  arabicText: arabic,
                                  transliteration: null,
                                  translation: trans,
                                  surahNumber: progress.surahNumber,
                                  verseNumber: progress.verseNumber,
                                );
                              },
                            ),

                            // Language Toggle
                            GestureDetector(
                              onTap: () => ref.read(localeProvider.notifier).toggle(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: NekiColors.adaptiveCardColor(hour),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: NekiColors.adaptiveCardBorder(hour)),
                                ),
                                child: Text(
                                  ref.watch(localeProvider) == AppLocale.bangla ? 'বাং' : 'EN',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: NekiColors.emeraldLight,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Compact Resume Reading Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SurahReaderScreen(
                                surahNumber: progress.surahNumber,
                                initialVerse: progress.verseNumber,
                              ),
                            ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  NekiColors.emeraldPrimary.withValues(alpha: 0.22),
                                  NekiColors.goldLight.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: NekiColors.emeraldLight.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bookmark_rounded,
                                  size: 16,
                                  color: NekiColors.goldLight,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'RESUME: ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: NekiColors.goldLight,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '$currentSurahName (Ayah ${progress.verseNumber})',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: NekiColors.adaptiveTextPrimary(hour),
                                      decoration: TextDecoration.none,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: NekiColors.adaptiveTextSecondary(hour),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Fully Rounded Capsule Tab Switcher
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C2217).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: NekiColors.emeraldLight.withValues(alpha: 0.22),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: controller,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [NekiColors.emeraldPrimary, Color(0xFF1E5638)],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: NekiColors.emeraldLight.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: NekiColors.emeraldPrimary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: NekiColors.adaptiveTextSecondary(hour),
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.menu_book_rounded, size: 16),
                                  const SizedBox(width: 6),
                                  Text(s.quranTab),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.volunteer_activism_rounded, size: 16),
                                  const SizedBox(width: 6),
                                  Text(s.duaTab),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_stories_rounded, size: 16),
                                  const SizedBox(width: 6),
                                  Text(s.hadithTab),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tab View Content
                      Expanded(
                        child: TabBarView(
                          controller: controller,
                          children: const [
                            SurahListScreen(),
                            DuaScreen(),
                            HadithScreen(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 3. Persistent Floating Audio Player ──
                const PersistentRecitationPlayer(bottomPadding: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecitationsBackground extends ConsumerWidget {
  const _RecitationsBackground();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = ref.watch(currentHourProvider);
    final colors = NekiColors.gradientForHour(hour);

    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.first,
            const Color(0xFF09160F),
          ],
        ),
      ),
    );
  }
}
