import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/widgets/animated_gradient_bg.dart';
import 'dua_provider.dart';

/// Full-screen dua reader with PageView for swiping between duas.
/// Shows 3 texts: Arabic, pronunciation, and translation.
class DuaDetailScreen extends ConsumerStatefulWidget {
  final List<Dua> duas;
  final int initialIndex;

  const DuaDetailScreen({
    super.key,
    required this.duas,
    required this.initialIndex,
  });

  @override
  ConsumerState<DuaDetailScreen> createState() => _DuaDetailScreenState();
}

class _DuaDetailScreenState extends ConsumerState<DuaDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
    final hour = DateTime.now().hour;

    return AnimatedGradientBackground(
      showMosque: false,
      showStars: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
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
                      child: Text(
                        widget.duas[_currentIndex].title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: NekiColors.adaptiveTextPrimary(hour),
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Page indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: NekiColors.adaptiveCardColor(hour),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.duas.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.adaptiveTextPrimary(hour),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Page View ──
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.duas.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, index) {
                    return _DuaPage(
                      dua: widget.duas[index],
                      locale: locale,
                      hour: hour,
                      s: s,
                    );
                  },
                ),
              ),

              // ── Bottom navigation arrows ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavButton(
                      icon: Icons.arrow_back_rounded,
                      enabled: _currentIndex > 0,
                      hour: hour,
                      onTap: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                    // Dot indicators (max 7 visible)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        widget.duas.length > 7 ? 7 : widget.duas.length,
                        (i) {
                          final dotIndex = widget.duas.length > 7
                              ? (_currentIndex - 3).clamp(0, widget.duas.length - 7) + i
                              : i;
                          return Container(
                            width: dotIndex == _currentIndex ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: dotIndex == _currentIndex
                                  ? NekiColors.emeraldLight
                                  : NekiColors.adaptiveTextSecondary(hour)
                                      .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      ),
                    ),
                    _NavButton(
                      icon: Icons.arrow_forward_rounded,
                      enabled: _currentIndex < widget.duas.length - 1,
                      hour: hour,
                      onTap: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ],
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
//  Single Dua Page content
// ─────────────────────────────────────────────────────

class _DuaPage extends StatelessWidget {
  final Dua dua;
  final AppLocale locale;
  final int hour;
  final S s;

  const _DuaPage({
    required this.dua,
    required this.locale,
    required this.hour,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Arabic text ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NekiColors.adaptiveCardColor(hour),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: NekiColors.goldLight.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              dua.arabic,
              style: GoogleFonts.amiriQuran(
                fontSize: 26,
                height: 2.0,
                color: NekiColors.adaptiveTextPrimary(hour),
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ),

          const SizedBox(height: 16),

          // ── Pronunciation / Transliteration ──
          if (dua.transliteration.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NekiColors.goldLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: NekiColors.goldLight.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.record_voice_over_rounded,
                          size: 16,
                          color: NekiColors.goldLight.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Text(
                        s.pronunciation,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.goldLight.withValues(alpha: 0.7),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dua.transliteration,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      height: 1.7,
                      color: NekiColors.goldLight.withValues(alpha: 0.9),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── Translation ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NekiColors.adaptiveCardColor(hour),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: NekiColors.adaptiveCardBorder(hour)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.translate_rounded,
                        size: 16,
                        color: NekiColors.adaptiveTextSecondary(hour)),
                    const SizedBox(width: 8),
                    Text(
                      s.translation,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: NekiColors.adaptiveTextSecondary(hour),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  dua.description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.7,
                    color: NekiColors.adaptiveTextPrimary(hour),
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

// ─────────────────────────────────────────────────────
//  Navigation Button
// ─────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final int hour;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? NekiColors.adaptiveCardColor(hour)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? NekiColors.adaptiveCardBorder(hour)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          color: enabled
              ? NekiColors.adaptiveTextPrimary(hour)
              : NekiColors.adaptiveTextSecondary(hour).withValues(alpha: 0.3),
          size: 22,
        ),
      ),
    );
  }
}
