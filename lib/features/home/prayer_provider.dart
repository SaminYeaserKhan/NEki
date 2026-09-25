import 'package:flutter_riverpod/flutter_riverpod.dart';

// Re-export new prayer schedule engine and models
export '../namaz/providers/prayer_schedule_provider.dart'
    show WaqtData, liveWaqtProvider, todayScheduleProvider, monthlyScheduleProvider;

// ─────────────────────────────────────────────────────────
//  12 / 24-hour toggle (persisted via Riverpod)
// ─────────────────────────────────────────────────────────

class Is24HourNotifier extends Notifier<bool> {
  @override
  bool build() => false; // default: 12-hour format

  void toggle() => state = !state;
}

final is24HourProvider =
    NotifierProvider<Is24HourNotifier, bool>(Is24HourNotifier.new);