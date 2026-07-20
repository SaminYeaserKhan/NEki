import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:quran/quran.dart' as quran;

import '../../core/theme/neki_colors.dart';
import 'quran_provider.dart';

/// Reads a single surah verse-by-verse with:
/// 1. Arabic text
/// 2. Pronunciation/transliteration (fetched from alquran.cloud API)
/// 3. Translation (Bengali default, toggleable to English)
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
  final Map<int, GlobalKey> _verseKeys = {};

  // Transliteration data fetched from API
  Map<int, String> _transliterations = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    final verseCount = quran.getVerseCount(widget.surahNumber);
    for (int i = 1; i <= verseCount; i++) {
      _verseKeys[i] = GlobalKey();
    }

    // Fetch transliterations from alquran.cloud
    _fetchTransliterations();

    if (widget.initialVerse > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(widget.initialVerse);
      });
    }
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
          setState(() {
            _transliterations = map;
          });
        }
      }
    } catch (_) {
      // Silently fail — transliteration is optional
    }
  }

  void _scrollToVerse(int verse) {
    final key = _verseKeys[verse];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
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
    final translationLang = ref.watch(translationProvider);
    final audioState = ref.watch(audioPlayerProvider);
    final verseCount = quran.getVerseCount(widget.surahNumber);
    final surahNameEn = quran.getSurahName(widget.surahNumber);
    final surahNameAr = quran.getSurahNameArabic(widget.surahNumber);
    final place = quran.getPlaceOfRevelation(widget.surahNumber);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B14),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(surahNameEn, surahNameAr, place, verseCount),
            _buildTranslationToggle(translationLang),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: verseCount + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildBismillahHeader();
                  final verseNum = index;
                  return _VerseCard(
                    key: _verseKeys[verseNum],
                    surahNumber: widget.surahNumber,
                    verseNumber: verseNum,
                    translationLang: translationLang,
                    transliteration: _transliterations[verseNum],
                    isPlaying: audioState.state == AudioState.playing &&
                        audioState.currentVerse == verseNum &&
                        audioState.currentSurah == widget.surahNumber,
                    onPlayTap: () {
                      ref
                          .read(audioPlayerProvider.notifier)
                          .playVerse(widget.surahNumber, verseNum);
                    },
                    onSaveProgress: () {
                      ref
                          .read(readingProgressProvider.notifier)
                          .update(widget.surahNumber, verseNum);
                    },
                  );
                },
              ),
            ),

            if (audioState.state != AudioState.idle)
              _buildAudioControls(audioState),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(
      String nameEn, String nameAr, String place, int verseCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nameEn,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none)),
                Text('$place • $verseCount Verses',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        decoration: TextDecoration.none)),
              ],
            ),
          ),
          Text(nameAr,
              style: GoogleFonts.amiri(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.goldLight)),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildTranslationToggle(TranslationLang lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              ref
                  .read(audioPlayerProvider.notifier)
                  .playSurah(widget.surahNumber);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: NekiColors.emeraldLight.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_filled_rounded,
                      size: 18, color: NekiColors.emeraldLight),
                  const SizedBox(width: 6),
                  Text('Play Surah',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NekiColors.emeraldLight,
                          decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => ref.read(translationProvider.notifier).toggle(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(
                    lang == TranslationLang.bengali ? 'বাংলা' : 'English',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBismillahHeader() {
    if (widget.surahNumber == 9) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(quran.basmala,
            style: GoogleFonts.amiriQuran(
                fontSize: 28, color: NekiColors.goldLight),
            textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildAudioControls(AudioPlayerState audioState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: NekiColors.nightElevated,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          if (audioState.state == AudioState.loading)
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: NekiColors.emeraldLight))
          else
            IconButton(
              icon: Icon(
                audioState.state == AudioState.playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: NekiColors.emeraldLight,
                size: 36,
              ),
              onPressed: () =>
                  ref.read(audioPlayerProvider.notifier).togglePlayPause(),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audioState.currentVerse != null
                      ? 'Verse ${audioState.currentVerse}'
                      : 'Full Surah',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: TextDecoration.none),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: audioState.duration.inMilliseconds > 0
                      ? audioState.position.inMilliseconds /
                          audioState.duration.inMilliseconds
                      : 0,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(NekiColors.emeraldLight),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.stop_rounded,
                color: Colors.white.withValues(alpha: 0.7)),
            onPressed: () => ref.read(audioPlayerProvider.notifier).stop(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Verse Card — shows 3 texts: Arabic, Pronunciation, Translation
// ─────────────────────────────────────────────────────

class _VerseCard extends StatelessWidget {
  final int surahNumber;
  final int verseNumber;
  final TranslationLang translationLang;
  final String? transliteration;
  final bool isPlaying;
  final VoidCallback onPlayTap;
  final VoidCallback onSaveProgress;

  const _VerseCard({
    super.key,
    required this.surahNumber,
    required this.verseNumber,
    required this.translationLang,
    this.transliteration,
    required this.isPlaying,
    required this.onPlayTap,
    required this.onSaveProgress,
  });

  @override
  Widget build(BuildContext context) {
    final arabicText =
        quran.getVerse(surahNumber, verseNumber, verseEndSymbol: true);

    final translation = translationLang == TranslationLang.bengali
        ? quran.getVerseTranslation(surahNumber, verseNumber,
            translation: quran.Translation.bengali)
        : quran.getVerseTranslation(surahNumber, verseNumber,
            translation: quran.Translation.enSaheeh);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPlaying
            ? NekiColors.emeraldPrimary.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaying
              ? NekiColors.emeraldLight.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Verse number + actions ──
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$verseNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.emeraldLight,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onPlayTap,
                child: Icon(
                  isPlaying
                      ? Icons.volume_up_rounded
                      : Icons.play_circle_outline_rounded,
                  color: isPlaying
                      ? NekiColors.emeraldLight
                      : Colors.white.withValues(alpha: 0.4),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  onSaveProgress();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bookmarked Verse $verseNumber'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                      backgroundColor: NekiColors.emeraldPrimary,
                    ),
                  );
                },
                child: Icon(
                  Icons.bookmark_border_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 1. Arabic text ──
          Text(
            arabicText,
            style: GoogleFonts.amiriQuran(
              fontSize: 24,
              height: 2.0,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),

          // ── 2. Pronunciation / Transliteration ──
          if (transliteration != null && transliteration!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: NekiColors.goldLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                transliteration!,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: NekiColors.goldLight.withValues(alpha: 0.85),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 10),

          // ── 3. Translation (Bengali / English) ──
          Text(
            translation,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.75),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
