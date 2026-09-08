import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/bengali_phonetic_helper.dart';
import '../../core/widgets/animated_gradient_bg.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/audio_visualizer_widget.dart';
import '../recitations/widgets/persistent_recitation_player.dart';
import '../recitations/widgets/pronunciation_checker_modal.dart';
import 'dua_provider.dart';

/// Redesigned Dua Reader with consistent vertical reading orientation.
/// Eliminates conflicting horizontal swipe gestures in favor of a smooth,
/// elegant devotional card deck with quick category navigation.
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
  late ScrollController _scrollController;
  final Map<int, GlobalKey> _duaKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    for (int i = 0; i < widget.duas.length; i++) {
      _duaKeys[i] = GlobalKey();
    }

    if (widget.initialIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDua(widget.initialIndex);
      });
    }
  }

  void _scrollToDua(int index) {
    final key = _duaKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = ref.watch(currentHourProvider);
    final audio = ref.watch(recitationAudioProvider);

    final categoryTitle = widget.duas.isNotEmpty
        ? widget.duas.first.category.toUpperCase()
        : 'DUAS';

    return AnimatedGradientBackground(
      showMosque: false,
      showStars: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_rounded,
                            color: NekiColors.adaptiveTextPrimary(hour),
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: NekiColors.adaptiveTextPrimary(hour),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              Text(
                                '${widget.duas.length} Supplications',
                                style: TextStyle(
                                  fontSize: 11,
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

                  // ── Sticky Horizontal Quick-Jump Pill Bar ──
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.duas.length,
                      itemBuilder: (context, index) {
                        final dua = widget.duas[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            backgroundColor: NekiColors.adaptiveCardColor(hour),
                            side: BorderSide(color: NekiColors.adaptiveCardBorder(hour)),
                            label: Text(
                              '${index + 1}. ${dua.title}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: NekiColors.adaptiveTextPrimary(hour),
                              ),
                            ),
                            onPressed: () => _scrollToDua(index),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ── Vertical Dua Cards Deck ──
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 140),
                      itemCount: widget.duas.length,
                      itemBuilder: (context, index) {
                        final dua = widget.duas[index];
                        final isPlaying = audio.isPlaying &&
                            audio.type == RecitationType.dua &&
                            audio.currentVerse == dua.id;

                        return _DuaCard(
                          key: _duaKeys[index],
                          dua: dua,
                          index: index + 1,
                          hour: hour,
                          locale: locale,
                          s: s,
                          isPlaying: isPlaying,
                          onPlayTap: () {
                            if (isPlaying) {
                              ref.read(recitationAudioProvider.notifier).togglePlayPause();
                            } else {
                              ref.read(recitationAudioProvider.notifier).playDua(dua);
                            }
                          },
                          onVocalizeTap: () {
                            final isBangla = locale == AppLocale.bangla;
                            final trans = isBangla && dua.bengali != null
                                ? dua.bengali!
                                : dua.description;
                            final pronunciation = isBangla
                                ? (dua.transliterationBn ?? BengaliPhoneticHelper.toBengaliPronunciation(dua.transliteration))
                                : dua.transliteration;

                            PronunciationCheckerModal.show(
                              context,
                              title: dua.title,
                              arabicText: dua.arabic,
                              transliteration: pronunciation,
                              translation: trans,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Single Docked Floating Audio Player ──
            const PersistentRecitationPlayer(bottomPadding: 24),
          ],
        ),
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  final Dua dua;
  final int index;
  final int hour;
  final AppLocale locale;
  final S s;
  final bool isPlaying;
  final VoidCallback onPlayTap;
  final VoidCallback onVocalizeTap;

  const _DuaCard({
    super.key,
    required this.dua,
    required this.index,
    required this.hour,
    required this.locale,
    required this.s,
    required this.isPlaying,
    required this.onPlayTap,
    required this.onVocalizeTap,
  });

  @override
  Widget build(BuildContext context) {
    final translationText = locale == AppLocale.bangla && dua.bengali != null
        ? dua.bengali!
        : dua.description;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isPlaying
            ? NekiColors.emeraldPrimary.withValues(alpha: 0.2)
            : NekiColors.adaptiveCardColor(hour),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPlaying
              ? NekiColors.emeraldLight
              : NekiColors.adaptiveCardBorder(hour),
          width: isPlaying ? 1.6 : 1.0,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$index',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dua.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.adaptiveTextPrimary(hour),
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPlaying) ...[
                const AudioVisualizerWidget(
                  isPlaying: true,
                  barCount: 3,
                  height: 14,
                  barWidth: 2,
                  color: NekiColors.emeraldLight,
                ),
                const SizedBox(width: 8),
              ],

              // Copy button
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white38),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${dua.arabic}\n\n${dua.title}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied Dua to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Arabic Scripture ──
          Text(
            dua.arabic,
            style: GoogleFonts.amiriQuran(
              fontSize: 24,
              height: 2.0,
              color: isPlaying ? const Color(0xFFFFFBEA) : NekiColors.adaptiveTextPrimary(hour),
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),

          // ── Transliteration / Pronunciation ──
          if (dua.transliteration.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              locale == AppLocale.bangla
                  ? (dua.transliterationBn ?? BengaliPhoneticHelper.toBengaliPronunciation(dua.transliteration))
                  : dua.transliteration,
              style: TextStyle(
                fontSize: 13,
                fontStyle: locale == AppLocale.bangla ? FontStyle.normal : FontStyle.italic,
                color: NekiColors.goldLight.withValues(alpha: 0.9),
                height: 1.45,
                decoration: TextDecoration.none,
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── Translation ──
          Text(
            translationText,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.88),
              decoration: TextDecoration.none,
            ),
          ),

          if (dua.reference != null && dua.reference!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              dua.reference!,
              style: TextStyle(
                fontSize: 11,
                color: NekiColors.adaptiveTextSecondary(hour).withValues(alpha: 0.7),
                decoration: TextDecoration.none,
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Action Buttons: Recite & Pronunciation ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onVocalizeTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.goldLight,
                    side: BorderSide(color: NekiColors.goldLight.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 16),
                  label: const Text('Recite & Check', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPlayTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NekiColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded, size: 16),
                  label: Text(isPlaying ? 'Pause' : 'Pronunciation', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
