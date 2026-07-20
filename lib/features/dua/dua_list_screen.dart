import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import '../../core/widgets/animated_gradient_bg.dart';
import 'dua_detail_screen.dart';
import 'dua_provider.dart';

/// Shows all duas within a specific category as a tappable list.
class DuaListScreen extends ConsumerWidget {
  final String categoryId;

  const DuaListScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duasAsync = ref.watch(duasByCategoryProvider(categoryId));
    final locale = ref.watch(localeProvider);
    final hour = DateTime.now().hour;

    // Get category display name
    final categoriesAsync = ref.watch(duaCategoriesProvider);
    final categoryName = categoriesAsync.whenOrNull(
      data: (cats) {
        final cat = cats.where((c) => c.id == categoryId).firstOrNull;
        return locale == AppLocale.bangla
            ? cat?.nameBn ?? categoryId
            : cat?.nameEn ?? categoryId;
      },
    ) ?? categoryId;

    return AnimatedGradientBackground(
      showMosque: false,
      showStars: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded,
                          color: NekiColors.adaptiveTextPrimary(hour),
                          size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        categoryName,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: NekiColors.adaptiveTextPrimary(hour),
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Dua List ──
              Expanded(
                child: duasAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: NekiColors.emeraldLight),
                  ),
                  error: (_, __) => const Center(
                    child: Text('Failed to load duas.',
                        style: TextStyle(
                          color: Colors.white70,
                          decoration: TextDecoration.none,
                        )),
                  ),
                  data: (duas) => ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: duas.length,
                    itemBuilder: (context, index) {
                      final dua = duas[index];
                      return _DuaListTile(
                        dua: dua,
                        index: index,
                        hour: hour,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  Dua List Tile
// ─────────────────────────────────────────────────────

class _DuaListTile extends StatelessWidget {
  final Dua dua;
  final int index;
  final int hour;
  final VoidCallback onTap;

  const _DuaListTile({
    required this.dua,
    required this.index,
    required this.hour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NekiColors.adaptiveCardBorder(hour)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: NekiColors.emeraldPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.emeraldLight,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dua.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: NekiColors.adaptiveTextPrimary(hour),
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dua.arabic,
                    style: GoogleFonts.amiri(
                      fontSize: 14,
                      color: NekiColors.adaptiveTextSecondary(hour),
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: NekiColors.adaptiveTextSecondary(hour),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
