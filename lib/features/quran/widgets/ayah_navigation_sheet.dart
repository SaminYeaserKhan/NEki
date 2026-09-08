import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

import '../../../core/theme/neki_colors.dart';

/// Simplified, elegant modal bottom sheet allowing users to jump directly
/// to any specific Ayah number with a clean stepper input and quick landmark pills.
class AyahNavigationSheet extends StatefulWidget {
  final int surahNumber;
  final int totalVerses;
  final int currentVerse;
  final void Function(int verse, bool playRecitation) onAyahSelected;

  const AyahNavigationSheet({
    super.key,
    required this.surahNumber,
    required this.totalVerses,
    required this.currentVerse,
    required this.onAyahSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required int surahNumber,
    required int totalVerses,
    required int currentVerse,
    required void Function(int verse, bool playRecitation) onAyahSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahNavigationSheet(
        surahNumber: surahNumber,
        totalVerses: totalVerses,
        currentVerse: currentVerse,
        onAyahSelected: onAyahSelected,
      ),
    );
  }

  @override
  State<AyahNavigationSheet> createState() => _AyahNavigationSheetState();
}

class _AyahNavigationSheetState extends State<AyahNavigationSheet> {
  late TextEditingController _textController;
  late int _targetVerse;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _targetVerse = widget.currentVerse.clamp(1, widget.totalVerses);
    _textController = TextEditingController(text: _targetVerse.toString());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _setVerse(int verse) {
    final clamped = verse.clamp(1, widget.totalVerses);
    setState(() {
      _targetVerse = clamped;
      _textController.text = clamped.toString();
      _errorMessage = null;
    });
  }

  void _increment() {
    if (_targetVerse < widget.totalVerses) {
      _setVerse(_targetVerse + 1);
    }
  }

  void _decrement() {
    if (_targetVerse > 1) {
      _setVerse(_targetVerse - 1);
    }
  }

  void _submit({bool play = false}) {
    final text = _textController.text.trim();
    final parsed = int.tryParse(text);

    if (parsed == null || parsed < 1 || parsed > widget.totalVerses) {
      setState(() {
        _errorMessage = 'Enter an Ayah between 1 and ${widget.totalVerses}';
      });
      return;
    }

    Navigator.of(context).pop();
    widget.onAyahSelected(parsed, play);
  }

  @override
  Widget build(BuildContext context) {
    final surahNameEn = quran.getSurahName(widget.surahNumber);
    final surahNameAr = quran.getSurahNameArabic(widget.surahNumber);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C1F15),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: NekiColors.goldLight.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pull Bar Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Clean Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NekiColors.goldLight.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: NekiColors.goldLight.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.format_list_numbered_rounded,
                        color: NekiColors.goldLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Go to Ayah',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          Text(
                            '$surahNameEn • $surahNameAr (${widget.totalVerses} Ayahs)',
                            style: TextStyle(
                              fontSize: 12,
                              color: NekiColors.emeraldLight.withValues(alpha: 0.9),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Direct Stepper & Number Input ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF132E20),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _errorMessage != null
                          ? Colors.redAccent
                          : NekiColors.emeraldLight.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Minus button
                      IconButton(
                        tooltip: 'Previous Ayah',
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: NekiColors.emeraldLight,
                          size: 26,
                        ),
                        onPressed: _decrement,
                      ),

                      // Large centered number input
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: NekiColors.goldLight,
                          ),
                          decoration: InputDecoration(
                            hintText: '1',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 28,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= widget.totalVerses) {
                              setState(() {
                                _targetVerse = parsed;
                                _errorMessage = null;
                              });
                            }
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                      ),

                      // Plus button
                      IconButton(
                        tooltip: 'Next Ayah',
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: NekiColors.emeraldLight,
                          size: 26,
                        ),
                        onPressed: _increment,
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // ── Simple Essential Landmarks (3 to 4 pills max) ──
                _buildSimpleLandmarks(),
                const SizedBox(height: 18),

                // ── Single Primary Action Button ──
                ElevatedButton.icon(
                  onPressed: () => _submit(),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    'Navigate to Ayah $_targetVerse',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NekiColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleLandmarks() {
    final List<Widget> chips = [];

    // First Ayah
    chips.add(_buildChip(1, 'Ayah 1'));

    // Famous Surah Landmarks
    if (widget.surahNumber == 2) {
      chips.add(_buildChip(255, 'Ayat al-Kursi (255)', isSpecial: true));
      chips.add(_buildChip(285, 'Amanar-Rasul (285)', isSpecial: true));
    } else if (widget.surahNumber == 18) {
      chips.add(_buildChip(10, 'Ashab al-Kahf (10)', isSpecial: true));
    } else if (widget.surahNumber == 36) {
      chips.add(_buildChip(58, 'Salamun Qawlam (58)', isSpecial: true));
    } else if (widget.surahNumber == 67) {
      chips.add(_buildChip(30, 'Water Springs (30)', isSpecial: true));
    } else if (widget.totalVerses > 20) {
      final mid = (widget.totalVerses / 2).round();
      chips.add(_buildChip(mid, 'Ayah $mid'));
    }

    // Last Ayah
    if (widget.totalVerses > 1) {
      chips.add(_buildChip(widget.totalVerses, 'Ayah ${widget.totalVerses}'));
    }

    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: chips,
      ),
    );
  }

  Widget _buildChip(int verse, String label, {bool isSpecial = false}) {
    final isSelected = _targetVerse == verse;

    return GestureDetector(
      onTap: () => _setVerse(verse),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? NekiColors.emeraldPrimary
              : isSpecial
                  ? NekiColors.goldLight.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? NekiColors.emeraldLight
                : isSpecial
                    ? NekiColors.goldLight
                    : Colors.white12,
            width: isSelected || isSpecial ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected || isSpecial ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : isSpecial
                    ? NekiColors.goldLight
                    : Colors.white.withValues(alpha: 0.85),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
