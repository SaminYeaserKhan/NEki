import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale/app_strings.dart';
import '../../core/locale/locale_provider.dart';
import '../../core/theme/neki_colors.dart';
import 'dua_list_screen.dart';
import 'dua_provider.dart';

/// Dua Categories grid screen.
/// Shows categorized dua topics — tap to browse duas in each category.
class DuaScreen extends ConsumerWidget {
  const DuaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(duaCategoriesProvider);
    final locale = ref.watch(localeProvider);
    final s = S.of(locale);
    final hour = DateTime.now().hour;

    // Embedded in RecitationsScreen — parent provides gradient/header.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ── Category Grid ──
        Expanded(
          child: categoriesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: NekiColors.emeraldLight),
            ),
            error: (_, __) => Center(
              child: Text(s.failedToLoad,
                  style: TextStyle(
                    color: NekiColors.adaptiveTextSecondary(hour),
                    decoration: TextDecoration.none,
                  )),
            ),
            data: (categories) {
              if (categories.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: NekiColors.emeraldLight),
                      const SizedBox(height: 12),
                      Text(
                        'Loading duas...',
                        style: TextStyle(
                          color: NekiColors.adaptiveTextSecondary(hour),
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return _CategoryCard(
                    category: cat,
                    locale: locale,
                    hour: hour,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DuaListScreen(categoryId: cat.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
//  Category Card
// ─────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final DuaCategory category;
  final AppLocale locale;
  final int hour;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.locale,
    required this.hour,
    required this.onTap,
  });

  IconData _iconForCategory(String id) {
    switch (id) {
      case 'daily':
        return Icons.wb_sunny_rounded;
      case 'prayer':
        return Icons.mosque_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'hardship':
        return Icons.favorite_rounded;
      case 'protection':
        return Icons.shield_rounded;
      case 'social':
        return Icons.people_rounded;
      case 'ramadan':
        return Icons.nightlight_round;
      case 'death':
        return Icons.menu_book_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  Color _colorForCategory(String id) {
    switch (id) {
      case 'daily':
        return const Color(0xFFFFB74D); // Amber
      case 'prayer':
        return NekiColors.emeraldLight;
      case 'travel':
        return const Color(0xFF4FC3F7); // Blue
      case 'family':
        return const Color(0xFFE57373); // Pink
      case 'hardship':
        return const Color(0xFF9575CD); // Purple
      case 'protection':
        return const Color(0xFF4DB6AC); // Teal
      case 'social':
        return const Color(0xFF81C784); // Green
      case 'ramadan':
        return NekiColors.goldLight;
      case 'death':
        return const Color(0xFFBDBDBD); // Grey
      default:
        return NekiColors.emeraldMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCategory(category.id);
    final name = locale == AppLocale.bangla ? category.nameBn : category.nameEn;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NekiColors.adaptiveCardColor(hour),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconForCategory(category.id),
                  color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: NekiColors.adaptiveTextPrimary(hour),
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.count} duas',
                  style: TextStyle(
                    fontSize: 12,
                    color: NekiColors.adaptiveTextSecondary(hour),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
