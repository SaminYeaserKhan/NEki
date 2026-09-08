import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;

import '../../../core/theme/neki_colors.dart';

/// Authentic Islamic illuminated arch header frame for Surah beginnings.
class SurahOrnateHeader extends StatelessWidget {
  final int surahNumber;
  final VoidCallback? onJumpTap;

  const SurahOrnateHeader({
    super.key,
    required this.surahNumber,
    this.onJumpTap,
  });

  @override
  Widget build(BuildContext context) {
    final surahNameEn = quran.getSurahName(surahNumber);
    final surahNameAr = quran.getSurahNameArabic(surahNumber);
    final place = quran.getPlaceOfRevelation(surahNumber);
    final verseCount = quran.getVerseCount(surahNumber);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF133624),
            Color(0xFF091C12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: NekiColors.goldLight.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle Arch Background Watermark
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: _SurahFramePainter(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                // Top Row: Surah Index and Revelation Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Surah index badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NekiColors.emeraldLight.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'SURAH $surahNumber',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: NekiColors.emeraldLight,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Revelation place & Ayahs badge (tap to jump)
                    Flexible(
                      child: GestureDetector(
                        onTap: onJumpTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: onJumpTap != null
                                ? NekiColors.goldLight.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: onJumpTap != null
                                  ? NekiColors.goldLight.withValues(alpha: 0.45)
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                place.toLowerCase().contains('makk') ? Icons.location_on_rounded : Icons.mosque_rounded,
                                size: 11,
                                color: NekiColors.goldLight,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$place • $verseCount Ayahs',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: onJumpTap != null ? NekiColors.goldLight : Colors.white70,
                                    decoration: TextDecoration.none,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (onJumpTap != null) ...[
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.format_list_numbered_rounded,
                                  size: 11,
                                  color: NekiColors.goldLight,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Large Arabic Calligraphy Name
                Text(
                  surahNameAr,
                  style: GoogleFonts.amiri(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFF7DB),
                    height: 1.4,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),

                // English Name
                Text(
                  surahNameEn,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Bismillah Calligraphy (unless Surah 9 At-Tawbah)
                if (surahNumber != 9) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2117).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: NekiColors.goldLight.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: NekiColors.gold.withValues(alpha: 0.08),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          quran.basmala,
                          style: GoogleFonts.amiriQuran(
                            fontSize: 22,
                            height: 1.8,
                            color: NekiColors.goldLight,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.3)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
