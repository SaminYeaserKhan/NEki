import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/app_strings.dart';
import 'core/locale/locale_provider.dart';
import 'core/navigation/navigation_providers.dart';
import 'core/theme/neki_colors.dart';
import 'core/theme/neki_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/home_screen.dart';
import 'features/recitations/recitations_screen.dart';
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
    final hour = ref.watch(currentHourProvider);

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