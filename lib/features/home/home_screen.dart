import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/navigation/navigation_providers.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/animated_gradient_bg.dart';
import '../../core/widgets/bento_card.dart';
import '../../core/widgets/home_content_background.dart';
import '../quran/quran_provider.dart';
import '../quran/surah_reader_screen.dart';
import '../tasbih/tasbih_screen.dart';
import '../namaz/screens/namaz_screen.dart';
import '../namaz/widgets/location_selector_sheet.dart';
import '../namaz/widgets/namaz_home_card.dart';
import 'prayer_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _pageController = PageController();

  bool _onScrollNotification(ScrollNotification notification) {
    bool isOverscrollingTop = false;

    if (notification is OverscrollNotification && notification.overscroll < 0) {
      isOverscrollingTop = true;
    } else if (notification is ScrollUpdateNotification && notification.metrics.pixels < -20) {
      // Threshold to prevent accidental trigger on slight bounces
      isOverscrollingTop = true;
    }

    if (isOverscrollingTop && _pageController.page?.round() == 1) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
    return false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = ref.watch(currentHourProvider);

    return Scaffold(
      backgroundColor: NekiColors.nightSurface,
      body: PageView(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        children: [
          _buildHeroPage(context, ref, s, hour),
          _buildContentPage(context, hour, s),
        ],
      ),
    );
  }

  Widget _buildHeroPage(BuildContext context, WidgetRef ref, S s, int hour) {
    return AnimatedGradientHeader(
      minHeight: MediaQuery.of(context).size.height,
      showMosque: true,
      showStars: true,
      bottomPadding: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context, ref, s, hour),
              _buildGreeting(context, s, hour),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _HeroPrayerCard(hour: hour, s: s),
              ),
              const SizedBox(height: 12),
              Expanded(child: _HeroHighlightsCarousel(hour: hour, s: s)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentPage(BuildContext context, int hour, S s) {
    final isBangla = ref.watch(localeProvider) == AppLocale.bangla;

    return HomeContentBackground(
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: SafeArea(
          top: true,
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // ── Return to Sky & Prayers Indicator Pill ──
              SliverToBoxAdapter(
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: NekiColors.adaptiveCardColor(hour).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: NekiColors.adaptiveCardBorder(hour),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 16,
                            color: NekiColors.adaptiveTextSecondary(hour),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isBangla ? 'ওয়াক্ত ও আকাশ' : 'Sky & Prayers',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: NekiColors.adaptiveTextSecondary(hour),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 📖 Recitations (combined Quran / Dua / Hadith) ──
              _buildSectionHeader(s.recitationsSection, hour),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _RecitationChip(
                        icon: Icons.menu_book_rounded,
                        label: s.quranTab,
                        color: NekiColors.emeraldPrimary,
                        hour: hour,
                        onTap: () {
                          // Navigate to Recitations tab, Quran sub-tab
                          final nav = ref.read(navigationIndexProvider.notifier);
                          nav.state = 1;
                        },
                      ),
                      const SizedBox(width: 10),
                      _RecitationChip(
                        icon: Icons.volunteer_activism_rounded,
                        label: s.duaTab,
                        color: const Color(0xFF7E57C2),
                        hour: hour,
                        onTap: () {
                          ref.read(navigationIndexProvider.notifier).state = 1;
                          ref.read(recitationsTabProvider.notifier).state = 1;
                        },
                      ),
                      const SizedBox(width: 10),
                      _RecitationChip(
                        icon: Icons.auto_stories_rounded,
                        label: s.hadithTab,
                        color: NekiColors.gold,
                        hour: hour,
                        onTap: () {
                          ref.read(navigationIndexProvider.notifier).state = 1;
                          ref.read(recitationsTabProvider.notifier).state = 2;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Resume Reading card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _ResumeQuranCard(hour: hour, s: s),
                ),
              ),

              // ── 🕌 Namaz ──
              _buildSectionHeader(s.namazSection, hour),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NamazHomeCard(hour: hour),
                ),
              ),

              // ── 💰 Zakat ──
              _buildSectionHeader(s.zakatSection, hour),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PlaceholderCard(
                    icon: Icons.calculate_rounded,
                    title: s.zakatTitle,
                    subtitle: s.comingSoon,
                    color: const Color(0xFFFF8F00),
                    hour: hour,
                  ),
                ),
              ),

              // ── 📚 Education ──
              _buildSectionHeader(s.educationSection, hour),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PlaceholderCard(
                    icon: Icons.school_rounded,
                    title: s.educationTitle,
                    subtitle: s.comingSoon,
                    color: const Color(0xFF42A5F5),
                    hour: hour,
                  ),
                ),
              ),

              // ── 🛠 Tools ──
              _buildSectionHeader(s.toolsSection, hour),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ToolCard(
                          icon: Icons.touch_app_rounded,
                          title: s.tasbih,
                          subtitle: s.counter,
                          hour: hour,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TasbihScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ToolCard(
                          icon: Icons.explore_rounded,
                          title: s.qibla,
                          subtitle: s.comingSoon,
                          hour: hour,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ToolCard(
                          icon: Icons.calendar_month_rounded,
                          title: s.calendar,
                          subtitle: s.hijri,
                          hour: hour,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int hour) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: NekiColors.adaptiveSectionHeader(hour),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref, S s, int hour) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      child: Row(
        children: [
          Text(
            'NEki',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: NekiColors.adaptiveTextPrimary(hour),
              letterSpacing: 1,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          // Language toggle
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.emeraldLight,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          PopupMenuButton<NekiTimeTheme>(
            icon: Icon(
              ref.watch(timeThemeProvider).icon,
              color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.8),
              size: 24,
            ),
            color: NekiColors.adaptiveCardColor(hour),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (theme) => ref.read(timeThemeProvider.notifier).setTheme(theme),
            itemBuilder: (context) => NekiTimeTheme.values.map((theme) {
              return PopupMenuItem<NekiTimeTheme>(
                value: theme,
                child: Row(
                  children: [
                    Icon(
                      theme.icon,
                      color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      theme.label,
                      style: TextStyle(
                        color: NekiColors.adaptiveTextPrimary(hour),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(BuildContext context, S s, int hour) {
    String greeting;
    if (hour >= 4 && hour < 12) {
      greeting = s.goodMorning;
    } else if (hour >= 12 && hour < 17) {
      greeting = s.goodAfternoon;
    } else if (hour >= 17 && hour < 20) {
      greeting = s.goodEvening;
    } else {
      greeting = s.goodNight;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.assalamuAlaikum,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: NekiColors.adaptiveTextSecondary(hour),
              letterSpacing: 0.5,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            greeting,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: NekiColors.adaptiveTextPrimary(hour),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// Navigation providers are in core/navigation/navigation_providers.dart

// ─────────────────────────────────────────────────────
//  Recitation Chip (Quran / Dua / Hadith in a row)
// ─────────────────────────────────────────────────────

class _RecitationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int hour;
  final VoidCallback onTap;

  const _RecitationChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: NekiColors.adaptiveCardColor(hour),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: NekiColors.adaptiveTextPrimary(hour),
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Placeholder Card (for unbuilt features)
// ─────────────────────────────────────────────────────

class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int hour;

  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.hour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NekiColors.adaptiveCardColor(hour),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.adaptiveTextPrimary(hour),
                      decoration: TextDecoration.none,
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: NekiColors.adaptiveTextSecondary(hour),
                      decoration: TextDecoration.none,
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Tool Card
// ─────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int hour;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NekiColors.adaptiveCardBorder(hour)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28,
                color: NekiColors.adaptiveIconColor(hour)),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.adaptiveTextPrimary(hour),
                  decoration: TextDecoration.none,
                )),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: NekiColors.adaptiveTextSecondary(hour),
                  decoration: TextDecoration.none,
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Resume Quran Card
// ─────────────────────────────────────────────────────

class _ResumeQuranCard extends ConsumerWidget {
  final int hour;
  final S s;

  const _ResumeQuranCard({required this.hour, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(readingProgressProvider);
    final surahs = ref.watch(surahListProvider);
    final surahName = surahs.isNotEmpty &&
            progress.surahNumber >= 1 &&
            progress.surahNumber <= surahs.length
        ? surahs[progress.surahNumber - 1].nameEnglish
        : 'Al-Fatihah';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SurahReaderScreen(
            surahNumber: progress.surahNumber,
            initialVerse: progress.verseNumber,
          ),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NekiColors.goldLight.withValues(alpha: 0.15),
              NekiColors.emeraldPrimary.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.bookmark_rounded, size: 24, color: NekiColors.goldLight),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.resume,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NekiColors.goldLight,
                        decoration: TextDecoration.none,
                      )),
                  Text('$surahName • Verse ${progress.verseNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: NekiColors.adaptiveTextPrimary(hour),
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: NekiColors.adaptiveTextSecondary(hour), size: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Hero Prayer Card
// ─────────────────────────────────────────────────────

class _HeroPrayerCard extends ConsumerWidget {
  final int hour;
  final S s;

  const _HeroPrayerCard({required this.hour, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BentoCard(
      height: 215,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NamazScreen()),
        );
      },
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          NekiColors.adaptiveCardColor(hour),
          NekiColors.adaptiveCardColor(hour).withValues(alpha: 0.7),
        ],
      ),
      child: ref.watch(liveWaqtProvider).when(
        loading: () => Center(
          child: CircularProgressIndicator(
              color: NekiColors.adaptiveTextPrimary(hour)),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_rounded,
                  color: NekiColors.adaptiveTextSecondary(hour), size: 32),
              const SizedBox(height: 8),
              Text(s.enableLocation,
                  style: TextStyle(
                    color: NekiColors.adaptiveTextSecondary(hour),
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (waqt) {
          final is24Hour = ref.watch(is24HourProvider);
          final timeFormatter =
              is24Hour ? DateFormat('HH:mm') : DateFormat('h:mm a');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(waqt.dateDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: NekiColors.adaptiveTextPrimary(hour)
                                  .withValues(alpha: 0.8),
                              decoration: TextDecoration.none,
                            )),
                        if (waqt.hijriDisplay != null)
                          Text(waqt.hijriDisplay!,
                              style: TextStyle(
                                fontSize: 12,
                                color: NekiColors.adaptiveTextSecondary(hour),
                                decoration: TextDecoration.none,
                              )),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Location Pill
                      GestureDetector(
                        onTap: () => LocationSelectorSheet.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: NekiColors.adaptiveTextSecondary(hour)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                waqt.isAutoGps
                                    ? Icons.my_location_rounded
                                    : Icons.location_on_rounded,
                                size: 12,
                                color: NekiColors.adaptiveTextPrimary(hour),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                waqt.locationDisplay.split(',').first,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: NekiColors.adaptiveTextPrimary(hour),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: NekiColors.adaptiveTextSecondary(hour),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 12H / 24H Toggle
                      GestureDetector(
                        onTap: () => ref.read(is24HourProvider.notifier).toggle(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: NekiColors.adaptiveTextSecondary(hour)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(is24Hour ? '24H' : '12H',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: NekiColors.adaptiveTextPrimary(hour),
                                decoration: TextDecoration.none,
                              )),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(waqt.currentWaqtName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: NekiColors.adaptiveTextSecondary(hour),
                            decoration: TextDecoration.none,
                          )),
                      const SizedBox(height: 2),
                      Text(timeFormatter.format(waqt.currentTime),
                          style: GoogleFonts.inter(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: NekiColors.adaptiveTextPrimary(hour),
                            height: 1.0,
                            decoration: TextDecoration.none,
                          )),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Schedule',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: NekiColors.adaptiveTextPrimary(hour),
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: NekiColors.adaptiveTextPrimary(hour),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${s.endsAt} ${timeFormatter.format(waqt.currentWaqtEnd)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: NekiColors.adaptiveTextSecondary(hour),
                    decoration: TextDecoration.none,
                  )),
              const Spacer(),
              Divider(
                  color: NekiColors.adaptiveTextSecondary(hour)
                      .withValues(alpha: 0.2),
                  height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.schedule_rounded,
                        size: 16,
                        color: NekiColors.adaptiveTextSecondary(hour)),
                    const SizedBox(width: 6),
                    Text('${s.next}: ${waqt.nextWaqtName}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: NekiColors.adaptiveTextPrimary(hour),
                          decoration: TextDecoration.none,
                        )),
                  ]),
                  Text(timeFormatter.format(waqt.nextWaqtStart),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: NekiColors.adaptiveTextPrimary(hour)
                            .withValues(alpha: 0.8),
                        decoration: TextDecoration.none,
                      )),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Hero Highlights Carousel
// ─────────────────────────────────────────────────────

class _HeroHighlightsCarousel extends StatefulWidget {
  final int hour;
  final S s;

  const _HeroHighlightsCarousel({required this.hour, required this.s});

  @override
  State<_HeroHighlightsCarousel> createState() => _HeroHighlightsCarouselState();
}

class _HeroHighlightsCarouselState extends State<_HeroHighlightsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late Stream<int> _timerStream;
  late StreamSubscription<int> _timerSubscription;

  @override
  void initState() {
    super.initState();
    // Auto-scroll every 5 seconds
    _timerStream = Stream.periodic(const Duration(seconds: 5), (i) => i);
    _timerSubscription = _timerStream.listen((_) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % 3;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timerSubscription.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildInspirationSlide(),
              _buildGoalSlide(),
              _buildEventSlide(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? NekiColors.adaptiveTextPrimary(widget.hour)
                    : NekiColors.adaptiveTextPrimary(widget.hour).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSlideContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NekiColors.adaptiveCardColor(widget.hour).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: NekiColors.adaptiveCardBorder(widget.hour).withValues(alpha: 0.5)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildInspirationSlide() {
    return _buildSlideContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded,
                  color: NekiColors.emeraldLight, size: 20),
              const SizedBox(width: 8),
              const Text('Ayah of the Day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                    decoration: TextDecoration.none,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              '"So remember Me; I will remember you. And be grateful to Me and do not deny Me." (2:152)',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: NekiColors.adaptiveTextPrimary(widget.hour),
                height: 1.4,
                decoration: TextDecoration.none,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSlide() {
    return _buildSlideContainer(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 0.65, // Example progress
                    strokeWidth: 4,
                    color: const Color(0xFF42A5F5),
                    backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  ),
                  const Text(
                    '65%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF42A5F5),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Monthly Quran Goal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF42A5F5),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You are on track to finish by the end of the month!',
                  style: TextStyle(
                    fontSize: 13,
                    color: NekiColors.adaptiveTextPrimary(widget.hour).withValues(alpha: 0.8),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSlide() {
    return _buildSlideContainer(
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star_rounded,
                color: Color(0xFFFF8F00), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sunnah Fasting',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF8F00),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Today is Monday. It is recommended to observe Sunnah fasting.',
                  style: TextStyle(
                    fontSize: 13,
                    color: NekiColors.adaptiveTextPrimary(widget.hour).withValues(alpha: 0.8),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}