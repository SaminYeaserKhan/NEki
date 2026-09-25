import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/neki_colors.dart';
import '../models/prayer_location.dart';
import '../providers/prayer_location_provider.dart';

/// Modal bottom sheet to switch location via GPS or manual city selection.
class LocationSelectorSheet extends ConsumerStatefulWidget {
  const LocationSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationSelectorSheet(),
    );
  }

  @override
  ConsumerState<LocationSelectorSheet> createState() =>
      _LocationSelectorSheetState();
}

class _LocationSelectorSheetState extends ConsumerState<LocationSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<PrayerLocation> _filteredCities = kPredefinedCities;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredCities = kPredefinedCities;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results =
        await ref.read(prayerLocationProvider.notifier).searchCities(query);
    if (mounted) {
      setState(() {
        _filteredCities = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(prayerLocationProvider);
    final currentLocation = locationState.location;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = ref.watch(localeProvider) == AppLocale.bangla;

    final sheetBg = isDark ? NekiColors.nightSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;
    final borderColor = isDark
        ? NekiColors.emeraldPrimary.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Grab Handle ──
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBn ? 'লোকেশন পরিবর্তন' : 'Select Location',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBn
                          ? 'সঠিক নামাজের সময় গণনার জন্য'
                          : 'For accurate astronomical prayer times',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Live GPS Button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: locationState.isLoadingGps
                    ? null
                    : () async {
                        final success = await ref
                            .read(prayerLocationProvider.notifier)
                            .refreshGpsLocation();
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isBn
                                      ? 'জিপিএস লোকেশন সফলভাবে আপডেট হয়েছে'
                                      : 'GPS Location updated successfully',
                                ),
                                backgroundColor: NekiColors.emeraldPrimary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            Navigator.of(context).pop();
                          } else if (locationState.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(locationState.errorMessage!),
                                backgroundColor: Colors.redAccent,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: NekiColors.emeraldPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: NekiColors.emeraldPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: locationState.isLoadingGps
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded,
                                color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBn
                                  ? 'ডিভাইসের লাইভ জিপিএস ব্যবহার করুন'
                                  : 'Use Device GPS Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: NekiColors.emeraldPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentLocation.isAutoGps
                                  ? (isBn
                                      ? 'বর্তমানে জিপিএস সক্রিয়: ${currentLocation.displayName}'
                                      : 'Active GPS: ${currentLocation.displayName}')
                                  : (isBn
                                      ? 'স্বয়ংক্রিয়ভাবে নিকটতম স্থান সনাক্ত করুন'
                                      : 'Automatically detect current coordinates'),
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (currentLocation.isAutoGps)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: NekiColors.emeraldPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: isBn
                    ? 'শহর বা দেশের নাম খুঁজুন...'
                    : 'Search city or country...',
                hintStyle: TextStyle(
                  color: textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            size: 18, color: textSecondary),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? NekiColors.nightElevated
                    : Colors.grey.withValues(alpha: 0.1),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: NekiColors.emeraldPrimary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Section Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  isBn ? 'জনপ্রিয় ও প্রধান শহরসমূহ' : 'Popular & Major Cities',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (_isSearching)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // ── Cities List ──
          Expanded(
            child: _filteredCities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off_rounded,
                            color: textSecondary, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          isBn ? 'কোনো শহর পাওয়া যায়নি' : 'No city found',
                          style: TextStyle(color: textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: _filteredCities.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final city = _filteredCities[index];
                      final isSelected = !currentLocation.isAutoGps &&
                          (currentLocation.cityName.toLowerCase() ==
                                  city.cityName.toLowerCase() ||
                              (currentLocation.latitude - city.latitude).abs() <
                                  0.01 &&
                                  (currentLocation.longitude - city.longitude)
                                          .abs() <
                                      0.01);

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? NekiColors.emeraldPrimary
                                  : (isDark
                                      ? NekiColors.nightElevated
                                      : Colors.grey.withValues(alpha: 0.12)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_rounded
                                  : Icons.location_city_rounded,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? NekiColors.textSecondaryOnDark
                                      : NekiColors.emeraldPrimary),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            city.cityName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? NekiColors.emeraldPrimary
                                  : textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            city.countryName.isNotEmpty
                                ? city.countryName
                                : '${city.latitude.toStringAsFixed(2)}°, ${city.longitude.toStringAsFixed(2)}°',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: NekiColors.emeraldPrimary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isBn ? 'নির্বাচিত' : 'Selected',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: NekiColors.emeraldPrimary,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () async {
                            await ref
                                .read(prayerLocationProvider.notifier)
                                .selectLocation(city);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isBn
                                        ? '${city.cityName} সেট করা হয়েছে'
                                        : 'Set to ${city.displayName}',
                                  ),
                                  backgroundColor: NekiColors.emeraldPrimary,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
