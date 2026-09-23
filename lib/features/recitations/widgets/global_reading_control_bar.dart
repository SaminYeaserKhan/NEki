import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/neki_colors.dart';
import '../providers/reading_settings_provider.dart';
import '../providers/recitation_audio_provider.dart';
import 'recitation_settings_sheet.dart';

/// Redesigned, perfectly symmetrical frosted-glass floating control island for Quran, Dua, and Hadith pages.
/// Symmetry Architecture:
/// - Left Group (3 items, 102px): [ ع ] [ Abc ] [ 文A ] (Text elements toggles)
/// - Left Spacer
/// - Hairline Divider (|)
/// - Center Group (1 item, ~84px): [ 🔊 Arabic / 🗣️ Translation ] (Dead-center audio track toggle)
/// - Hairline Divider (|)
/// - Right Spacer
/// - Right Group (3 items, 102px): [ A ] [ EN / বাং ] [ ⚙️ Settings ]
/// - Both outer groups have identical 32×32 geometry and equal pixel widths, ensuring mathematical and visual symmetry.
class GlobalReadingControlBar extends ConsumerWidget {
  final EdgeInsetsGeometry padding;
  final bool showModeSelector;

  const GlobalReadingControlBar({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 10),
    this.showModeSelector = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readingSettingsProvider);
    final settingsNotifier = ref.read(readingSettingsProvider.notifier);
    final locale = ref.watch(localeProvider);
    final isBn = locale == AppLocale.bangla;

    return Padding(
      padding: padding,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 44,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2016).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: NekiColors.emeraldLight.withValues(alpha: 0.22),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Left Group: 3 Content Element Buttons (102px total) ──
                  _ElementButton(
                    label: 'ع',
                    tooltip: isBn ? 'আরবি মূলপাঠ' : 'Arabic Scripture',
                    isActive: settings.showArabic,
                    isArabic: true,
                    onTap: () async {
                      final allowed = await settingsNotifier.toggleArabic();
                      if (!allowed && context.mounted) {
                        _showMinGuardToast(context, isBn);
                      }
                    },
                  ),
                  const SizedBox(width: 3),

                  _ElementButton(
                    label: isBn ? 'আ' : 'Abc',
                    tooltip: isBn ? 'উচ্চারণ (Phonetics)' : 'Pronunciation',
                    isActive: settings.showTransliteration,
                    onTap: () async {
                      final allowed = await settingsNotifier.toggleTransliteration();
                      if (!allowed && context.mounted) {
                        _showMinGuardToast(context, isBn);
                      }
                    },
                  ),
                  const SizedBox(width: 3),

                  _ElementButton(
                    icon: Icons.translate_rounded,
                    tooltip: isBn ? 'অনুবাদ (Translation)' : 'Translation',
                    isActive: settings.showTranslation,
                    onTap: () async {
                      final allowed = await settingsNotifier.toggleTranslation();
                      if (!allowed && context.mounted) {
                        _showMinGuardToast(context, isBn);
                      }
                    },
                  ),

                  // ── Left Symmetrical Spacer ──
                  const Spacer(),

                  // ── Left Divider ──
                  _buildDivider(),

                  const SizedBox(width: 8),

                  // ── Center Group: Audio Track Mode Switcher (Dead Center) ──
                  _buildAudioTrackButton(ref, settings, isBn),

                  const SizedBox(width: 8),

                  // ── Right Divider ──
                  _buildDivider(),

                  // ── Right Symmetrical Spacer ──
                  const Spacer(),

                  // ── Right Group: 3 Preference & Setting Buttons (102px total) ──
                  _buildFontSizeButton(context, settingsNotifier, settings, isBn),
                  const SizedBox(width: 3),
                  _buildLanguageButton(ref, isBn),
                  const SizedBox(width: 3),
                  _buildSettingsButton(context, isBn),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 16,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }

  Widget _buildAudioTrackButton(WidgetRef ref, ReadingSettingsState settings, bool isBn) {
    return Tooltip(
      message: settings.audioTrackMode == AudioTrackMode.recitation
          ? (isBn ? 'অনুবাদে পরিবর্তন করতে চাপুন' : 'Switch to Translation')
          : (isBn ? 'আরবিতে পরিবর্তন করতে চাপুন' : 'Switch to Arabic'),
      child: GestureDetector(
        onTap: () {
          final next = settings.audioTrackMode == AudioTrackMode.recitation
              ? AudioTrackMode.translation
              : AudioTrackMode.recitation;
          ref.read(recitationAudioProvider.notifier).switchTrackMode(next);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: settings.audioTrackMode == AudioTrackMode.translation
                ? NekiColors.goldLight.withValues(alpha: 0.18)
                : NekiColors.emeraldPrimary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: settings.audioTrackMode == AudioTrackMode.translation
                  ? NekiColors.goldLight.withValues(alpha: 0.45)
                  : NekiColors.emeraldLight.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                settings.audioTrackMode == AudioTrackMode.recitation
                    ? Icons.volume_up_rounded
                    : Icons.record_voice_over_rounded,
                size: 13,
                color: settings.audioTrackMode == AudioTrackMode.translation
                    ? NekiColors.goldLight
                    : NekiColors.emeraldLight,
              ),
              const SizedBox(width: 4),
              Text(
                settings.audioTrackMode == AudioTrackMode.recitation
                    ? (isBn ? 'আরবি' : 'Arabic')
                    : (isBn ? 'অনুবাদ' : 'Translation'),
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.bold,
                  color: settings.audioTrackMode == AudioTrackMode.translation
                      ? NekiColors.goldLight
                      : NekiColors.emeraldLight,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeButton(
    BuildContext context,
    ReadingSettingsNotifier settingsNotifier,
    ReadingSettingsState settings,
    bool isBn,
  ) {
    final currentPreset = settings.currentFontSizePreset;
    final presetName = _getPresetName(currentPreset, isBn);

    return Tooltip(
      message: isBn
          ? 'হরফের আকার: $presetName (পরিবর্তন করতে চাপুন)'
          : 'Font Size: $presetName (Tap to switch)',
      child: GestureDetector(
        onTap: () async {
          final next = await settingsNotifier.cycleFontSizePreset();
          if (context.mounted) {
            _showFontSizeToast(context, next, isBn);
          }
        },
        onLongPress: () {
          _showFontSizePresetsSheet(context, settingsNotifier, settings, isBn);
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: NekiColors.goldLight.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Text(
            'A',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
              color: NekiColors.goldLight,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  void _showFontSizeToast(BuildContext context, FontSizePreset preset, bool isBn) {
    final name = _getPresetName(preset, isBn);
    final subtitle = switch (preset) {
      FontSizePreset.small => isBn ? 'আরবি ২২pt • অনুবাদ ১২.৫pt' : 'Arabic 22pt • Translation 12.5pt',
      FontSizePreset.medium => isBn ? 'আরবি ২৬pt • অনুবাদ ১৪pt' : 'Arabic 26pt • Translation 14pt',
      FontSizePreset.large => isBn ? 'আরবি ৩২pt • অনুবাদ ১৬.৫pt' : 'Arabic 32pt • Translation 16.5pt',
      FontSizePreset.extraLarge => isBn ? 'আরবি ৩৮pt • অনুবাদ ১৯.৫pt' : 'Arabic 38pt • Translation 19.5pt',
    };

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: NekiColors.goldLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.format_size_rounded, color: NekiColors.goldLight, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn ? 'হরফের আকার: $name' : 'Font Size: $name',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10281D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: NekiColors.emeraldLight.withValues(alpha: 0.25),
          ),
        ),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  void _showFontSizePresetsSheet(
    BuildContext context,
    ReadingSettingsNotifier settingsNotifier,
    ReadingSettingsState settings,
    bool isBn,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F241A),
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isBn ? 'হরফের আকার নির্বাচন' : 'Select Font Size Preset',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...FontSizePreset.values.map((preset) {
                  final isSelected = preset == settings.currentFontSizePreset;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FontSizePresetItem(
                      preset: preset,
                      isSelected: isSelected,
                      isBn: isBn,
                      onTap: () {
                        settingsNotifier.applyFontSizePreset(preset);
                        Navigator.pop(ctx);
                        _showFontSizeToast(context, preset, isBn);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _getPresetName(FontSizePreset preset, bool isBn) {
    return switch (preset) {
      FontSizePreset.small => isBn ? 'ছোট' : 'Small',
      FontSizePreset.medium => isBn ? 'সাধারণ' : 'Medium',
      FontSizePreset.large => isBn ? 'বড়' : 'Large',
      FontSizePreset.extraLarge => isBn ? 'অনেক বড়' : 'Extra Large',
    };
  }

  Widget _buildLanguageButton(WidgetRef ref, bool isBn) {
    return Tooltip(
      message: isBn ? 'Switch to English' : 'বাংলায় পরিবর্তন করুন',
      child: GestureDetector(
        onTap: () => ref.read(localeProvider.notifier).toggle(),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Text(
            isBn ? 'বাং' : 'EN',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton(BuildContext context, bool isBn) {
    return Tooltip(
      message: isBn ? 'ডিসপ্লে ও টাইপোগ্রাফি সেটিংস' : 'Display & Typography Settings',
      child: GestureDetector(
        onTap: () => RecitationSettingsSheet.show(context),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(
            Icons.tune_rounded,
            size: 15,
            color: NekiColors.emeraldLight,
          ),
        ),
      ),
    );
  }

  void _showMinGuardToast(BuildContext context, bool isBn) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: NekiColors.goldLight, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isBn
                    ? 'কমপক্ষে একটি উপাদান (আরবি, উচ্চারণ বা অনুবাদ) দৃশ্যমান থাকতে হবে'
                    : 'At least one reading element must remain visible',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF132B1F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ElementButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String tooltip;
  final bool isActive;
  final bool isArabic;
  final VoidCallback onTap;

  const _ElementButton({
    this.label,
    this.icon,
    required this.tooltip,
    required this.isActive,
    this.isArabic = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? NekiColors.emeraldPrimary
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? NekiColors.emeraldLight.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: icon != null
              ? Icon(
                  icon,
                  size: 15,
                  color: isActive ? Colors.white : Colors.white60,
                )
              : isArabic
                  ? Transform.translate(
                      offset: const Offset(0, -2.0),
                      child: Text(
                        label!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.amiri(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                          color: isActive ? Colors.white : Colors.white60,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    )
                  : Text(
                      label!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                        letterSpacing: 0.1,
                        color: isActive ? Colors.white : Colors.white60,
                        decoration: TextDecoration.none,
                      ),
                    ),
        ),
      ),
    );
  }
}

class _FontSizePresetItem extends StatelessWidget {
  final FontSizePreset preset;
  final bool isSelected;
  final bool isBn;
  final VoidCallback onTap;

  const _FontSizePresetItem({
    required this.preset,
    required this.isSelected,
    required this.isBn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (preset) {
      FontSizePreset.small => isBn ? 'ছোট (Small)' : 'Small',
      FontSizePreset.medium => isBn ? 'সাধারণ (Medium)' : 'Medium',
      FontSizePreset.large => isBn ? 'বড় (Large)' : 'Large',
      FontSizePreset.extraLarge => isBn ? 'অনেক বড় (Extra Large)' : 'Extra Large',
    };

    final subtitle = switch (preset) {
      FontSizePreset.small => isBn ? 'আরবি ২২pt • অনুবাদ ১২.৫pt' : 'Arabic 22pt • Translation 12.5pt',
      FontSizePreset.medium => isBn ? 'আরবি ২৬pt • অনুবাদ ১৪pt' : 'Arabic 26pt • Translation 14pt',
      FontSizePreset.large => isBn ? 'আরবি ৩২pt • অনুবাদ ১৬.৫pt' : 'Arabic 32pt • Translation 16.5pt',
      FontSizePreset.extraLarge => isBn ? 'আরবি ৩৮pt • অনুবাদ ১৯.৫pt' : 'Arabic 38pt • Translation 19.5pt',
    };

    return Material(
      color: Colors.transparent,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? NekiColors.emeraldLight.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        tileColor: isSelected
            ? NekiColors.emeraldPrimary.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? NekiColors.goldLight.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'A',
            style: GoogleFonts.outfit(
              fontSize: switch (preset) {
                FontSizePreset.small => 12.0,
                FontSizePreset.medium => 14.5,
                FontSizePreset.large => 17.0,
                FontSizePreset.extraLarge => 20.0,
              },
              fontWeight: FontWeight.bold,
              color: isSelected ? NekiColors.goldLight : Colors.white70,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? NekiColors.goldLight : Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: NekiColors.emeraldLight, size: 20)
            : null,
        onTap: onTap,
      ),
    );
  }
}
