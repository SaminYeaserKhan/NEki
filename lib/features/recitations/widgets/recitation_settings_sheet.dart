import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/neki_colors.dart';
import '../providers/reading_settings_provider.dart';
import '../providers/recitation_audio_provider.dart';
import '../services/neural_tts_service.dart';

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
    final locale = ref.watch(localeProvider);
    final isBn = locale == AppLocale.bangla;

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
      child: Material(
        color: const Color(0xFF0F2218).withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(
            color: NekiColors.emeraldLight.withValues(alpha: 0.25),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SingleChildScrollView(
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
                  Text(
                    isBn ? 'পঠন ও অডিও প্রদর্শন সেটিংস' : 'Reading Display & Audio Settings',
                    style: const TextStyle(
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

              // ── 1. Content Visibility Presets ──
              Text(
                isBn ? 'কার্ড উপাদান প্রদর্শন প্রিসেট' : 'CONTENT VISIBILITY PRESETS',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.7,
                  color: Colors.white60,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(isBn ? 'সবগুলো (All Three)' : 'All Three'),
                    selected: settings.isAllThree,
                    selectedColor: NekiColors.emeraldPrimary,
                    onSelected: (_) => notifier.setDisplayPreset(
                      arabic: true,
                      transliteration: true,
                      translation: true,
                    ),
                  ),
                  ChoiceChip(
                    label: Text(isBn ? 'শুধু অনুবাদ' : 'Translation Only'),
                    selected: settings.isTranslationOnly,
                    selectedColor: NekiColors.emeraldPrimary,
                    onSelected: (_) => notifier.setDisplayPreset(
                      arabic: false,
                      transliteration: false,
                      translation: true,
                    ),
                  ),
                  ChoiceChip(
                    label: Text(isBn ? 'শুধু উচ্চারণ' : 'Pronunciation Only'),
                    selected: settings.isPronunciationOnly,
                    selectedColor: NekiColors.emeraldPrimary,
                    onSelected: (_) => notifier.setDisplayPreset(
                      arabic: false,
                      transliteration: true,
                      translation: false,
                    ),
                  ),
                  ChoiceChip(
                    label: Text(isBn ? 'অনুবাদ ও উচ্চারণ' : 'Trans + Pronun'),
                    selected: !settings.showArabic && settings.showTransliteration && settings.showTranslation,
                    selectedColor: NekiColors.emeraldPrimary,
                    onSelected: (_) => notifier.setDisplayPreset(
                      arabic: false,
                      transliteration: true,
                      translation: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Reading Orientation ──
              Text(
                isBn ? 'পঠন শৈলী' : 'READING ORIENTATION',
                style: const TextStyle(
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
                      title: isBn ? 'মুসহাফ মোড' : 'Mushaf Mode',
                      subtitle: isBn ? 'মুদ্রিত কুরআনের মতো আয়াত প্রবাহ' : 'Continuous scripture flow',
                      icon: Icons.auto_stories_rounded,
                      isSelected: settings.readingMode == ReadingMode.mushaf,
                      onTap: () => notifier.setReadingMode(ReadingMode.mushaf),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeOptionCard(
                      title: isBn ? 'আয়াত ভিত্তিক স্টাডি' : 'Verse Study',
                      subtitle: isBn ? 'উচ্চারণ ও অনুবাদ সহ পাঠ' : 'Line-by-line card study',
                      icon: Icons.view_headline_rounded,
                      isSelected: settings.readingMode == ReadingMode.study,
                      onTap: () => notifier.setReadingMode(ReadingMode.study),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── 2. Live Sample Preview ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NekiColors.goldLight.withValues(alpha: 0.15)),
                ),
                child: Column(
                  children: [
                    if (settings.showArabic)
                      Text(
                        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝١',
                        style: previewStyle,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                    if (settings.showTransliteration) ...[
                      if (settings.showArabic) const SizedBox(height: 6),
                      Text(
                        isBn
                            ? 'বিসমিল্লাহির রাহমানির রাহিম'
                            : 'Bismillahir Rahmanir Raheem',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontStyle: isBn ? FontStyle.normal : FontStyle.italic,
                          color: NekiColors.goldLight.withValues(alpha: 0.9),
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (settings.showTranslation) ...[
                      const SizedBox(height: 6),
                      Text(
                        isBn
                            ? 'পরম করুণাময় ও অসীম দয়ালু আল্লাহর নামে শুরু করছি।'
                            : 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
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

              const SizedBox(height: 16),

              // ── 3. Individual Element Switches ──
              _SettingsSwitchTile(
                title: isBn ? 'আরবি মূলপাঠ প্রদর্শন' : 'Show Arabic Scripture',
                value: settings.showArabic,
                onChanged: (_) async {
                  final allowed = await notifier.toggleArabic();
                  if (!allowed && context.mounted) {
                    _showToast(context, isBn);
                  }
                },
              ),
              _SettingsSwitchTile(
                title: isBn ? 'উচ্চারণ / ট্রান্সলিটারেশন প্রদর্শন' : 'Show Pronunciation / Transliteration',
                value: settings.showTransliteration,
                onChanged: (_) async {
                  final allowed = await notifier.toggleTransliteration();
                  if (!allowed && context.mounted) {
                    _showToast(context, isBn);
                  }
                },
              ),
              _SettingsSwitchTile(
                title: isBn ? 'অনুবাদ প্রদর্শন' : 'Show Translation',
                value: settings.showTranslation,
                onChanged: (_) async {
                  final allowed = await notifier.toggleTranslation();
                  if (!allowed && context.mounted) {
                    _showToast(context, isBn);
                  }
                },
              ),

              const SizedBox(height: 14),

              // ── 4. Audio Playback Mode ──
              Text(
                isBn ? 'অডিও প্লেব্যাক পছন্দ' : 'AUDIO PLAYBACK TRACK',
                style: const TextStyle(
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
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.volume_up_rounded, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isBn ? 'আরবি' : 'Arabic',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      selected: settings.audioTrackMode == AudioTrackMode.recitation,
                      selectedColor: NekiColors.emeraldPrimary,
                      onSelected: (_) => ref
                          .read(recitationAudioProvider.notifier)
                          .switchTrackMode(AudioTrackMode.recitation),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.record_voice_over_rounded, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isBn ? 'অনুবাদ' : 'Translation',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      selected: settings.audioTrackMode == AudioTrackMode.translation,
                      selectedColor: NekiColors.emeraldPrimary,
                      onSelected: (_) => ref
                          .read(recitationAudioProvider.notifier)
                          .switchTrackMode(AudioTrackMode.translation),
                    ),
                  ),
                ],
              ),

              if (settings.audioTrackMode == AudioTrackMode.translation) ...[
                const SizedBox(height: 12),
                Text(
                  isBn ? 'অনুবাদ কণ্ঠস্বর (AI Neural Voice)' : 'TRANSLATION VOICE (AI NEURAL)',
                  style: const TextStyle(
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
                      child: ChoiceChip(
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.female_rounded, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isBn ? 'নবানিতা (নারী)' : 'Jenny (Female)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        selected: settings.voiceGender == TtsVoiceGender.female,
                        selectedColor: NekiColors.emeraldPrimary,
                        onSelected: (_) => notifier.setVoiceGender(TtsVoiceGender.female),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.male_rounded, size: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isBn ? 'প্রদীপ (পুরুষ)' : 'Guy (Male)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        selected: settings.voiceGender == TtsVoiceGender.male,
                        selectedColor: NekiColors.emeraldPrimary,
                        onSelected: (_) => notifier.setVoiceGender(TtsVoiceGender.male),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // ── 5. App Language ──
              Text(
                isBn ? 'ভাষা নির্বাচন' : 'APPLICATION LANGUAGE',
                style: const TextStyle(
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
                    child: ChoiceChip(
                      label: const Center(child: Text('বাংলা (Bangla)')),
                      selected: locale == AppLocale.bangla,
                      selectedColor: NekiColors.emeraldPrimary,
                      onSelected: (_) =>
                          ref.read(localeProvider.notifier).setLocale(AppLocale.bangla),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('English')),
                      selected: locale == AppLocale.english,
                      selectedColor: NekiColors.emeraldPrimary,
                      onSelected: (_) =>
                          ref.read(localeProvider.notifier).setLocale(AppLocale.english),
                    ),
                  ),
                ],
              ),

              if (settings.showArabic) ...[
                const SizedBox(height: 18),
                // ── Arabic Typography ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isBn ? 'আরবি ফন্ট সাইজ' : 'Arabic Font Size',
                      style: const TextStyle(
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

                Row(
                  children: [
                    Text(
                      isBn ? 'লিপি ধরন' : 'Arabic Script',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Uthmanic', style: TextStyle(fontSize: 12)),
                      selected: settings.arabicScript == ArabicScript.uthmanic,
                      selectedColor: NekiColors.emeraldPrimary,
                      onSelected: (_) => notifier.setArabicScript(ArabicScript.uthmanic),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('IndoPak', style: TextStyle(fontSize: 12)),
                      selected: settings.arabicScript == ArabicScript.indopak,
                      selectedColor: NekiColors.emeraldPrimary,
                      onSelected: (_) => notifier.setArabicScript(ArabicScript.indopak),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

  static void _showToast(BuildContext context, bool isBn) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBn
              ? 'কমপক্ষে একটি উপাদান দৃশ্যমান থাকতে হবে'
              : 'At least one reading element must remain visible',
          style: const TextStyle(fontSize: 12.5),
        ),
        backgroundColor: const Color(0xFF132B1F),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? NekiColors.emeraldLight : Colors.white,
                      decoration: TextDecoration.none,
                    ),
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

class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: Switch.adaptive(
                activeThumbColor: NekiColors.emeraldLight,
                activeTrackColor: NekiColors.emeraldPrimary,
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
