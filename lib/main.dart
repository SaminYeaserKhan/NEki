import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/app_strings.dart';
import 'core/locale/locale_provider.dart';
import 'core/navigation/navigation_providers.dart';
import 'core/theme/neki_colors.dart';
import 'core/theme/neki_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/dua/dua_screen.dart';
import 'features/hadith/hadith_screen.dart';
import 'features/home/home_screen.dart';
import 'features/quran/surah_list_screen.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: NekiApp(),
    ),
  );
}

class NekiApp extends ConsumerWidget {
  const NekiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Neki',
      debugShowCheckedModeBanner: false,
      theme: NekiTheme.light,
      darkTheme: NekiTheme.dark,
      themeMode: themeMode,
      home: const _AppEntry(),
    );
  }
}

/// Entry point that shows the splash screen first, then navigates
/// to the main navigation shell.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _splashDone = false;

  void _onSplashComplete() {
    if (mounted) {
      setState(() => _splashDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashScreen(onComplete: _onSplashComplete);
    }
    return const MainNavigationShell();
  }
}

// Navigation providers are in core/navigation/navigation_providers.dart

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = DateTime.now().hour;

    final screens = [
      const HomeScreen(),
      const RecitationsScreen(),
      // Social placeholder
      Center(
        child: Text(
          s.comingSoon,
          style: TextStyle(
            fontSize: 24,
            color: NekiColors.adaptiveTextPrimary(hour),
            decoration: TextDecoration.none,
          ),
        ),
      ),
      // Profile placeholder
      Center(
        child: Text(
          s.comingSoon,
          style: TextStyle(
            fontSize: 24,
            color: NekiColors.adaptiveTextPrimary(hour),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(currentIndex),
          child: screens[currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(navigationIndexProvider.notifier).state = index;
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.grid_view_rounded),
            label: s.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_rounded),
            label: s.recitations,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_alt_rounded),
            label: s.socialNav,
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_circle_rounded),
            label: s.profile,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Recitations Screen — Quran / Dua / Hadith sub-tabs
// ─────────────────────────────────────────────────────

class RecitationsScreen extends ConsumerWidget {
  const RecitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(recitationsTabProvider);
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = DateTime.now().hour;

    return DefaultTabController(
      length: 3,
      initialIndex: tabIndex,
      child: Builder(
        builder: (context) {
          // Keep provider in sync when user swipes tabs
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
                // Background gradient
                const _RecitationsBackground(),

                // Content
                SafeArea(
                  child: Column(
                    children: [
                      // ── Header ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Row(
                          children: [
                            Text(
                              s.recitations,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: NekiColors.adaptiveTextPrimary(hour),
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () =>
                                  ref.read(localeProvider.notifier).toggle(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: NekiColors.adaptiveCardColor(hour),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: NekiColors.adaptiveCardBorder(hour)),
                                ),
                                child: Text(
                                  ref.watch(localeProvider) == AppLocale.bangla
                                      ? 'বাং'
                                      : 'EN',
                                  style: TextStyle(
                                    fontSize: 13,
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

                      // ── Tab bar ──
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: NekiColors.adaptiveCardColor(hour),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: NekiColors.adaptiveCardBorder(hour)),
                        ),
                        child: TabBar(
                          controller: controller,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          dividerColor: Colors.transparent,
                          labelColor: NekiColors.adaptiveTextPrimary(hour),
                          unselectedLabelColor:
                              NekiColors.adaptiveTextSecondary(hour),
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                          tabs: [
                            Tab(text: s.quranTab),
                            Tab(text: s.duaTab),
                            Tab(text: s.hadithTab),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Tab content ──
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RecitationsBackground extends StatelessWidget {
  const _RecitationsBackground();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final colors = NekiColors.gradientForHour(hour);

    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }
}