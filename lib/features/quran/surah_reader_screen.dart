import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:quran/quran.dart' as quran;

import '../../core/theme/neki_colors.dart';
import '../recitations/providers/reading_settings_provider.dart';
import '../recitations/providers/recitation_audio_provider.dart';
import '../recitations/widgets/persistent_recitation_player.dart';
import '../recitations/widgets/recitation_settings_sheet.dart';
import 'quran_provider.dart';
import 'widgets/ayah_navigation_sheet.dart';
import 'widgets/mushaf_view_widget.dart';
import 'widgets/verse_study_view_widget.dart';

/// Redesigned Surah Reader supporting both:
/// 1. Mushaf Mode: Authentic continuous scripture flow with ۝ medallions.
/// 2. Verse Study Mode: Clean line-by-line layout with translation & transliteration.
/// Plus streamlined Ayah navigation modal to easily jump to specific ayahs.
class SurahReaderScreen extends ConsumerStatefulWidget {
  final int surahNumber;
  final int initialVerse;

  const SurahReaderScreen({
    super.key,
    required this.surahNumber,
    this.initialVerse = 1,
  });

  @override
  ConsumerState<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends ConsumerState<SurahReaderScreen> {
  late ScrollController _scrollController;
  Map<int, String> _transliterations = {};

  late int _currentVisibleVerse;
  int? _highlightedVerse;
  Timer? _highlightTimer;

  final GlobalKey<VerseStudyViewWidgetState> _studyKey = GlobalKey();
  final GlobalKey<MushafViewWidgetState> _mushafKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _currentVisibleVerse = widget.initialVerse.clamp(1, quran.getVerseCount(widget.surahNumber));
    _fetchTransliterations();
  }

  Future<void> _fetchTransliterations() async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.alquran.cloud/v1/surah/${widget.surahNumber}/en.transliteration',
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ayahs = data['data']['ayahs'] as List;
        final map = <int, String>{};
        for (final ayah in ayahs) {
          map[ayah['numberInSurah'] as int] = ayah['text'] as String;
        }
        if (mounted) {
          setState(() => _transliterations = map);
        }
      }
    } catch (_) {}
  }

  void _jumpToAyah(int verse, {bool playRecitation = false}) {
    final total = quran.getVerseCount(widget.surahNumber);
    final target = verse.clamp(1, total);

    setState(() {
      _currentVisibleVerse = target;
      _highlightedVerse = target;
    });

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _highlightedVerse = null);
    });

    final settings = ref.read(readingSettingsProvider);
    if (settings.readingMode == ReadingMode.mushaf) {
      _mushafKey.currentState?.scrollToAyah(target);
    } else {
      _studyKey.currentState?.scrollToVerse(target);
    }

    ref.read(readingProgressProvider.notifier).update(widget.surahNumber, target);

    if (playRecitation) {
      ref.read(recitationAudioProvider.notifier).playVerse(widget.surahNumber, target);
    }
  }

  void _showJumpSheet() {
    final total = quran.getVerseCount(widget.surahNumber);
    AyahNavigationSheet.show(
      context,
      surahNumber: widget.surahNumber,
      totalVerses: total,
      currentVerse: _currentVisibleVerse,
      onAyahSelected: (ayah, playAudio) {
        _jumpToAyah(ayah, playRecitation: playAudio);
      },
    );
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    final settingsNotifier = ref.read(readingSettingsProvider.notifier);
    final translationLang = ref.watch(translationProvider);
    final surahNameEn = quran.getSurahName(widget.surahNumber);
    final surahNameAr = quran.getSurahNameArabic(widget.surahNumber);
    final totalVerses = quran.getVerseCount(widget.surahNumber);

    return Scaffold(
      backgroundColor: const Color(0xFF09160F),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── Top Action Toolbar ──
                _buildTopToolbar(
                  context,
                  surahNameEn,
                  surahNameAr,
                  totalVerses,
                  settings,
                  settingsNotifier,
                  translationLang,
                ),

                // ── Reading Body (Mushaf vs Study View) ──
                Expanded(
                  child: settings.readingMode == ReadingMode.mushaf
                      ? MushafViewWidget(
                          key: _mushafKey,
                          surahNumber: widget.surahNumber,
                          scrollController: _scrollController,
                          transliterations: _transliterations,
                          initialVerse: widget.initialVerse,
                          highlightedVerse: _highlightedVerse,
                          onJumpRequested: _showJumpSheet,
                          onVisibleVerseChanged: (v) {
                            if (_currentVisibleVerse != v && mounted) {
                              setState(() => _currentVisibleVerse = v);
                            }
                          },
                        )
                      : VerseStudyViewWidget(
                          key: _studyKey,
                          surahNumber: widget.surahNumber,
                          scrollController: _scrollController,
                          transliterations: _transliterations,
                          initialVerse: widget.initialVerse,
                          highlightedVerse: _highlightedVerse,
                          onJumpRequested: _showJumpSheet,
                          onVisibleVerseChanged: (v) {
                            if (_currentVisibleVerse != v && mounted) {
                              setState(() => _currentVisibleVerse = v);
                            }
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
    );
  }

  Widget _buildTopToolbar(
    BuildContext context,
    String nameEn,
    String nameAr,
    int totalVerses,
    ReadingSettingsState settings,
    ReadingSettingsNotifier notifier,
    TranslationLang translationLang,
  ) {
    final isMushaf = settings.readingMode == ReadingMode.mushaf;
    final audio = ref.watch(recitationAudioProvider);
    final isThisSurah = audio.currentSurah == widget.surahNumber && audio.hasAudio;
    final isPlaying = isThisSurah && audio.isPlaying;
    final isLoading = isThisSurah && audio.isLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1F15),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),

          // Interactive Surah Title & Ayah Jump Badge
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showJumpSheet,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nameEn,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Ayah $_currentVisibleVerse of $totalVerses',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: NekiColors.goldLight.withValues(alpha: 0.9),
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // ── Play Surah Top Navigation Button ──
          IconButton(
            tooltip: isPlaying ? 'Pause Surah' : 'Play Surah',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: isPlaying
                    ? const LinearGradient(
                        colors: [NekiColors.emeraldPrimary, Color(0xFF1E5638)],
                      )
                    : null,
                color: isPlaying
                    ? null
                    : NekiColors.emeraldPrimary.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPlaying
                      ? NekiColors.goldLight
                      : NekiColors.emeraldLight.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: isPlaying
                    ? [
                        BoxShadow(
                          color: NekiColors.emeraldPrimary.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NekiColors.goldLight,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18,
                      color: isPlaying ? NekiColors.goldLight : NekiColors.emeraldLight,
                    ),
            ),
            onPressed: () {
              if (isPlaying) {
                ref.read(recitationAudioProvider.notifier).togglePlayPause();
              } else if (isThisSurah && audio.currentVerse != null) {
                ref.read(recitationAudioProvider.notifier).togglePlayPause();
              } else {
                ref.read(recitationAudioProvider.notifier).playSurah(widget.surahNumber);
              }
            },
          ),

          // ── Jump to Ayah Toolbar Button ──
          IconButton(
            tooltip: 'Go to Ayah',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(
                Icons.format_list_numbered_rounded,
                size: 16,
                color: NekiColors.goldLight,
              ),
            ),
            onPressed: _showJumpSheet,
          ),

          // Reading Mode Switcher Button (Mushaf <-> Study)
          IconButton(
            tooltip: isMushaf ? 'Switch to Verse Study' : 'Switch to Mushaf Flow',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(
                isMushaf ? Icons.view_headline_rounded : Icons.auto_stories_rounded,
                size: 16,
                color: NekiColors.emeraldLight,
              ),
            ),
            onPressed: () {
              notifier.setReadingMode(
                isMushaf ? ReadingMode.study : ReadingMode.mushaf,
              );
            },
          ),

          // Reading Display & Typography Settings
          IconButton(
            tooltip: 'Typography & Display Settings',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(
                Icons.text_fields_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ),
            onPressed: () => RecitationSettingsSheet.show(context),
          ),

          // Translation Language Toggle
          GestureDetector(
            onTap: () => ref.read(translationProvider.notifier).toggle(),
            child: Container(
              margin: const EdgeInsets.only(left: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.35)),
              ),
              child: Text(
                translationLang == TranslationLang.bengali ? 'বাং' : 'EN',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.emeraldLight,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
