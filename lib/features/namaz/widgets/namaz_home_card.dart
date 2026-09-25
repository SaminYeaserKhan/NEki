import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/neki_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../../home/prayer_provider.dart';
import '../providers/prayer_location_provider.dart';
import '../providers/prayer_tracker_provider.dart';
import '../screens/namaz_screen.dart';

/// Interactive Bento Card for Namaz section on the Home Screen.
class NamazHomeCard extends ConsumerWidget {
  final int hour;

  const NamazHomeCard({super.key, required this.hour});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveWaqt = ref.watch(liveWaqtProvider);
    final location = ref.watch(prayerLocationProvider).location;
    final tracker = ref.watch(dailyPrayerTrackerProvider).record;
    final isBn = ref.watch(localeProvider) == AppLocale.bangla;
    final is24Hour = ref.watch(is24HourProvider);
    final timeFormat = is24Hour ? DateFormat('HH:mm') : DateFormat('h:mm a');

    final textPrimary = NekiColors.adaptiveTextPrimary(hour);
    final textSecondary = NekiColors.adaptiveTextSecondary(hour);

    return liveWaqt.when(
      loading: () => BentoCard(
        height: 175,
        child: Center(
          child: CircularProgressIndicator(color: textPrimary),
        ),
      ),
      error: (_, _) => BentoCard(
        height: 175,
        child: Center(
          child: Text(
            isBn ? 'নামাজের সময় লোড হচ্ছে...' : 'Loading prayer schedule...',
            style: TextStyle(color: textSecondary),
          ),
        ),
      ),
      data: (waqt) {
        final sched = waqt.todaySchedule;

        return BentoCard(
          height: null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NamazScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // ── Header Row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.access_time_filled_rounded,
                          color: NekiColors.emeraldPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBn ? 'আজকের নামাজের সময়সূচি' : "Today's Prayer Times",
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                location.isAutoGps
                                    ? Icons.my_location_rounded
                                    : Icons.location_on_rounded,
                                size: 11,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                location.cityName,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${tracker.farzCompletedCount}/5 ${isBn ? 'আদায়' : 'Prayed'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: NekiColors.emeraldPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: textSecondary, size: 14),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── 5 Daily Prayers Pill Row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPrayerPill(
                    name: isBn ? 'ফজর' : 'Fajr',
                    time: timeFormat.format(sched.fajr),
                    isActive: waqt.currentWaqtName == 'Fajr',
                    isDone: tracker.fajr,
                    hour: hour,
                  ),
                  _buildPrayerPill(
                    name: isBn ? 'যোহর' : 'Dhuhr',
                    time: timeFormat.format(sched.dhuhr),
                    isActive: waqt.currentWaqtName == 'Dhuhr',
                    isDone: tracker.dhuhr,
                    hour: hour,
                  ),
                  _buildPrayerPill(
                    name: isBn ? 'আসর' : 'Asr',
                    time: timeFormat.format(sched.asr),
                    isActive: waqt.currentWaqtName == 'Asr',
                    isDone: tracker.asr,
                    hour: hour,
                  ),
                  _buildPrayerPill(
                    name: isBn ? 'মাগরিব' : 'Maghrib',
                    time: timeFormat.format(sched.maghrib),
                    isActive: waqt.currentWaqtName == 'Maghrib',
                    isDone: tracker.maghrib,
                    hour: hour,
                  ),
                  _buildPrayerPill(
                    name: isBn ? 'ইশা' : 'Isha',
                    time: timeFormat.format(sched.isha),
                    isActive: waqt.currentWaqtName == 'Isha',
                    isDone: tracker.isha,
                    hour: hour,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Bottom Action Hint ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${isBn ? 'পরবর্তী' : 'Next'}: ${waqt.nextWaqtName} at ${timeFormat.format(waqt.nextWaqtStart)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                  Text(
                    isBn ? 'সম্পূর্ণ শিডিউল ও ট্র্যাকার ➔' : 'Full Schedule & Tracker ➔',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.emeraldPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
    );
  }

  Widget _buildPrayerPill({
    required String name,
    required String time,
    required bool isActive,
    required bool isDone,
    required int hour,
  }) {
    final textPrimary = NekiColors.adaptiveTextPrimary(hour);

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? NekiColors.emeraldPrimary
            : (isDone
                ? NekiColors.emeraldPrimary.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? NekiColors.gold
              : (isDone
                  ? NekiColors.emeraldPrimary.withValues(alpha: 0.3)
                  : Colors.transparent),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive
                  ? Colors.white
                  : (isDone ? NekiColors.emeraldPrimary : textPrimary),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white70 : textPrimary.withValues(alpha: 0.8),
            ),
          ),
          if (isDone) ...[
            const SizedBox(height: 2),
            Icon(Icons.check_circle_rounded,
                size: 11,
                color: isActive ? Colors.white : NekiColors.emeraldPrimary),
          ],
        ],
      ),
    );
  }
}
