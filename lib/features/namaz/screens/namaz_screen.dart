import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/neki_colors.dart';
import '../../home/prayer_provider.dart';
import '../models/prayer_calculation_settings.dart';
import '../providers/azan_player_provider.dart';
import '../providers/prayer_location_provider.dart';
import '../providers/prayer_schedule_provider.dart';
import '../providers/prayer_settings_provider.dart';
import '../providers/prayer_tracker_provider.dart';
import '../widgets/location_selector_sheet.dart';

/// Full-featured Namaz & Prayer Times Screen.
class NamazScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const NamazScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<NamazScreen> createState() => _NamazScreenState();
}

class _NamazScreenState extends ConsumerState<NamazScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedCalendarMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBn = ref.watch(localeProvider) == AppLocale.bangla;
    final locationState = ref.watch(prayerLocationProvider);
    final location = locationState.location;
    final is24Hour = ref.watch(is24HourProvider);

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1811), Color(0xFF11261B), Color(0xFF0D1B14)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2F8F4), Color(0xFFE8F2EC), Color(0xFFF8FAF9)],
          );

    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Top Bar ──
              _buildTopBar(
                context,
                isDark: isDark,
                isBn: isBn,
                location: location,
                is24Hour: is24Hour,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              // ── Segmented Navigation Tabs ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? NekiColors.nightElevated.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? NekiColors.emeraldPrimary.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: NekiColors.emeraldPrimary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: NekiColors.emeraldPrimary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: textSecondary,
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(text: isBn ? 'ওয়াক্ত' : 'Today'),
                    Tab(text: isBn ? 'ক্যালেন্ডার' : 'Calendar'),
                    Tab(text: isBn ? 'ট্র্যাকার' : 'Tracker'),
                    Tab(text: isBn ? 'সেটিংস' : 'Settings'),
                  ],
                ),
              ),

              // ── Tab Views ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTodayTab(context, isDark, isBn, is24Hour),
                    _buildCalendarTab(context, isDark, isBn, is24Hour),
                    _buildTrackerTab(context, isDark, isBn),
                    _buildSettingsTab(context, isDark, isBn),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Top Bar Widget
  // ─────────────────────────────────────────────────────────

  Widget _buildTopBar(
    BuildContext context, {
    required bool isDark,
    required bool isBn,
    required dynamic location,
    required bool is24Hour,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => LocationSelectorSheet.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        location.isAutoGps
                            ? Icons.my_location_rounded
                            : Icons.location_on_rounded,
                        size: 16,
                        color: NekiColors.emeraldPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  location.cityName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 18, color: textSecondary),
                            ],
                          ),
                          Text(
                            location.countryName.isNotEmpty
                                ? location.countryName
                                : (isBn ? 'লোকেশন পরিবর্তন' : 'Change Location'),
                            style: TextStyle(fontSize: 11, color: textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Language Toggle [বাং / EN]
          InkWell(
            onTap: () => ref.read(localeProvider.notifier).toggle(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? NekiColors.nightElevated
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? NekiColors.emeraldPrimary.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                isBn ? 'বাং' : 'EN',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.emeraldPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 12H / 24H Toggle
          InkWell(
            onTap: () => ref.read(is24HourProvider.notifier).toggle(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? NekiColors.nightElevated
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? NekiColors.emeraldPrimary.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                is24Hour ? '24H' : '12H',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.emeraldPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Tab 1: Today's Waqt & Live Schedule
  // ─────────────────────────────────────────────────────────

  Widget _buildTodayTab(
      BuildContext context, bool isDark, bool isBn, bool is24Hour) {
    final liveWaqt = ref.watch(liveWaqtProvider);
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;
    final timeFormat = is24Hour ? DateFormat('HH:mm') : DateFormat('h:mm a');

    return liveWaqt.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NekiColors.emeraldPrimary),
      ),
      error: (e, _) => Center(
        child: Text('Error loading prayer times: $e',
            style: TextStyle(color: textSecondary)),
      ),
      data: (waqt) {
        final schedule = waqt.todaySchedule;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Live Countdown Hero Card ──
            _buildLiveHeroWaqtCard(
              context,
              waqt: waqt,
              isDark: isDark,
              isBn: isBn,
              timeFormat: timeFormat,
            ),
            const SizedBox(height: 12),

            // ── Makruh Warning Pill (If Active) ──
            if (waqt.isMakruhTime && waqt.makruhReason != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isBn
                          ? 'মাকরূহ ওয়াক্ত: এই সময়ে সালাত নিষিদ্ধ বা অনুচিত (${waqt.makruhReason})'
                          : 'Prohibited Time: ${waqt.makruhReason}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Qibla Compass Pill ──
            _buildQiblaPill(
              context,
              schedule: schedule,
              isDark: isDark,
              isBn: isBn,
            ),
            const SizedBox(height: 16),

            // ── Section Title ──
            Text(
              isBn ? 'দৈনিক নামাজের ওয়াক্ত' : "Today's Prayer Timings",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // ── 5 Farz Prayer Cards ──
            _buildPrayerRowCard(
              nameEn: 'Fajr',
              nameBn: 'ফজর',
              arabic: 'الفجر',
              startTime: schedule.fajr,
              endTime: schedule.sunrise,
              icon: Icons.brightness_3_rounded,
              isCurrent: waqt.currentWaqtName == 'Fajr',
              timeFormat: timeFormat,
              isDark: isDark,
              isBn: isBn,
            ),
            _buildPrayerRowCard(
              nameEn: 'Sunrise',
              nameBn: 'সূর্যোদয় (ইশরাক শুরু)',
              arabic: 'الشروق',
              startTime: schedule.sunrise,
              endTime: schedule.sunrise.add(const Duration(minutes: 15)),
              icon: Icons.wb_sunny_outlined,
              isCurrent: waqt.currentWaqtName == 'Post-Sunrise',
              timeFormat: timeFormat,
              isDark: isDark,
              isBn: isBn,
              isSunnah: true,
            ),
            _buildPrayerRowCard(
              nameEn: 'Dhuhr',
              nameBn: 'যোহর',
              arabic: 'الظهر',
              startTime: schedule.dhuhr,
              endTime: schedule.asr,
              icon: Icons.wb_sunny_rounded,
              isCurrent: waqt.currentWaqtName == 'Dhuhr',
              timeFormat: timeFormat,
              isDark: isDark,
              isBn: isBn,
            ),
            _buildPrayerRowCard(
              nameEn: 'Asr',
              nameBn: 'আসর',
              arabic: 'العصر',
              startTime: schedule.asr,
              endTime: schedule.maghrib,
              icon: Icons.cloud_outlined,
              isCurrent: waqt.currentWaqtName == 'Asr',
              timeFormat: timeFormat,
              isDark: isDark,
              isBn: isBn,
            ),
            _buildPrayerRowCard(
              nameEn: 'Maghrib',
              nameBn: 'মাগরিব',
              arabic: 'المغرب',
              startTime: schedule.maghrib,
              endTime: schedule.isha,
              icon: Icons.nights_stay_outlined,
              isCurrent: waqt.currentWaqtName == 'Maghrib',
              timeFormat: timeFormat,
              isDark: isDark,
              isBn: isBn,
            ),
            _buildPrayerRowCard(
              nameEn: 'Isha',
              nameBn: 'ইশা',
              arabic: 'العشاء',
              startTime: schedule.isha,
              endTime: schedule.fajr.add(const Duration(days: 1)),
              icon: Icons.bedtime_rounded,
              isCurrent: waqt.currentWaqtName == 'Isha',
              timeFormat: timeFormat,
              isDark: isDark,
              isBn: isBn,
            ),
            const SizedBox(height: 16),

            // ── Extra Sunnah & Nafl Times ──
            Text(
              isBn ? 'সুন্নাত ও নফল ওয়াক্ত' : 'Sunnah & Voluntary Times',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildSunnahCard(
              titleEn: 'Tahajjud (Last 1/3 of Night)',
              titleBn: 'তাহাজ্জুদ (রাত্রির শেষ তৃতীয়াংশ)',
              arabic: 'التهجد',
              time: schedule.tahajjud,
              icon: Icons.stars_rounded,
              color: const Color(0xFF7E57C2),
              timeFormat: timeFormat,
              isDark: isDark,
            ),
            _buildSunnahCard(
              titleEn: 'Duha / Ishraq (Chasht)',
              titleBn: 'দুহা / ইশরাক ও চাশত',
              arabic: 'الضحى',
              time: schedule.duha,
              icon: Icons.light_mode_rounded,
              color: const Color(0xFFFFA000),
              timeFormat: timeFormat,
              isDark: isDark,
            ),
            _buildSunnahCard(
              titleEn: 'Islamic Midnight (Nisf al-Layl)',
              titleBn: 'ইসলামিক মধ্যরাত',
              arabic: 'نصف الليل',
              time: schedule.midnight,
              icon: Icons.dark_mode_rounded,
              color: const Color(0xFF3F51B5),
              timeFormat: timeFormat,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLiveHeroWaqtCard(
    BuildContext context, {
    required WaqtData waqt,
    required bool isDark,
    required bool isBn,
    required DateFormat timeFormat,
  }) {
    final diff = waqt.currentWaqtEnd.difference(waqt.currentTime);
    final hoursLeft = diff.inHours;
    final minutesLeft = diff.inMinutes % 60;
    final secondsLeft = diff.inSeconds % 60;

    String countdownStr = '${minutesLeft}m ${secondsLeft}s left';
    if (hoursLeft > 0) {
      countdownStr = '${hoursLeft}h ${minutesLeft}m left';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NekiColors.emeraldDeep,
            NekiColors.emeraldPrimary,
            const Color(0xFF1E5B3A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: NekiColors.emeraldPrimary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isBn ? 'চলমান ওয়াক্ত' : 'CURRENT WAQT',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    countdownStr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waqt.currentWaqtName,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isBn ? 'শেষ হবে' : 'Ends at'} ${timeFormat.format(waqt.currentWaqtEnd)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timeFormat.format(waqt.currentTime),
                style: GoogleFonts.inter(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar through current waqt
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: waqt.progressPercent,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(NekiColors.gold),
            ),
          ),
          const SizedBox(height: 14),

          // Next prayer preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.update_rounded,
                      size: 15, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    '${isBn ? 'পরবর্তী' : 'Next'}: ${waqt.nextWaqtName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              Text(
                timeFormat.format(waqt.nextWaqtStart),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: NekiColors.goldLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQiblaPill(
    BuildContext context, {
    required PrayerDaySchedule schedule,
    required bool isDark,
    required bool isBn,
  }) {
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? NekiColors.nightElevated.withValues(alpha: 0.7)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? NekiColors.emeraldPrimary.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: NekiColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.explore_rounded,
                color: NekiColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn ? 'ক্বিবলা দিক (মক্কা মুকাররমা)' : 'Qibla Direction',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  '${schedule.qiblaDirection.toStringAsFixed(1)}° ${isBn ? 'উত্তর থেকে ঘড়ির কাঁটার দিকে' : 'from North towards Kaaba'}',
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: NekiColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${schedule.qiblaDirection.round()}°',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: NekiColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerRowCard({
    required String nameEn,
    required String nameBn,
    required String arabic,
    required DateTime startTime,
    required DateTime endTime,
    required IconData icon,
    required bool isCurrent,
    required DateFormat timeFormat,
    required bool isDark,
    required bool isBn,
    bool isSunnah = false,
  }) {
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent
            ? NekiColors.emeraldPrimary.withValues(alpha: 0.15)
            : (isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.6)
                : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? NekiColors.emeraldPrimary
              : (isDark
                  ? NekiColors.emeraldPrimary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.06)),
          width: isCurrent ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCurrent
                  ? NekiColors.emeraldPrimary
                  : (isDark
                      ? NekiColors.nightSurface
                      : NekiColors.emeraldPale),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isCurrent
                  ? Colors.white
                  : (isDark ? NekiColors.emeraldLight : NekiColors.emeraldPrimary),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isBn ? nameBn : nameEn,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w600,
                        color: isCurrent ? NekiColors.emeraldPrimary : textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      arabic,
                      style: GoogleFonts.amiri(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: NekiColors.emeraldPrimary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isBn ? 'চলমান' : 'ACTIVE',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${isBn ? 'শেষ' : 'Until'} ${timeFormat.format(endTime)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeFormat.format(startTime),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCurrent ? NekiColors.emeraldPrimary : textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSunnahCard({
    required String titleEn,
    required String titleBn,
    required String arabic,
    required DateTime time,
    required IconData icon,
    required Color color,
    required DateFormat timeFormat,
    required bool isDark,
  }) {
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? NekiColors.nightElevated.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleEn,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  arabic,
                  style: GoogleFonts.amiri(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeFormat.format(time),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Tab 2: Monthly Calendar Schedule
  // ─────────────────────────────────────────────────────────

  Widget _buildCalendarTab(
      BuildContext context, bool isDark, bool isBn, bool is24Hour) {
    final scheduleList = ref.watch(monthlyScheduleProvider(_selectedCalendarMonth));
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;
    final timeFormat = is24Hour ? DateFormat('HH:mm') : DateFormat('h:mm');
    final monthHeader = DateFormat('MMMM yyyy').format(_selectedCalendarMonth);
    final today = DateTime.now();

    return Column(
      children: [
        // Month Selector Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded,
                    color: textPrimary, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedCalendarMonth = DateTime(
                      _selectedCalendarMonth.year,
                      _selectedCalendarMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                monthHeader,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded,
                    color: textPrimary, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedCalendarMonth = DateTime(
                      _selectedCalendarMonth.year,
                      _selectedCalendarMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
        ),

        // Table Header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  isBn ? 'তারিখ' : 'Date',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.emeraldPrimary),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    _TableColHeader('Fajr'),
                    _TableColHeader('Sun'),
                    _TableColHeader('Dhuhr'),
                    _TableColHeader('Asr'),
                    _TableColHeader('Magh'),
                    _TableColHeader('Isha'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Schedule List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: scheduleList.length,
            itemBuilder: (context, index) {
              final daySched = scheduleList[index];
              final isToday = daySched.date.year == today.year &&
                  daySched.date.month == today.month &&
                  daySched.date.day == today.day;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isToday
                      ? NekiColors.emeraldPrimary.withValues(alpha: 0.2)
                      : (isDark
                          ? NekiColors.nightElevated.withValues(alpha: 0.4)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isToday
                        ? NekiColors.emeraldPrimary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04)),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('d').format(daySched.date),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isToday
                                  ? NekiColors.emeraldPrimary
                                  : textPrimary,
                            ),
                          ),
                          Text(
                            DateFormat('E').format(daySched.date),
                            style: TextStyle(
                              fontSize: 10,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _TableTimeCell(timeFormat.format(daySched.fajr),
                              isDark: isDark, isToday: isToday),
                          _TableTimeCell(timeFormat.format(daySched.sunrise),
                              isDark: isDark, isToday: isToday),
                          _TableTimeCell(timeFormat.format(daySched.dhuhr),
                              isDark: isDark, isToday: isToday),
                          _TableTimeCell(timeFormat.format(daySched.asr),
                              isDark: isDark, isToday: isToday),
                          _TableTimeCell(timeFormat.format(daySched.maghrib),
                              isDark: isDark, isToday: isToday),
                          _TableTimeCell(timeFormat.format(daySched.isha),
                              isDark: isDark, isToday: isToday),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Tab 3: Daily Prayer Tracker & Qaza (Milestone 10.3)
  // ─────────────────────────────────────────────────────────

  Widget _buildTrackerTab(BuildContext context, bool isDark, bool isBn) {
    final trackerState = ref.watch(dailyPrayerTrackerProvider);
    final qazaRecord = ref.watch(qazaTrackerProvider);
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;

    final record = trackerState.record;
    final dateDisplay = DateFormat('EEEE, d MMMM yyyy').format(trackerState.selectedDate);
    final isToday = DateFormat('yyyy-MM-dd').format(trackerState.selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Date Stepper Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? NekiColors.emeraldPrimary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  ref.read(dailyPrayerTrackerProvider.notifier).changeDate(
                        trackerState.selectedDate.subtract(const Duration(days: 1)),
                      );
                },
              ),
              Column(
                children: [
                  Text(
                    isToday ? (isBn ? 'আজ' : 'Today') : dateDisplay,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  if (isToday)
                    Text(
                      dateDisplay,
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  ref.read(dailyPrayerTrackerProvider.notifier).changeDate(
                        trackerState.selectedDate.add(const Duration(days: 1)),
                      );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Completion Progress Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NekiColors.emeraldDeep,
                NekiColors.emeraldPrimary,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: record.farzCompletionRate,
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(NekiColors.gold),
                    ),
                    Center(
                      child: Text(
                        '${(record.farzCompletionRate * 100).round()}%',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.farzCompletedCount} of 5 Obligatory Prayers',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.farzCompletedCount == 5
                          ? (isBn
                              ? 'মাশাআল্লাহ! আজকের সকল ফরজ সালাত আদায় হয়েছে।'
                              : 'MashaAllah! All 5 Farz prayers completed today.')
                          : (isBn
                              ? 'নিয়মিত নামাজ আদায় করুন ও ট্র্যাকিং করুন।'
                              : 'Keep your prayers consistent and log daily.'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 5 Obligatory Farz Prayers Checklist
        Text(
          isBn ? 'ফরজ সালাত তালিকা' : 'Obligatory (Farz) Prayers',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        _buildPrayerChecklistTile(
          prayerKey: 'fajr',
          titleEn: 'Fajr (2 Farz)',
          titleBn: 'ফজর (২ রাকাত ফরজ)',
          isCompleted: record.fajr,
          isDark: isDark,
        ),
        _buildPrayerChecklistTile(
          prayerKey: 'dhuhr',
          titleEn: 'Dhuhr (4 Farz)',
          titleBn: 'যোহর (৪ রাকাত ফরজ)',
          isCompleted: record.dhuhr,
          isDark: isDark,
        ),
        _buildPrayerChecklistTile(
          prayerKey: 'asr',
          titleEn: 'Asr (4 Farz)',
          titleBn: 'আসর (৪ রাকাত ফরজ)',
          isCompleted: record.asr,
          isDark: isDark,
        ),
        _buildPrayerChecklistTile(
          prayerKey: 'maghrib',
          titleEn: 'Maghrib (3 Farz)',
          titleBn: 'মাগরিব (৩ রাকাত ফরজ)',
          isCompleted: record.maghrib,
          isDark: isDark,
        ),
        _buildPrayerChecklistTile(
          prayerKey: 'isha',
          titleEn: 'Isha (4 Farz)',
          titleBn: 'ইশা (৪ রাকাত ফরজ)',
          isCompleted: record.isha,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // Sunnah & Nafl Checklist
        Text(
          isBn ? 'সুন্নাত ও নফল সালাত' : 'Sunnah & Voluntary Prayers',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        _buildPrayerChecklistTile(
          prayerKey: 'witr',
          titleEn: 'Witr (3 Wajib)',
          titleBn: 'বিতর (৩ রাকাত ওয়াজিব)',
          isCompleted: record.witr,
          isDark: isDark,
          isSunnah: true,
        ),
        _buildPrayerChecklistTile(
          prayerKey: 'tahajjud',
          titleEn: 'Tahajjud (Qiyam al-Layl)',
          titleBn: 'তাহাজ্জুদ (কিয়ামুল লাইল)',
          isCompleted: record.tahajjud,
          isDark: isDark,
          isSunnah: true,
        ),
        _buildPrayerChecklistTile(
          prayerKey: 'duha',
          titleEn: 'Duha / Ishraq',
          titleBn: 'ইশরাক ও দুহা',
          isCompleted: record.duha,
          isDark: isDark,
          isSunnah: true,
        ),
        const SizedBox(height: 24),

        // ── Qaza (Missed Prayer) Tracker Deck ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBn ? 'কাযা নামাজ ট্র্যাকার' : 'Qaza-e-Umri Tracker',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  isBn
                      ? 'ছুটে যাওয়া নামাজের হিসাব ও আদায়'
                      : 'Track and fulfill your missed prayers',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Total: ${qazaRecord.totalQaza}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E57C2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid of Qaza Counters
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _buildQazaCard('fajr', isBn ? 'ফজর' : 'Fajr', qazaRecord.fajr, isDark),
            _buildQazaCard('dhuhr', isBn ? 'যোহর' : 'Dhuhr', qazaRecord.dhuhr, isDark),
            _buildQazaCard('asr', isBn ? 'আসর' : 'Asr', qazaRecord.asr, isDark),
            _buildQazaCard('maghrib', isBn ? 'মাগরিব' : 'Maghrib', qazaRecord.maghrib, isDark),
            _buildQazaCard('isha', isBn ? 'ইশা' : 'Isha', qazaRecord.isha, isDark),
            _buildQazaCard('witr', isBn ? 'বিতর' : 'Witr', qazaRecord.witr, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildPrayerChecklistTile({
    required String prayerKey,
    required String titleEn,
    required String titleBn,
    required bool isCompleted,
    required bool isDark,
    bool isSunnah = false,
  }) {
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? NekiColors.emeraldPrimary.withValues(alpha: 0.12)
            : (isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.5)
                : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? NekiColors.emeraldPrimary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Icon(
            isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isCompleted
                ? NekiColors.emeraldPrimary
                : (isDark ? Colors.white38 : Colors.black26),
            size: 24,
          ),
          title: Text(
            titleEn,
            style: GoogleFonts.outfit(
              fontSize: 14.5,
              fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
              color: isCompleted ? NekiColors.emeraldPrimary : textPrimary,
            ),
          ),
          trailing: isCompleted
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Prayed ✓',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: NekiColors.emeraldPrimary,
                    ),
                  ),
                )
              : null,
          onTap: () {
            HapticFeedback.lightImpact();
            ref
                .read(dailyPrayerTrackerProvider.notifier)
                .togglePrayer(prayerKey);
          },
        ),
      ),
    );
  }

  Widget _buildQazaCard(
      String prayerKey, String name, int count, bool isDark) {
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? NekiColors.nightElevated.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: count > 0 ? Colors.orangeAccent : textPrimary,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: count > 0
                    ? () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(qazaTrackerProvider.notifier)
                            .decrement(prayerKey);
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove_rounded,
                      size: 16, color: Colors.redAccent),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(qazaTrackerProvider.notifier)
                      .increment(prayerKey);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 16, color: NekiColors.emeraldPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Tab 4: Settings & Calculation Methods
  // ─────────────────────────────────────────────────────────

  Widget _buildSettingsTab(BuildContext context, bool isDark, bool isBn) {
    ref.listen<AzanPlayerState>(azanPlayerProvider, (prev, next) {
      if (next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final settings = ref.watch(prayerSettingsProvider);
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── App Language (ভাষা) ──
        _buildSettingsHeader(
          isBn ? 'অ্যাপের ভাষা' : 'App Language',
          textPrimary,
          onInfoTap: () => _showSettingInfoSheet(
            context: context,
            title: isBn ? 'অ্যাপের ভাষা নির্বাচন' : 'App Language Selection',
            description: isBn
                ? 'আপনি সম্পূর্ণ অ্যাপ ও নামাজের যাবতীয় বিবরণ বাংলা অথবা ইংরেজি যেকোনো ভাষায় দেখতে পারেন।\n\n'
                  'ভাষা পরিবর্তন করলে নামাজের ওয়াক্তের নাম, সেটিংস, হাদিস, দোয়া এবং সূরার অনুবাদ তৎক্ষণাৎ নির্বাচিত ভাষায় পরিবর্তিত হবে।'
                : 'Choose your preferred language for the entire app and prayer schedule.\n\n'
                  'Changing the language updates prayer names, settings, descriptions, Duas, and Quran interfaces immediately.',
            guidance: isBn
                ? 'পরামর্শ: বাংলা ভাষায় স্বাচ্ছন্দ্য বোধ করলে "বাংলা" নির্বাচন করে রাখুন।'
                : 'Recommendation: Select your preferred native language for an optimal spiritual experience.',
            icon: Icons.language_rounded,
            isDark: isDark,
            isBn: isBn,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    isBn
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isBn ? NekiColors.emeraldPrimary : textSecondary,
                  ),
                  title: Text(
                    'বাংলা (Bangla)',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'সকল বিবরণ ও নামাজের ওয়াক্তসমূহ বাংলায়',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: isBn
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'সক্রিয়',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: NekiColors.emeraldPrimary,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).setLocale(AppLocale.bangla);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    !isBn
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: !isBn ? NekiColors.emeraldPrimary : textSecondary,
                  ),
                  title: Text(
                    'English',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'All interface texts and prayer schedules in English',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  trailing: !isBn
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: NekiColors.emeraldPrimary,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    ref.read(localeProvider.notifier).setLocale(AppLocale.english);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Juristic School (Madhab) ──
        _buildSettingsHeader(
          isBn ? 'ফিকহি মাযহাব (আসর ওয়াক্ত)' : 'Juristic Method (Madhab)',
          textPrimary,
          onInfoTap: () => _showSettingInfoSheet(
            context: context,
            title: isBn ? 'ফিকহি মাযহাব ও আসরের ওয়াক্ত' : 'Juristic Method (Madhab) & Asr',
            description: isBn
                ? 'আসরের ওয়াক্ত শুরুর সময় নির্ধারণে ইসলামী ফিকহে দুটি প্রধান দৃষ্টিভঙ্গি রয়েছে:\n\n'
                  '• হানাফী মাযহাব (দ্বিগুণ ছায়া): কোনো বস্তুর ছায়া তার মূল দৈর্ঘ্য বাদে ঠিক দ্বিগুণ দীর্ঘ হলে আসরের ওয়াক্ত শুরু হয়। এটি বাংলাদেশ, ভারত, পাকিস্তান ও তুরস্কে অনুসরণ করা হয়, ফলে আসর কিছুটা দেরিতে শুরু হয়।\n\n'
                  '• শাফেঈ, মালেকী ও হাম্বলী (একগুণ ছায়া): বস্তুর ছায়া তার মূল দৈর্ঘ্যের সমান হলেই আসর শুরু হয়ে যায়, যা আরব বিশ্ব, মিশর ও দক্ষিণ-পূর্ব এশিয়ায় আন্তর্জাতিক মান হিসেবে গণ্য।'
                : 'There are two primary jurisprudential determinations for the start of Asr prayer:\n\n'
                  '• Hanafi (Shadow factor 2): Asr enters when the shadow of an object (excluding the midday shadow) is twice its length. This is standard in Bangladesh, Pakistan, India, and Turkey, resulting in a later Asr time.\n\n'
                  '• Shafi\'i, Maliki, Hanbali (Shadow factor 1): Asr enters earlier when the shadow equals the object\'s length. This is standard across Arab countries, Egypt, and Southeast Asia.',
            guidance: isBn
                ? 'পরামর্শ: আপনি যদি দক্ষিণ এশিয়ায় (যেমন বাংলাদেশে) থাকেন, তবে স্থানীয় মসজিদ ও ক্যালেন্ডারের সাথে মিল রাখতে "হানাফী" নির্বাচন করুন।'
                : 'Recommendation: If you reside in South Asia (Bangladesh, India, Pakistan), choose "Hanafi" to align with your local neighborhood mosques.',
            icon: Icons.balance_rounded,
            isDark: isDark,
            isBn: isBn,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    settings.madhab == Madhab.hanafi
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: settings.madhab == Madhab.hanafi
                        ? NekiColors.emeraldPrimary
                        : textSecondary,
                  ),
                  title: Text(
                    isBn ? 'হানাফী মাযহাব' : 'Hanafi (Standard in South Asia)',
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  subtitle: Text(
                    isBn
                        ? 'ছায়া দ্বিগুণ হওয়ার পর আসরের ওয়াক্ত শুরু হয়।'
                        : 'Shadow factor 2 (Later Asr time).',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  onTap: () {
                    ref
                        .read(prayerSettingsProvider.notifier)
                        .setMadhab(Madhab.hanafi);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    settings.madhab == Madhab.shafi
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: settings.madhab == Madhab.shafi
                        ? NekiColors.emeraldPrimary
                        : textSecondary,
                  ),
                  title: Text(
                    isBn
                        ? 'শাফেঈ, মালেকী ও হাম্বলী'
                        : "Shafi'i, Maliki, Hanbali (Earlier Asr)",
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  subtitle: Text(
                    isBn
                        ? 'ছায়া সমপরিমাণ হওয়ার পর আসরের ওয়াক্ত শুরু হয়।'
                        : 'Shadow factor 1 (Standard international Asr).',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  onTap: () {
                    ref
                        .read(prayerSettingsProvider.notifier)
                        .setMadhab(Madhab.shafi);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── International Calculation Method ──
        _buildSettingsHeader(
          isBn ? 'গণনা পদ্ধতি (কনভেনশন)' : 'Calculation Method Convention',
          textPrimary,
          onInfoTap: () => _showSettingInfoSheet(
            context: context,
            title: isBn ? 'গণনা পদ্ধতি ও সৌর কোণ' : 'Calculation Method Convention',
            description: isBn
                ? 'ফজর (সুবহে সাদিক) এবং ইশার ওয়াক্ত নির্ধারণে পৃথিবীর বিভিন্ন অঞ্চলের ফিকহ বোর্ড ও সরকার দিগন্তের নিচে সূর্যের কৌণিক অবস্থান (Twilight Depression Angle) নির্দিষ্ট করেছে:\n\n'
                  '• করাচী (১৮° ফজর / ১৮° ইশা): ইসলামিক ইউনিভার্সিটি করাচী এবং বাংলাদেশ ইসলামিক ফাউন্ডেশনের অনুসৃত নিয়ম।\n\n'
                  '• উম্মুল কুরা (মক্কা): সৌদি আরবে ব্যবহৃত হয় (ফজর ১৮.৫°, ইশা মাগরিবের ৯০ মিনিট পর)।\n\n'
                  '• মুসলিম ওয়ার্ল্ড লীগ (১৮° / ১৭°): ইউরোপ ও উত্তর আমেরিকায় বহুল ব্যবহৃত আন্তর্জাতিক নিয়ম।\n\n'
                  '• মিশরীয় কর্তৃপক্ষ (১৯.৫° / ১৭.৫°): মিশর, আফ্রিকা ও মধ্যপ্রাচ্যের একাংশে মানা হয়।'
                : 'Prayer calculation methods determine the solar depression angle below the horizon used to calculate Fajr (true dawn) and Isha (complete darkness):\n\n'
                  '• Karachi (18° Fajr / 18° Isha): Official standard of the Islamic Foundation of Bangladesh, Pakistan, and India.\n\n'
                  '• Umm al-Qura (Makkah): Standard in Saudi Arabia and the Arabian Peninsula (18.5° Fajr, Isha is fixed 90 minutes after Maghrib).\n\n'
                  '• Muslim World League (18° / 17°): Standard across Europe, North America, and international Islamic centers.\n\n'
                  '• Egyptian General Authority (19.5° / 17.5°): Widely used in Egypt, Africa, and parts of the Levant.',
            guidance: isBn
                ? 'পরামর্শ: বাংলাদেশ ও উপমহাদেশে নির্ভুল সময়ের জন্য "Karachi" পদ্ধতি নির্বাচন করে রাখা সর্বোত্তম।'
                : 'Recommendation: Keep "Karachi" selected for maximum accuracy within Bangladesh and the Indian subcontinent.',
            icon: Icons.public_rounded,
            isDark: isDark,
            isBn: isBn,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CalculationMethod>(
              value: settings.calculationMethod,
              isExpanded: true,
              dropdownColor: isDark ? NekiColors.nightSurface : Colors.white,
              items: CalculationMethod.values.map((method) {
                return DropdownMenuItem<CalculationMethod>(
                  value: method,
                  child: Text(
                    isBn ? method.shortNameBn : method.shortNameEn,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref
                      .read(prayerSettingsProvider.notifier)
                      .setCalculationMethod(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Azan Audio Selector & Prayer Call Settings ──
        _buildSettingsHeader(
          isBn ? 'নামাজের ওয়াক্তে আযান সুর' : 'Azan Audio & Tones',
          textPrimary,
          onInfoTap: () => _showSettingInfoSheet(
            context: context,
            title: isBn ? 'আযান সুর ও অডিও বিকল্প' : 'Azan Audio & Tones',
            description: isBn
                ? 'নামাজের ওয়াক্ত শুরু হলে যে আযান বা অডিও সুর শুনতে চান তা নির্বাচন করুন। আপনি চাইলে নীরব (সাইলেন্ট) মোডও বেছে নিতে পারেন:\n\n'
                  '• শায়খ মিশারি রশিদ আল-আফাসী: বিশ্ববিখ্যাত কুয়েতি ক্বারীর সুললিত পূর্ণাঙ্গ স্টুডিও কোয়ালিটি আযান (১৯২ কেবিপিএস)।\n\n'
                  '• মক্কা মুকাররমা আযান: কাবা শরীফের ঐতিহাসিক হৃদয়স্পর্শী সুউচ্চ আযান (১২৮ কেবিপিএস এইচডি)।\n\n'
                  '• মদীনা মুনাওয়ারা আযান: মসজিদে নববীর ভাবগাম্ভীর্যপূর্ণ সুমধুর আযান (১২৮ কেবিপিএস এইচডি)।\n\n'
                  '• আল-আকসা মসজিদ আযান: জেরুজালেমের পবিত্র মসজিদুল আকসার ঐতিহ্যবাহী সুরেলা আযান (১৯২ কেবিপিএস)।\n\n'
                  '• শায়খ মনসুর আল-যাহরানি: হৃদয় জুড়ানো শান্ত স্নিগ্ধ আযান (১৯২ কেবিপিএস)।\n\n'
                  '• সংক্ষিপ্ত তাকবীর: শুধুমাত্র "আল্লাহু আকবার" ধ্বনির সংক্ষিপ্ত মধুর সুর (১৯২ কেবিপিএস)।\n\n'
                  '• নীরব / কোনো অডিও নয়: নামাজের ওয়াক্তে কোনো অডিও বাজবে না।'
                : 'Select the Azan audio tone to play when prayer time enters, or select silent mode:\n\n'
                  '• Sheikh Mishary Alafasy: Iconic high-fidelity studio recording from the renowned Kuwaiti reciter (192 kbps).\n\n'
                  '• Makkah Al-Mukarramah: Majestic call to prayer from the Holy Ka\'bah (128 kbps HD Stereo).\n\n'
                  '• Madinah Al-Munawwarah: Reverent, melodious call to prayer from the Prophet\'s Mosque (128 kbps HD Stereo).\n\n'
                  '• Al-Aqsa Mosque: Historic Jerusalem call to prayer from the sacred sanctuary (192 kbps).\n\n'
                  '• Sheikh Mansoor Az-Zahrani: Soothing and peaceful vocalization (192 kbps).\n\n'
                  '• Short Takbeerat Chime: Subtle "Allahu Akbar" reminder (192 kbps).\n\n'
                  '• Silent / Mute: No audio will be played during prayer times.',
            guidance: isBn
                ? 'পরামর্শ: তালিকার যে কোনো সুরের উপর ট্যাপ করে তা নির্বাচন করুন, এবং পাশে "শুনুন" বোতাম চেপে উচ্চমানের অডিও পরখ করে নিন।'
                : 'Recommendation: Tap any tone to select it as your prayer call, and tap "Preview" to audition its studio sound quality.',
            icon: Icons.music_note_rounded,
            isDark: isDark,
            isBn: isBn,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                _buildAzanAudioTile(
                  key: 'mishary',
                  titleEn: 'Sheikh Mishary Rashid Alafasy',
                  titleBn: 'শায়খ মিশারি রশিদ আল-আফাসী',
                  subtitleEn: 'Studio High Fidelity • 192 kbps',
                  subtitleBn: 'স্টুডিও হাই-ফিডেলিটি • ১৯২ কেবিপিএস',
                  isDark: isDark,
                  isBn: isBn,
                  currentSound: settings.azanSound,
                ),
                const Divider(height: 1),
                _buildAzanAudioTile(
                  key: 'makkah',
                  titleEn: 'Makkah Al-Mukarramah Azan',
                  titleBn: 'মক্কা মুকাররমা আযান',
                  subtitleEn: 'Grand Mosque (Masjid al-Haram) • 128 kbps',
                  subtitleBn: 'মসজিদুল হারাম (কাবা শরীফ) • ১২৮ কেবিপিএস',
                  isDark: isDark,
                  isBn: isBn,
                  currentSound: settings.azanSound,
                ),
                const Divider(height: 1),
                _buildAzanAudioTile(
                  key: 'madinah',
                  titleEn: 'Madinah Al-Munawwarah Azan',
                  titleBn: 'মদীনা মুনাওয়ারা আযান',
                  subtitleEn: 'Prophet\'s Mosque (Al-Masjid an-Nabawi) • 128 kbps',
                  subtitleBn: 'মসজিদে নববী (মদীনা শরীফ) • ১২৮ কেবিপিএস',
                  isDark: isDark,
                  isBn: isBn,
                  currentSound: settings.azanSound,
                ),
                const Divider(height: 1),
                _buildAzanAudioTile(
                  key: 'alaqsa',
                  titleEn: 'Al-Aqsa Mosque Azan',
                  titleBn: 'আল-আকসা মসজিদ আযান',
                  subtitleEn: 'Sacred Sanctuary of Jerusalem • 192 kbps',
                  subtitleBn: 'পবিত্র বায়তুল মুকাদ্দাস • ১৯২ কেবিপিএস',
                  isDark: isDark,
                  isBn: isBn,
                  currentSound: settings.azanSound,
                ),
                const Divider(height: 1),
                _buildAzanAudioTile(
                  key: 'mansour',
                  titleEn: 'Sheikh Mansoor Az-Zahrani',
                  titleBn: 'শায়খ মনসুর আল-যাহরানি',
                  subtitleEn: 'Melodious vocalization • 192 kbps',
                  subtitleBn: 'সুমধুর শান্ত সুরেলা আযান • ১৯২ কেবিপিএস',
                  isDark: isDark,
                  isBn: isBn,
                  currentSound: settings.azanSound,
                ),
                const Divider(height: 1),
                _buildAzanAudioTile(
                  key: 'takbir',
                  titleEn: 'Short Takbeerat Chime',
                  titleBn: 'সংক্ষিপ্ত তাকবীর ধ্বনি',
                  subtitleEn: 'Gentle "Allahu Akbar" alert chime • 192 kbps',
                  subtitleBn: 'সংক্ষিপ্ত সুন্দর সুর (আল্লাহু আকবার)',
                  isDark: isDark,
                  isBn: isBn,
                  currentSound: settings.azanSound,
                ),
                const Divider(height: 1),
                _buildAzanAudioTile(
                  key: 'silent',
                  titleEn: 'Silent / No Audio (Mute)',
                  titleBn: 'নীরব / কোনো অডিও নয় (মিউট)',
                  subtitleEn: 'Do not play any sound at prayer times',
                  subtitleBn: 'নামাজের ওয়াক্তে কোনো অডিও বাজবে না',
                  isDark: isDark,
                  isBn: isBn,
                  currentSound: settings.azanSound,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Per-Prayer Audio Alerts ──
        _buildSettingsHeader(
          isBn ? 'ওয়াক্তভিত্তিক অডিও নোটিফিকেশন' : 'Prayer Audio Alerts',
          textPrimary,
          onInfoTap: () => _showSettingInfoSheet(
            context: context,
            title: isBn ? 'ওয়াক্তভিত্তিক অডিও অ্যালার্ট' : 'Per-Prayer Audio Alerts',
            description: isBn
                ? 'প্রতিটি নির্দিষ্ট ওয়াক্তে আযান বা অডিও অ্যালার্ট বাজবে কিনা তা এখান থেকে নির্ধারণ করতে পারেন।\n\n'
                  'উদাহরণস্বরূপ: আপনি চাইলে ফজরের সময় সাইলেন্ট রেখে অন্য ওয়াক্তগুলোতে আযান সক্রিয় রাখতে পারেন।'
                : 'Control whether the Azan audio tone plays for specific prayers.\n\n'
                  'For example: you can keep Fajr silent while keeping audio active for Dhuhr, Asr, Maghrib, and Isha.',
            guidance: isBn
                ? 'পরামর্শ: যে ওয়াক্তে আযান বাজাতে চান তা চালু রাখুন, বাকিগুলো বন্ধ করতে পারেন।'
                : 'Recommendation: Toggle individual prayers on or off based on your daily schedule and privacy needs.',
            icon: Icons.notifications_active_rounded,
            isDark: isDark,
            isBn: isBn,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              _buildPrayerAlertSwitch('Fajr', isBn ? 'ফজর' : 'Fajr', settings.prayerAlerts['Fajr'] ?? true, Icons.wb_twilight_rounded, isDark, isBn),
              const Divider(height: 1),
              _buildPrayerAlertSwitch('Dhuhr', isBn ? 'যোহর' : 'Dhuhr', settings.prayerAlerts['Dhuhr'] ?? true, Icons.wb_sunny_rounded, isDark, isBn),
              const Divider(height: 1),
              _buildPrayerAlertSwitch('Asr', isBn ? 'আসর' : 'Asr', settings.prayerAlerts['Asr'] ?? true, Icons.sunny_snowing, isDark, isBn),
              const Divider(height: 1),
              _buildPrayerAlertSwitch('Maghrib', isBn ? 'মাগরিব' : 'Maghrib', settings.prayerAlerts['Maghrib'] ?? true, Icons.nights_stay_rounded, isDark, isBn),
              const Divider(height: 1),
              _buildPrayerAlertSwitch('Isha', isBn ? 'ইশা' : 'Isha', settings.prayerAlerts['Isha'] ?? true, Icons.bedtime_rounded, isDark, isBn),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Manual Minute Adjustments (Mosque Sync) ──
        _buildSettingsHeader(
          isBn ? 'স্থানীয় মসজিদের সাথে সময় সমন্বয়' : 'Manual Minute Adjustments (+/- Minutes)',
          textPrimary,
          onInfoTap: () => _showSettingInfoSheet(
            context: context,
            title: isBn ? 'স্থানীয় মসজিদের সাথে সমন্বয়' : 'Manual Minute Adjustments',
            description: isBn
                ? 'জ্যোতির্বৈজ্ঞানিক হিসাবের পাশাপাশি আপনার মহল্লার নির্দিষ্ট মসজিদ বা ওয়াক্তসূচির সাথে মিল রাখার জন্য প্রতিটি ওয়াক্তে -৩০ থেকে +৩০ মিনিট পর্যন্ত যোগ বা বিয়োগ করতে পারেন।\n\n'
                  'উদাহরণস্বরূপ: অনেকেই মাগরিব বা ইফতারের সময়ে স্থানীয় সতর্কতামূলক ১-২ মিনিট বাড়িয়ে নেন, কিংবা ফজরের জামাতের জন্য মিনিট সমন্বয় করেন।'
                : 'Allows you to calibrate astronomical calculations to match your neighborhood mosque\'s exact printed timetable.\n\n'
                  'You can adjust any individual prayer from -30 to +30 minutes (e.g. adding 2-3 minutes safety buffer for Maghrib/Iftar, or aligning with local horizon obstructions).',
            guidance: isBn
                ? 'পরামর্শ: কোনো ওয়াক্তে সময় কিছুটা গরমিল মনে হলে "+" বা "-" বোতাম চেপে স্থানীয় মসজিদের সাথে মিলিয়ে নিন।'
                : 'Recommendation: Use "+" or "-" to sync with your local Jama\'at schedule if a discrepancy exists with your local calendar.',
            icon: Icons.tune_rounded,
            isDark: isDark,
            isBn: isBn,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? NekiColors.nightElevated.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              _buildOffsetRow(isBn ? 'ফজর' : 'Fajr', settings.fajrOffset, (val) {
                ref.read(prayerSettingsProvider.notifier).setOffset(fajr: val);
              }, textPrimary),
              _buildOffsetRow(isBn ? 'যোহর' : 'Dhuhr', settings.dhuhrOffset, (val) {
                ref.read(prayerSettingsProvider.notifier).setOffset(dhuhr: val);
              }, textPrimary),
              _buildOffsetRow(isBn ? 'আসর' : 'Asr', settings.asrOffset, (val) {
                ref.read(prayerSettingsProvider.notifier).setOffset(asr: val);
              }, textPrimary),
              _buildOffsetRow(isBn ? 'মাগরিব' : 'Maghrib', settings.maghribOffset, (val) {
                ref.read(prayerSettingsProvider.notifier).setOffset(maghrib: val);
              }, textPrimary),
              _buildOffsetRow(isBn ? 'ইশা' : 'Isha', settings.ishaOffset, (val) {
                ref.read(prayerSettingsProvider.notifier).setOffset(isha: val);
              }, textPrimary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsHeader(
    String title,
    Color textPrimary, {
    VoidCallback? onInfoTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
          if (onInfoTap != null)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              color: NekiColors.emeraldPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 18,
              onPressed: onInfoTap,
              tooltip: 'Learn more',
            ),
        ],
      ),
    );
  }

  void _showSettingInfoSheet({
    required BuildContext context,
    required String title,
    required String description,
    required String guidance,
    required IconData icon,
    required bool isDark,
    required bool isBn,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = isDark ? NekiColors.nightSurface : Colors.white;
        final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
        final textSecondary = isDark
            ? NekiColors.textSecondaryOnDark
            : NekiColors.textSecondaryOnLight;

        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: NekiColors.emeraldPrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NekiColors.emeraldPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: NekiColors.emeraldPrimary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: NekiColors.emeraldPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            guidance,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: isDark ? NekiColors.emeraldLight : const Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NekiColors.emeraldPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        isBn ? 'বুঝেছি' : 'Got it',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAzanAudioTile({
    required String key,
    required String titleEn,
    required String titleBn,
    required String subtitleEn,
    required String subtitleBn,
    required bool isDark,
    required bool isBn,
    required String currentSound,
  }) {
    final isSelected = currentSound == key;
    final azanState = ref.watch(azanPlayerProvider);
    final isPlaying = azanState.isPlaying && azanState.activeSoundKey == key;
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;
    final isSilent = key == 'silent';

    return InkWell(
      onTap: () {
        ref.read(prayerSettingsProvider.notifier).setAzanSound(key);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            // Radio indicator
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? NekiColors.emeraldPrimary : textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            // Title & Subtitle & Selected pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isBn ? titleBn : titleEn,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? (isDark ? NekiColors.emeraldLight : NekiColors.emeraldPrimary)
                                : textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NekiColors.emeraldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isBn ? 'নির্বাচিত' : 'SELECTED',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: NekiColors.emeraldPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBn ? subtitleBn : subtitleEn,
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Preview button or Silent Icon
            if (isSilent)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.volume_off_rounded,
                  color: isSelected ? Colors.redAccent : textSecondary,
                  size: 22,
                ),
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    ref.read(azanPlayerProvider.notifier).playSound(key);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? Colors.redAccent.withValues(alpha: 0.12)
                          : NekiColors.emeraldPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPlaying
                            ? Colors.redAccent.withValues(alpha: 0.4)
                            : NekiColors.emeraldPrimary.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPlaying
                              ? Icons.stop_circle_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 16,
                          color: isPlaying ? Colors.redAccent : NekiColors.emeraldPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPlaying
                              ? (isBn ? 'থামান' : 'Stop')
                              : (isBn ? 'শুনুন' : 'Preview'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPlaying ? Colors.redAccent : NekiColors.emeraldPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerAlertSwitch(
    String prayerKey,
    String label,
    bool isEnabled,
    IconData icon,
    bool isDark,
    bool isBn,
  ) {
    final textPrimary = isDark ? Colors.white : NekiColors.textOnLight;
    final textSecondary =
        isDark ? NekiColors.textSecondaryOnDark : NekiColors.textSecondaryOnLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isEnabled ? NekiColors.emeraldPrimary : textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  isEnabled
                      ? (isBn ? 'অডিও চালু আছে' : 'Audio Alert On')
                      : (isBn ? 'নীরব (মিউট)' : 'Silent / Muted'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isEnabled ? NekiColors.emeraldPrimary : textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            activeTrackColor: NekiColors.emeraldPrimary,
            onChanged: (_) {
              ref.read(prayerSettingsProvider.notifier).toggleAlert(prayerKey);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOffsetRow(
      String label, int value, ValueChanged<int> onChanged, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                onPressed: () => onChanged(value - 1),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  value >= 0 ? '+$value' : '$value',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: value != 0 ? NekiColors.emeraldPrimary : textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Table Cell Subcomponents for Monthly Calendar
// ─────────────────────────────────────────────────────────

class _TableColHeader extends StatelessWidget {
  final String label;
  const _TableColHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: NekiColors.emeraldPrimary,
        ),
      ),
    );
  }
}

class _TableTimeCell extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool isToday;

  const _TableTimeCell(this.text,
      {required this.isDark, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
          color: isToday
              ? NekiColors.emeraldPrimary
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }
}
