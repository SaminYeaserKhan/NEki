import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/recitation_background.dart';
import '../recitations/providers/reading_settings_provider.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/audio_visualizer_widget.dart';
import '../recitations/widgets/bottom_panning_nav_bar.dart';
import '../recitations/widgets/global_reading_control_bar.dart';
import '../recitations/widgets/persistent_recitation_player.dart';
import '../recitations/widgets/pronunciation_checker_modal.dart';
import 'dua_detail_screen.dart';
import 'dua_provider.dart';

/// Shows all duas within a specific category with tranquil reading canvas.
/// Designed for serene readability with full sentences (zero truncation).
class DuaListScreen extends ConsumerStatefulWidget {
  final String categoryId;

  const DuaListScreen({super.key, required this.categoryId});

  @override
  ConsumerState<DuaListScreen> createState() => _DuaListScreenState();
}

class _DuaListScreenState extends ConsumerState<DuaListScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _activeDuaIndex = 0;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onItemPositionsChanged);
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final duasAsync = ref.watch(duasByCategoryProvider(widget.categoryId));
    final locale = ref.watch(localeProvider);
    final isBn = locale == AppLocale.bangla;
    final hour = ref.watch(currentHourProvider);

    // Get category display name
    final categoriesAsync = ref.watch(duaCategoriesProvider);
    final categoryName = categoriesAsync.whenOrNull(
          data: (cats) {
            final cat = cats.where((c) => c.id == widget.categoryId).firstOrNull;
            return isBn
                ? cat?.nameBn ?? widget.categoryId
                : cat?.nameEn ?? widget.categoryId;
          },
        ) ??
        widget.categoryId;

    return RecitationBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Clean Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                categoryName,
                                style: GoogleFonts.inter(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              duasAsync.maybeWhen(
                                data: (duas) => Text(
                                  isBn
                                      ? '${duas.length}টি দো‘আ • সম্পূর্ণ পাঠ ও অর্থ'
                                      : '${duas.length} Duas • Full Scripture & Meaning',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                                orElse: () => Text(
                                  isBn
                                      ? 'দো‘আর তালিকা'
                                      : 'Dua Directory',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Global Reading Control Bar (Elements, Language, Audio Track) ──
                  const GlobalReadingControlBar(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                  ),

                  // ── Dua List ──
                  Expanded(
                    child: duasAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: NekiColors.emeraldLight,
                        ),
                      ),
                      error: (_, _) => const Center(
                        child: Text(
                          'Failed to load duas.',
                          style: TextStyle(
                            color: Colors.white70,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      data: (duas) => ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 170),
                        itemCount: duas.length,
                        itemBuilder: (context, index) {
                          final dua = duas[index];
                          return _DuaCategoryCard(
                            dua: dua,
                            index: index,
                            hour: hour,
                            locale: locale,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DuaDetailScreen(
                                  duas: duas,
                                  initialIndex: index,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom Scroll Panning Bar for Category Duas ──
            duasAsync.maybeWhen(
              data: (duas) {
                if (duas.length <= 1) return const SizedBox.shrink();
                return BottomPanningNavBar(
                  itemCount: duas.length,
                  currentIndex: _activeDuaIndex.clamp(0, duas.length - 1),
                  labelBuilder: (index) => '#${index + 1}',
                  prevTooltip: isBn ? 'পূর্ববর্তী দো‘আ' : 'Previous Dua',
                  nextTooltip: isBn ? 'পরবর্তী দো‘আ' : 'Next Dua',
                  onItemSelected: _scrollToDua,
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // ── Persistent Floating Audio Player ──
            const PersistentRecitationPlayer(bottomPadding: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Serene, Full-Sentence Dua Category Card
// ─────────────────────────────────────────────────────

class _DuaCategoryCard extends ConsumerWidget {
  final Dua dua;
  final int index;
  final int hour;
  final AppLocale locale;
  final VoidCallback onTap;

  const _DuaCategoryCard({
    required this.dua,
    required this.index,
    required this.hour,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readingSettingsProvider);
    final audioState = ref.watch(recitationAudioProvider);
    final isPlaying = audioState.isPlaying &&
        audioState.type == RecitationType.dua &&
        audioState.currentVerse == dua.id;
    final isBangla = locale == AppLocale.bangla;
    final bookmarks = ref.watch(duaBookmarkProvider);
    final isBookmarked = bookmarks.contains(dua.id);

    // Full translation text (No truncation)
    final translationText = isBangla && dua.bengali != null && dua.bengali!.trim().isNotEmpty
        ? dua.bengali!
        : dua.description;

    // Transliteration (Pronunciation guide)
    final transliterationText = isBangla && dua.transliterationBn != null && dua.transliterationBn!.trim().isNotEmpty
        ? dua.transliterationBn!
        : dua.transliteration;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isPlaying
            ? const Color(0xFF133224).withValues(alpha: 0.95)
            : const Color(0xFF0F241A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPlaying ? NekiColors.emeraldLight : const Color(0xFF1E3D2D),
          width: isPlaying ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isPlaying
                ? NekiColors.emeraldPrimary.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: isPlaying ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Header Row ──
              Row(
                children: [
                  // Index Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? NekiColors.emeraldPrimary
                          : NekiColors.emeraldPrimary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: NekiColors.emeraldLight.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: NekiColors.emeraldLight,
                      ),
                    ),
                  ),

                  // Quranic Badge
                  if (dua.isQuranic) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: NekiColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: NekiColors.goldLight.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        isBangla ? 'কুরআনিক দো‘আ' : 'Quranic',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: NekiColors.goldLight,
                        ),
                      ),
                    ),
                  ],

                  // Repetitions Badge (if > 1)
                  if (dua.recommendedRepetitions > 1) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        isBangla
                            ? '${dua.recommendedRepetitions} বার পাঠ'
                            : '${dua.recommendedRepetitions}x Recitation',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Playing Visualizer
                  if (isPlaying) ...[
                    const AudioVisualizerWidget(
                      isPlaying: true,
                      barCount: 3,
                      height: 13,
                      barWidth: 2,
                      color: NekiColors.emeraldLight,
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Copy Action
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    tooltip: isBangla ? 'কপি করুন' : 'Copy',
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white54),
                    onPressed: () {
                      final textToCopy = '${dua.title}\n\n'
                          '${dua.arabic}\n\n'
                          '$translationText\n'
                          '${dua.reference != null ? "(${dua.reference})" : ""}';
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: NekiColors.emeraldLight, size: 16),
                              const SizedBox(width: 8),
                              Text(isBangla ? 'দো‘আ কপি করা হয়েছে' : 'Dua copied to clipboard'),
                            ],
                          ),
                          backgroundColor: const Color(0xFF132B1F),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),

                  // Bookmark Action
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark',
                    icon: Icon(
                      isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 19,
                      color: isBookmarked ? NekiColors.goldLight : Colors.white54,
                    ),
                    onPressed: () {
                      ref.read(duaBookmarkProvider.notifier).toggle(dua.id);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Full Title (No Truncation) ──
              Text(
                dua.title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.35,
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 14),

              // ── Full Arabic Scripture (No Truncation, Generous Typography) ──
              if (settings.showArabic) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    dua.arabic,
                    style: settings.arabicScript == ArabicScript.uthmanic
                        ? GoogleFonts.amiriQuran(
                            fontSize: settings.arabicFontSize,
                            height: 2.0,
                            color: isPlaying ? const Color(0xFFFFFBEA) : const Color(0xFFFFFDF5),
                          )
                        : GoogleFonts.scheherazadeNew(
                            fontSize: settings.arabicFontSize,
                            height: 2.0,
                            color: isPlaying ? const Color(0xFFFFFBEA) : const Color(0xFFFFFDF5),
                          ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],

              // ── Full Translation Sentence (Prominent & Clear) ──
              if (settings.showTranslation) ...[
                if (settings.showArabic) const SizedBox(height: 12),
                Text(
                  translationText,
                  style: TextStyle(
                    fontSize: settings.translationFontSize,
                    height: 1.6,
                    color: NekiColors.adaptiveTextPrimary(hour).withValues(alpha: 0.95),
                  ),
                ),
              ],

              // ── Transliteration / Pronunciation ──
              if (settings.showTransliteration && transliterationText.isNotEmpty) ...[
                if (settings.showArabic || settings.showTranslation) const SizedBox(height: 8),
                Text(
                  transliterationText,
                  style: TextStyle(
                    fontSize: (settings.translationFontSize - 1.5).clamp(11.0, 18.0),
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                    color: NekiColors.goldLight.withValues(alpha: 0.85),
                  ),
                ),
              ],

              // ── Reference / Source Citation ──
              if (dua.reference != null && dua.reference!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 12, color: Colors.white38),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        dua.reference!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // ── Clean Action Strip ──
              Row(
                children: [
                  // Pronunciation Checker ("Recite & Check")
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        PronunciationCheckerModal.show(
                          context,
                          title: dua.title,
                          arabicText: dua.arabic,
                          transliteration: dua.transliteration,
                          translation: translationText,
                          dua: dua,
                          surahNumber: dua.surahNumber,
                          verseNumber: dua.verseNumber,
                        );
                      },
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
                        isBangla ? 'উচ্চারণ যাচাই' : 'Recite & Check',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Listen / Audio Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (isPlaying) {
                          ref.read(recitationAudioProvider.notifier).togglePlayPause();
                        } else {
                          ref.read(recitationAudioProvider.notifier).playDua(dua);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NekiColors.emeraldPrimary,
                        foregroundColor: Colors.white,
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
                            ? (isBangla ? 'বিরতি' : 'Pause')
                            : (settings.audioTrackMode == AudioTrackMode.translation
                                ? (isBangla ? 'অনুবাদ' : 'Translation')
                                : (isBangla ? 'তিলাওয়াত' : 'Listen')),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
