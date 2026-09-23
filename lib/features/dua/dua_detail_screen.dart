import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/bengali_phonetic_helper.dart';
import '../../core/widgets/recitation_background.dart';
import '../recitations/providers/reading_settings_provider.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/audio_visualizer_widget.dart';
import '../recitations/widgets/bottom_panning_nav_bar.dart';
import '../recitations/widgets/global_reading_control_bar.dart';
import '../recitations/widgets/persistent_recitation_player.dart';
import '../recitations/widgets/pronunciation_checker_modal.dart';
import '../recitations/widgets/recitation_settings_sheet.dart';
import 'dua_provider.dart';

/// Serene, high-contrast Dua Reader & Recitation Deck.
/// Features tranquil sacred recitation canvas, customizable Arabic typography,
/// horizontal quick-jump pill carousel, interactive Dhikr/recitation tap counters,
/// and integrated Vocalize Studio & audio recitation dock.
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
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  final Map<int, int> _recitationCounts = {};
  int _activeDuaIndex = 0;

  @override
  void initState() {
    super.initState();
    _activeDuaIndex = widget.initialIndex.clamp(0, widget.duas.isEmpty ? 0 : widget.duas.length - 1);

    for (int i = 0; i < widget.duas.length; i++) {
      _recitationCounts[widget.duas[i].id] = 0;
    }

    _itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);

    if (widget.initialIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDua(widget.initialIndex);
      });
    }
  }

  void _onItemPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final visible = positions
        .where((pos) => pos.itemTrailingEdge > 0.05)
        .toList();
    if (visible.isEmpty) return;
    visible.sort((a, b) => a.index.compareTo(b.index));
    final topIndex = visible.first.index;
    if (topIndex != _activeDuaIndex && mounted) {
      setState(() => _activeDuaIndex = topIndex);
    }
  }

  void _scrollToDua(int index) {
    if (index < 0 || index >= widget.duas.length) return;
    setState(() => _activeDuaIndex = index);

    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
    }
  }

  void _incrementDuaCount(Dua dua) {
    final current = _recitationCounts[dua.id] ?? 0;
    final target = dua.recommendedRepetitions;
    final updated = current + 1;

    setState(() {
      _recitationCounts[dua.id] = updated;
    });

    if (target > 1 && updated == target) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _resetDuaCount(Dua dua) {
    HapticFeedback.selectionClick();
    setState(() {
      _recitationCounts[dua.id] = 0;
    });
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onItemPositionsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = ref.watch(currentHourProvider);
    final audio = ref.watch(recitationAudioProvider);
    final settings = ref.watch(readingSettingsProvider);

    final categoryTitle = widget.duas.isNotEmpty
        ? widget.duas.first.category.toUpperCase()
        : 'DUAS';

    return RecitationBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Top Sacred App Bar ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      categoryTitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: NekiColors.emeraldPrimary
                                          .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: NekiColors.emeraldLight
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      '${widget.duas.length}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: NekiColors.emeraldLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                locale == AppLocale.bangla
                                    ? 'বিশুদ্ধ প্রার্থনা ও যিকির সংগ্রহ'
                                    : 'Authentic Supplications & Adhkar',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Reading & Typography Settings Button
                        IconButton(
                          tooltip: 'Typography & Display Settings',
                          icon: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: NekiColors.emeraldLight,
                              size: 18,
                            ),
                          ),
                          onPressed: () => RecitationSettingsSheet.show(context),
                        ),
                      ],
                    ),
                  ),

                  // ── Global Reading Control Bar (Elements, Audio Track, Language) ──
                  const GlobalReadingControlBar(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                  ),

                  // ── 2. Vertical Dua Cards Deck ──
                  Expanded(
                    child: ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      initialScrollIndex: widget.initialIndex > 0 ? widget.initialIndex : 0,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 170),
                      itemCount: widget.duas.length,
                      itemBuilder: (context, index) {
                        final dua = widget.duas[index];
                        final isPlaying = audio.isPlaying &&
                            audio.type == RecitationType.dua &&
                            audio.currentVerse == dua.id;
                        final currentCount = _recitationCounts[dua.id] ?? 0;

                        return _DuaCard(
                          dua: dua,
                          index: index + 1,
                          hour: hour,
                          locale: locale,
                          s: s,
                          settings: settings,
                          isPlaying: isPlaying,
                          currentCount: currentCount,
                          onIncrementCount: () => _incrementDuaCount(dua),
                          onResetCount: () => _resetDuaCount(dua),
                          onPlayTap: () {
                            if (isPlaying) {
                              ref
                                  .read(recitationAudioProvider.notifier)
                                  .togglePlayPause();
                            } else {
                              ref
                                  .read(recitationAudioProvider.notifier)
                                  .playDua(dua);
                            }
                          },
                          onVocalizeTap: () {
                            final isBangla = locale == AppLocale.bangla;
                            final trans = isBangla && dua.bengali != null
                                ? dua.bengali!
                                : dua.description;
                            final pronunciation = isBangla
                                ? (dua.transliterationBn ??
                                    BengaliPhoneticHelper
                                        .toBengaliPronunciation(
                                            dua.transliteration))
                                : dua.transliteration;

                            PronunciationCheckerModal.show(
                              context,
                              title: dua.title,
                              arabicText: dua.arabic,
                              transliteration: pronunciation,
                              translation: trans,
                              dua: dua,
                              surahNumber: dua.surahNumber,
                              verseNumber: dua.verseNumber,
                              onNext: index < widget.duas.length - 1
                                  ? () => _scrollToDua(index + 1)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── 3. Bottom Scroll Panning Bar for Dua Navigation ──
            if (widget.duas.length > 1)
              BottomPanningNavBar(
                itemCount: widget.duas.length,
                currentIndex: _activeDuaIndex,
                labelBuilder: (index) => '#${index + 1}',
                prevTooltip: locale == AppLocale.bangla ? 'পূর্ববর্তী দো‘আ' : 'Previous Dua',
                nextTooltip: locale == AppLocale.bangla ? 'পরবর্তী দো‘আ' : 'Next Dua',
                onItemSelected: _scrollToDua,
              ),

            // ── 4. Single Docked Floating Audio Player ──
            const PersistentRecitationPlayer(bottomPadding: 16),
          ],
        ),
      ),
    );
  }
}

class _DuaCard extends ConsumerStatefulWidget {
  final Dua dua;
  final int index;
  final int hour;
  final AppLocale locale;
  final S s;
  final ReadingSettingsState settings;
  final bool isPlaying;
  final int currentCount;
  final VoidCallback onIncrementCount;
  final VoidCallback onResetCount;
  final VoidCallback onPlayTap;
  final VoidCallback onVocalizeTap;

  const _DuaCard({
    required this.dua,
    required this.index,
    required this.hour,
    required this.locale,
    required this.s,
    required this.settings,
    required this.isPlaying,
    required this.currentCount,
    required this.onIncrementCount,
    required this.onResetCount,
    required this.onPlayTap,
    required this.onVocalizeTap,
  });

  @override
  ConsumerState<_DuaCard> createState() => _DuaCardState();
}

class _DuaCardState extends ConsumerState<_DuaCard> {
  @override
  Widget build(BuildContext context) {
    final dua = widget.dua;
    final index = widget.index;
    final locale = widget.locale;
    final settings = ref.watch(readingSettingsProvider);
    final isPlaying = widget.isPlaying;
    final currentCount = widget.currentCount;
    final onIncrementCount = widget.onIncrementCount;
    final onResetCount = widget.onResetCount;
    final onPlayTap = widget.onPlayTap;
    final onVocalizeTap = widget.onVocalizeTap;

    final bookmarks = ref.watch(duaBookmarkProvider);
    final isBookmarked = bookmarks.contains(dua.id);

    final translationText = locale == AppLocale.bangla && dua.bengali != null
        ? dua.bengali!
        : dua.description;

    final targetCount = dua.recommendedRepetitions;

    // Dynamic Arabic Typography based on user settings
    final arabicStyle = settings.arabicScript == ArabicScript.uthmanic
        ? GoogleFonts.amiriQuran(
            fontSize: settings.arabicFontSize,
            height: 2.1,
            color: isPlaying ? const Color(0xFFFFFBEA) : const Color(0xFFFFFDF5),
          )
        : GoogleFonts.scheherazadeNew(
            fontSize: settings.arabicFontSize,
            height: 2.1,
            color: isPlaying ? const Color(0xFFFFFBEA) : const Color(0xFFFFFDF5),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isPlaying
            ? const Color(0xFF133224).withValues(alpha: 0.95)
            : const Color(0xFF0F241A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPlaying
              ? NekiColors.emeraldLight
              : const Color(0xFF1E3D2D),
          width: isPlaying ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPlaying
                ? NekiColors.emeraldPrimary.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: isPlaying ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card Header Row ──
          Row(
            children: [
              // Index Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? NekiColors.emeraldPrimary
                      : NekiColors.emeraldPrimary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: NekiColors.emeraldLight.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '#$index',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                  ),
                ),
              ),

              if (dua.isQuranic) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: NekiColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: NekiColors.goldLight.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_stories_rounded,
                          size: 11, color: NekiColors.goldLight),
                      const SizedBox(width: 4),
                      Text(
                        'Quran ${dua.surahNumber}:${dua.verseNumber}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.goldLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              if (isPlaying) ...[
                const AudioVisualizerWidget(
                  isPlaying: true,
                  barCount: 3,
                  height: 14,
                  barWidth: 2.2,
                  color: NekiColors.emeraldLight,
                ),
                const SizedBox(width: 10),
              ],

              // Copy Button
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: 'Copy Dua',
                icon: const Icon(Icons.copy_rounded,
                    size: 17, color: Colors.white54),
                onPressed: () {
                  final textToCopy = '${dua.title}\n\n'
                      '${dua.arabic}\n\n'
                      '${dua.transliteration.isNotEmpty ? "${dua.transliteration}\n\n" : ""}'
                      '$translationText'
                      '${dua.reference != null ? "\n(${dua.reference})" : ""}';
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: NekiColors.emeraldLight, size: 18),
                          const SizedBox(width: 8),
                          Text(locale == AppLocale.bangla
                              ? 'দো‘আ কপি করা হয়েছে'
                              : 'Copied Dua to clipboard'),
                        ],
                      ),
                      backgroundColor: const Color(0xFF132B1F),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: NekiColors.emeraldLight),
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),

              const SizedBox(width: 6),

              // Bookmark Button
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark Dua',
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 21,
                  color: isBookmarked ? NekiColors.goldLight : Colors.white54,
                ),
                onPressed: () {
                  ref.read(duaBookmarkProvider.notifier).toggle(dua.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isBookmarked
                            ? (locale == AppLocale.bangla
                                ? 'বুকমার্ক সরানো হয়েছে'
                                : 'Bookmark removed')
                            : (locale == AppLocale.bangla
                                ? 'বুকমার্ক সংরক্ষণ করা হয়েছে'
                                : 'Saved to Bookmarks'),
                      ),
                      backgroundColor: const Color(0xFF132B1F),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Title
          Text(
            dua.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 14),

          // ── Arabic Scripture (Full, Uncut Sentence) ──
          if (settings.showArabic) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Text(
                dua.arabic,
                style: arabicStyle,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],

          // ── Transliteration / Pronunciation ──
          if (settings.showTransliteration &&
              dua.transliteration.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NekiColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: NekiColors.goldLight.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                locale == AppLocale.bangla
                    ? (dua.transliterationBn ??
                        BengaliPhoneticHelper.toBengaliPronunciation(
                            dua.transliteration))
                    : dua.transliteration,
                style: TextStyle(
                  fontSize: (settings.translationFontSize - 1.0).clamp(11.0, 18.0),
                  fontStyle: locale == AppLocale.bangla
                      ? FontStyle.normal
                      : FontStyle.italic,
                  color: NekiColors.goldLight,
                  height: 1.45,
                ),
              ),
            ),
          ],

          // ── Translation ──
          if (settings.showTranslation) ...[
            const SizedBox(height: 12),
            Text(
              translationText,
              style: TextStyle(
                fontSize: settings.translationFontSize,
                height: 1.55,
                color: const Color(0xFFEFF5F1),
                letterSpacing: 0.15,
              ),
            ),
          ],

          // ── Reference ──
          if (dua.reference != null && dua.reference!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    dua.reference!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ── Interactive Recitation Counter Pill ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: currentCount >= targetCount && targetCount > 1
                  ? NekiColors.emeraldPrimary.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: currentCount >= targetCount && targetCount > 1
                    ? NekiColors.emeraldLight
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  currentCount >= targetCount && targetCount > 1
                      ? Icons.check_circle_rounded
                      : Icons.fingerprint_rounded,
                  size: 18,
                  color: currentCount >= targetCount && targetCount > 1
                      ? NekiColors.emeraldLight
                      : NekiColors.goldLight,
                ),
                const SizedBox(width: 8),
                Text(
                  targetCount > 1
                      ? 'Target: $targetCount • Recited: $currentCount'
                      : 'Recitation Count: $currentCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: currentCount >= targetCount && targetCount > 1
                        ? NekiColors.emeraldLight
                        : Colors.white70,
                  ),
                ),
                const Spacer(),

                // Reset button
                if (currentCount > 0)
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Reset Count',
                    icon: const Icon(Icons.refresh_rounded,
                        size: 16, color: Colors.white38),
                    onPressed: onResetCount,
                  ),

                const SizedBox(width: 6),

                // Tap to Count Button
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onIncrementCount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: NekiColors.emeraldPrimary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color:
                              NekiColors.emeraldPrimary.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'Count',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Action Buttons: Recite & Audio ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onVocalizeTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.goldLight,
                    side: BorderSide(
                      color: NekiColors.goldLight.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: const Icon(Icons.mic_rounded, size: 15),
                  label: Text(
                    locale == AppLocale.bangla ? 'উচ্চারণ যাচাই' : 'Recite & Check',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPlayTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NekiColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.volume_up_rounded,
                    size: 15,
                  ),
                  label: Text(
                    isPlaying
                        ? (locale == AppLocale.bangla ? 'বিরতি' : 'Pause')
                        : (settings.audioTrackMode == AudioTrackMode.translation
                            ? (locale == AppLocale.bangla ? 'অনুবাদ' : 'Translation')
                            : (dua.isQuranic ? 'আলাফাসী' : (locale == AppLocale.bangla ? 'তিলাওয়াত' : 'Recitation'))),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
