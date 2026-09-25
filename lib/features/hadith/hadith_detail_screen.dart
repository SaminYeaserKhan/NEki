import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/bengali_phonetic_helper.dart';
import '../../core/utils/hadith_text_sanitizer.dart';
import '../../core/widgets/neki_snack_bar.dart';
import '../../core/widgets/recitation_background.dart';
import '../recitations/providers/reading_settings_provider.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/audio_visualizer_widget.dart';
import '../recitations/widgets/bottom_panning_nav_bar.dart';
import '../recitations/widgets/global_reading_control_bar.dart';
import '../recitations/widgets/persistent_recitation_player.dart';
import '../recitations/widgets/pronunciation_checker_modal.dart';
import '../recitations/widgets/recitation_settings_sheet.dart';
import 'hadith_provider.dart';

/// Serene, human-centered Hadith Reader & Recitation Deck.
/// Features:
/// - 3 Ergonomic Reading Modes: Translation-First (default), Dual View, and Arabic Scripture
/// - Auto-collapsible Arabic guard for long texts (no more endless scrolling past 5+ screens of Arabic)
/// - Sanitized Bengali/English translations (untranslated raw Arabic bab prefixes removed)
/// - Top Quick-Jump Pill Bar for 0ms chapter navigation
/// - High-contrast sacred canvas, authentic grading badges, and docked audio clearance
class HadithDetailScreen extends ConsumerStatefulWidget {
  final String bookId;
  final HadithSection section;

  const HadithDetailScreen({
    super.key,
    required this.bookId,
    required this.section,
  });

  @override
  ConsumerState<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends ConsumerState<HadithDetailScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  int _activeHadithIndex = 0;

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
    if (topIndex != _activeHadithIndex && mounted) {
      setState(() => _activeHadithIndex = topIndex);
    }
  }

  void _scrollToHadith(int index) {
    setState(() => _activeHadithIndex = index);
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
    final hadithsAsync = ref.watch(
      hadithBySectionProvider((
        bookId: widget.bookId,
        sectionNumber: widget.section.sectionNumber,
      )),
    );
    final hour = ref.watch(currentHourProvider);
    final locale = ref.watch(localeProvider);
    final isBn = locale == AppLocale.bangla;
    final settings = ref.watch(readingSettingsProvider);
    final readingMode = ref.watch(hadithReadingModeProvider);

    final book = hadithBooks.firstWhere(
      (b) => b.id == widget.bookId,
      orElse: () => hadithBooks.first,
    );
    final bookName = isBn ? book.nameBengali : book.nameEnglish;

    return RecitationBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Top App Bar ──
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
                                      bookName,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: NekiColors.emeraldLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ch. ${widget.section.sectionNumber}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.section.name,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
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

                  // ── 2. Global Reading Control Bar (Element Toggles, Presets, Audio Track & Language) ──
                  const GlobalReadingControlBar(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                  ),

                  // ── 3. Hadith List (Reliable ScrollablePositionedList) ──
                  Expanded(
                    child: hadithsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: NekiColors.emeraldLight,
                        ),
                      ),
                      error: (_, _) => Center(
                        child: Text(
                          isBn ? 'হাদিস লোড করতে ব্যর্থ হয়েছে।' : 'Failed to load hadiths.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      data: (hadiths) {
                        return ScrollablePositionedList.builder(
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 170),
                          itemCount: hadiths.length,
                          itemBuilder: (context, index) => _HadithCard(
                            hadith: hadiths[index],
                            bookId: widget.bookId,
                            hour: hour,
                            locale: locale,
                            settings: settings,
                            readingMode: readingMode,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── 4. Bottom Scroll Panning Bar for Hadith Navigation ──
            hadithsAsync.maybeWhen(
              data: (hadiths) => BottomPanningNavBar(
                itemCount: hadiths.length,
                currentIndex: _activeHadithIndex,
                labelBuilder: (index) => '#${hadiths[index].number}',
                prevTooltip: isBn ? 'পূর্ববর্তী হাদিস' : 'Previous Hadith',
                nextTooltip: isBn ? 'পরবর্তী হাদিস' : 'Next Hadith',
                onItemSelected: _scrollToHadith,
              ),
              orElse: () => const SizedBox.shrink(),
            ),

            // ── 5. Single Docked Floating Audio Player ──
            const PersistentRecitationPlayer(bottomPadding: 16),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────
//  Hadith Card with Progressive Disclosure
// ─────────────────────────────────────────────────────

class _HadithCard extends ConsumerStatefulWidget {
  final HadithEntry hadith;
  final String bookId;
  final int hour;
  final AppLocale locale;
  final ReadingSettingsState settings;
  final HadithReadingMode readingMode;

  const _HadithCard({
    required this.hadith,
    required this.bookId,
    required this.hour,
    required this.locale,
    required this.settings,
    required this.readingMode,
  });

  @override
  ConsumerState<_HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends ConsumerState<_HadithCard> {
  bool _isArabicExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(hadithBookmarkProvider);
    final isBookmarked = bookmarks.contains('${widget.bookId}:${widget.hadith.number}');
    final audio = ref.watch(recitationAudioProvider);
    final isPlaying = audio.isPlaying &&
        audio.type == RecitationType.hadith &&
        audio.currentVerse == widget.hadith.number;

    final isBangla = widget.locale == AppLocale.bangla;

    // Resolve sanitized translation without raw Arabic header contamination
    final resolvedTranslation = HadithTextSanitizer.resolveTranslation(
      bengali: widget.hadith.bengali,
      english: widget.hadith.english,
      fallbackText: widget.hadith.text,
      locale: widget.locale,
    );

    final resolvedTransliteration = isBangla
        ? (widget.hadith.transliterationBn ??
            (widget.hadith.transliteration != null
                ? BengaliPhoneticHelper.toBengaliPronunciation(widget.hadith.transliteration!)
                : ''))
        : (widget.hadith.transliteration ?? '');

    // Dynamic Arabic Typography
    final arabicStyle = widget.settings.arabicScript == ArabicScript.uthmanic
        ? GoogleFonts.amiri(
            fontSize: widget.settings.arabicFontSize,
            height: 2.0,
            color: isPlaying ? const Color(0xFFFFFBEA) : const Color(0xFFFFFDF5),
          )
        : GoogleFonts.scheherazadeNew(
            fontSize: widget.settings.arabicFontSize,
            height: 2.0,
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
          color: isPlaying ? NekiColors.emeraldLight : const Color(0xFF1E3D2D),
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
          // ── Header Row ──
          Row(
            children: [
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
                  '#${widget.hadith.number}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                  ),
                ),
              ),
              if (widget.hadith.grade != null && widget.hadith.grade!.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildGradeBadge(widget.hadith.grade!),
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
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: 'Copy Hadith',
                icon: const Icon(Icons.copy_rounded, size: 17, color: Colors.white54),
                onPressed: () {
                  final textToCopy = '${widget.hadith.arabic}\n\n'
                      '${resolvedTranslation.text}\n'
                      '(${widget.hadith.reference ?? "Hadith ${widget.hadith.number}"})'
                      '${widget.hadith.grade != null ? " [${widget.hadith.grade}]" : ""}';
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  NekiSnackBar.showSuccess(
                    context,
                    message: isBangla ? 'হাদিস কপি করা হয়েছে' : 'Copied Hadith to clipboard',
                  );
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark Hadith',
                icon: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 21,
                  color: isBookmarked ? NekiColors.goldLight : Colors.white54,
                ),
                onPressed: () {
                  final willBeBookmarked = !isBookmarked;
                  ref
                      .read(hadithBookmarkProvider.notifier)
                      .toggle(widget.bookId, widget.hadith.number);
                  NekiSnackBar.showBookmark(
                    context,
                    isSaved: willBeBookmarked,
                    message: willBeBookmarked
                        ? (isBangla ? 'বুকমার্কে সংরক্ষণ করা হয়েছে' : 'Saved to Bookmarks')
                        : (isBangla ? 'বুকমার্ক সরানো হয়েছে' : 'Bookmark removed'),
                  );
                },
              ),
            ],
          ),

          // ── Narrator attribution chip ──
          if ((widget.hadith.narrator != null && widget.hadith.narrator!.isNotEmpty) ||
              resolvedTranslation.narrator != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: NekiColors.goldLight.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, size: 12, color: NekiColors.goldLight),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.hadith.narrator?.isNotEmpty == true
                        ? widget.hadith.narrator!
                        : resolvedTranslation.narrator!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: NekiColors.goldLight.withValues(alpha: 0.95),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // ── BODY: Progressive Layout by Reading Mode ──
          if (widget.readingMode == HadithReadingMode.translationFirst) ...[
            // ── TRANSLATION FIRST (Prominent & Immediate) ──
            if (widget.settings.showTranslation && resolvedTranslation.text.isNotEmpty) ...[
              _buildTranslationBlock(resolvedTranslation.text),
              const SizedBox(height: 12),
            ],
            if (widget.settings.showTransliteration && resolvedTransliteration.isNotEmpty) ...[
              _buildTransliterationBlock(resolvedTransliteration),
              const SizedBox(height: 12),
            ],
            if (widget.settings.showArabic && widget.hadith.arabic.isNotEmpty)
              _buildCollapsibleArabicAccordion(
                widget.hadith.arabic,
                arabicStyle,
                isBangla,
              ),
          ] else if (widget.readingMode == HadithReadingMode.dual) ...[
            // ── DUAL VIEW (Arabic with smart collapse guard, then translation) ──
            if (widget.settings.showArabic && widget.hadith.arabic.isNotEmpty) ...[
              _buildGuardedArabicBox(
                widget.hadith.arabic,
                arabicStyle,
                isBangla,
              ),
              const SizedBox(height: 14),
            ],
            if (widget.settings.showTransliteration && resolvedTransliteration.isNotEmpty) ...[
              _buildTransliterationBlock(resolvedTransliteration),
              const SizedBox(height: 12),
            ],
            if (widget.settings.showTranslation && resolvedTranslation.text.isNotEmpty)
              _buildTranslationBlock(resolvedTranslation.text),
          ] else ...[
            // ── ARABIC FOCUS ──
            if (widget.settings.showArabic && widget.hadith.arabic.isNotEmpty) ...[
              _buildGuardedArabicBox(
                widget.hadith.arabic,
                arabicStyle,
                isBangla,
                forceExpanded: true,
              ),
              const SizedBox(height: 12),
            ],
            if (widget.settings.showTransliteration && resolvedTransliteration.isNotEmpty) ...[
              _buildTransliterationBlock(resolvedTransliteration),
              const SizedBox(height: 12),
            ],
            if (widget.settings.showTranslation && resolvedTranslation.text.isNotEmpty) ...[
              _buildCollapsibleTranslationDrawer(resolvedTranslation.text, isBangla),
            ],
          ],

          // ── Reference / Citation ──
          if (widget.hadith.reference != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 12, color: Colors.white38),
                const SizedBox(width: 5),
                Text(
                  widget.hadith.reference!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ── Action Toolbar: Recite & Check + Listen ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    PronunciationCheckerModal.show(
                      context,
                      title: widget.hadith.reference ?? 'Hadith #${widget.hadith.number}',
                      arabicText: widget.hadith.arabic,
                      transliteration: resolvedTransliteration,
                      translation: resolvedTranslation.text,
                      hadith: widget.hadith,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NekiColors.goldLight,
                    side: BorderSide(color: NekiColors.goldLight.withValues(alpha: 0.45)),
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
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isPlaying) {
                      ref.read(recitationAudioProvider.notifier).togglePlayPause();
                    } else {
                      ref.read(recitationAudioProvider.notifier).playHadith(
                        widget.hadith,
                        trackMode: widget.settings.audioTrackMode,
                      );
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
                    isPlaying
                        ? Icons.pause_rounded
                        : (widget.settings.audioTrackMode == AudioTrackMode.translation
                            ? Icons.record_voice_over_rounded
                            : Icons.volume_up_rounded),
                    size: 15,
                  ),
                  label: Text(
                    isPlaying
                        ? (isBangla ? 'বিরতি' : 'Pause')
                        : (widget.settings.audioTrackMode == AudioTrackMode.translation
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
    );
  }

  // ─────────────────────────────────────────────────────
  //  Translation Block
  // ─────────────────────────────────────────────────────

  Widget _buildTranslationBlock(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: widget.settings.translationFontSize,
        height: 1.65,
        color: const Color(0xFFEFF5F1),
        letterSpacing: 0.15,
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Transliteration / Pronunciation Block
  // ─────────────────────────────────────────────────────

  Widget _buildTransliterationBlock(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: NekiColors.goldLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.locale == AppLocale.bangla ? 'উচ্চারণ' : 'Pronunciation',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: NekiColors.goldLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: widget.settings.translationFontSize * 0.95,
                height: 1.55,
                fontStyle: FontStyle.italic,
                color: const Color(0xFFC7E6D5),
                letterSpacing: 0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Collapsible Arabic Accordion (Translation First mode)
  // ─────────────────────────────────────────────────────

  Widget _buildCollapsibleArabicAccordion(
    String arabic,
    TextStyle arabicStyle,
    bool isBangla,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isArabicExpanded = !_isArabicExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories_rounded, size: 14, color: NekiColors.emeraldLight),
                  const SizedBox(width: 8),
                  Text(
                    isBangla ? 'মূল আরবী পাঠ (Arabic Matn)' : 'Original Arabic Scripture',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NekiColors.emeraldLight,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isArabicExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (_isArabicExpanded) ...[
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                arabic,
                style: arabicStyle,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Guarded Arabic Box with Smart Truncation (Dual view)
  // ─────────────────────────────────────────────────────

  Widget _buildGuardedArabicBox(
    String arabic,
    TextStyle arabicStyle,
    bool isBangla, {
    bool forceExpanded = false,
  }) {
    final isLong = arabic.length > 200;
    final isExpanded = forceExpanded || _isArabicExpanded || !isLong;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            arabic,
            style: arabicStyle,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: isExpanded ? null : 3,
            overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (isLong && !forceExpanded) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _isArabicExpanded = !_isArabicExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isArabicExpanded
                          ? (isBangla ? 'সংক্ষেপ করুন ▲' : 'Collapse Arabic ▲')
                          : (isBangla ? 'সম্পূর্ণ আরবী দেখুন ▼' : 'Show Full Arabic ▼'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: NekiColors.emeraldLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Collapsible Translation Drawer (Arabic Focus mode)
  // ─────────────────────────────────────────────────────

  Widget _buildCollapsibleTranslationDrawer(String text, bool isBangla) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        title: Text(
          isBangla ? 'অনুবাদ দেখুন' : 'View Translation',
          style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          _buildTranslationBlock(text),
        ],
      ),
    );
  }

  Widget _buildGradeBadge(String grade) {
    final lower = grade.toLowerCase();
    Color badgeColor;
    IconData badgeIcon;

    if (lower.contains('sahih') || lower.contains('সহীহ')) {
      badgeColor = NekiColors.emeraldLight;
      badgeIcon = Icons.verified_rounded;
    } else if (lower.contains('hasan') || lower.contains('হাসান')) {
      badgeColor = const Color(0xFF4DB6AC);
      badgeIcon = Icons.check_circle_outline_rounded;
    } else {
      badgeColor = NekiColors.goldLight;
      badgeIcon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 11, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            grade,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
