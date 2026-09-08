import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/neki_colors.dart';
import '../providers/reading_settings_provider.dart';

class RecitationSettingsSheet extends ConsumerWidget {
  const RecitationSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const RecitationSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);

    final previewStyle = settings.arabicScript == ArabicScript.uthmanic
        ? GoogleFonts.amiriQuran(
            fontSize: settings.arabicFontSize,
            color: NekiColors.goldLight,
            height: 1.8,
          )
        : GoogleFonts.scheherazadeNew(
            fontSize: settings.arabicFontSize,
            color: NekiColors.goldLight,
            height: 1.8,
          );

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2218).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: NekiColors.emeraldLight.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: NekiColors.emeraldLight, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Reading Display & Typography',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            // ── Reading Mode Switcher ──
            const Text(
              'READING ORIENTATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.7,
                color: Colors.white60,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ModeOptionCard(
                    title: 'Mushaf Mode',
                    subtitle: 'Continuous scripture flow with ۝ medallions',
                    icon: Icons.auto_stories_rounded,
                    isSelected: settings.readingMode == ReadingMode.mushaf,
                    onTap: () => notifier.setReadingMode(ReadingMode.mushaf),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeOptionCard(
                    title: 'Verse Study',
                    subtitle: 'Line-by-line with translation & phonetics',
                    icon: Icons.view_headline_rounded,
                    isSelected: settings.readingMode == ReadingMode.study,
                    onTap: () => notifier.setReadingMode(ReadingMode.study),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Live Sample Preview ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝١',
                    style: previewStyle,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  if (settings.showTranslation) ...[
                    const SizedBox(height: 4),
                    Text(
                      'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
                      style: TextStyle(
                        fontSize: settings.translationFontSize,
                        color: Colors.white70,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Arabic Font Size Slider ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Arabic Font Size',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  '${settings.arabicFontSize.toInt()} pt',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: NekiColors.emeraldLight,
                inactiveTrackColor: Colors.white12,
                thumbColor: NekiColors.goldLight,
              ),
              child: Slider(
                value: settings.arabicFontSize,
                min: 20.0,
                max: 38.0,
                divisions: 9,
                onChanged: (v) => notifier.setArabicFontSize(v),
              ),
            ),

            // ── Script Selector ──
            Row(
              children: [
                const Text(
                  'Arabic Script',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                ChoiceChip(
                  label: const Text('Uthmanic (Hafs)', style: TextStyle(fontSize: 12)),
                  selected: settings.arabicScript == ArabicScript.uthmanic,
                  selectedColor: NekiColors.emeraldPrimary,
                  onSelected: (_) => notifier.setArabicScript(ArabicScript.uthmanic),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('IndoPak (Asian)', style: TextStyle(fontSize: 12)),
                  selected: settings.arabicScript == ArabicScript.indopak,
                  selectedColor: NekiColors.emeraldPrimary,
                  onSelected: (_) => notifier.setArabicScript(ArabicScript.indopak),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Toggles: Transliteration & Translation ──
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Show Pronunciation / Transliteration',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
              activeThumbColor: NekiColors.emeraldLight,
              activeTrackColor: NekiColors.emeraldPrimary,
              value: settings.showTransliteration,
              onChanged: (_) => notifier.toggleTransliteration(),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Show Translation',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
              activeThumbColor: NekiColors.emeraldLight,
              activeTrackColor: NekiColors.emeraldPrimary,
              value: settings.showTranslation,
              onChanged: (_) => notifier.toggleTranslation(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? NekiColors.emeraldPrimary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? NekiColors.emeraldLight : Colors.white12,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? NekiColors.emeraldLight : Colors.white70),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? NekiColors.emeraldLight : Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.25,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
