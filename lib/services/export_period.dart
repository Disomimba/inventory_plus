import 'package:inventory_plus/services/debug_clock.dart';

/// Calendar-aligned reporting periods, shared by every export feature.
///
/// Rules:
/// - Daily   = one calendar day (midnight to midnight), not a rolling 24h window.
/// - Weekly  = a week block inside the current month (days 1-7, 8-14, 15-21,
///             22-28, 29-end), not a rolling 7-day window.
/// - Monthly = one calendar month, not a rolling 30-day window.
enum ExportPeriodType { daily, weekly, monthly }

extension ExportPeriodTypeLabel on ExportPeriodType {
  String get label {
    switch (this) {
      case ExportPeriodType.daily:
        return 'Daily';
      case ExportPeriodType.weekly:
        return 'Weekly';
      case ExportPeriodType.monthly:
        return 'Monthly';
    }
  }
}

class ExportPeriod {
  final ExportPeriodType type;
  final DateTime start; // inclusive, local midnight
  final DateTime endExclusive; // first moment NOT included
  final String key; // stable id, e.g. '2026-09-30', '2026-09-W4', '2026-09'

  const ExportPeriod({
    required this.type,
    required this.start,
    required this.endExclusive,
    required this.key,
  });

  String get label => type.label;

  /// Last real moment inside the period — use this for display, never [endExclusive].
  DateTime get displayEnd => endExclusive.subtract(const Duration(seconds: 1));

  bool contains(DateTime dt) =>
      !dt.isBefore(start) && dt.isBefore(endExclusive);

  /// True once "today" is the last calendar day of this period.
  /// Always true for Daily, since a daily period IS today.
  bool get isFinalDay {
    final now = DebugClock.now();
    final last = displayEnd;
    return now.year == last.year &&
        now.month == last.month &&
        now.day == last.day;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static ExportPeriod current(ExportPeriodType type, {DateTime? now}) {
    final n = now ?? DebugClock.now();
    switch (type) {
      case ExportPeriodType.daily:
        final start = DateTime(n.year, n.month, n.day);
        return ExportPeriod(
          type: type,
          start: start,
          endExclusive: start.add(const Duration(days: 1)),
          key: '${n.year}-${_two(n.month)}-${_two(n.day)}',
        );

      case ExportPeriodType.weekly:
        // ISO week: Monday-Sunday. Can span across two months.
        final start = DateTime(
          n.year,
          n.month,
          n.day,
        ).subtract(Duration(days: n.weekday - 1)); // n.weekday: Mon=1..Sun=7
        final end = start.add(const Duration(days: 7));

        // ISO week-year and week number (the Thursday of the week decides both,
        final thursday = start.add(const Duration(days: 3));
        final isoYear = thursday.year;
        final jan4 = DateTime(isoYear, 1, 4);
        final firstThursday = jan4.subtract(Duration(days: jan4.weekday - 1));
        final isoWeek =
            ((thursday.difference(firstThursday).inDays) / 7).floor() + 1;

        return ExportPeriod(
          type: type,
          start: start,
          endExclusive: end,
          key: '$isoYear-W${isoWeek.toString().padLeft(2, '0')}',
        );

      case ExportPeriodType.monthly:
        final start = DateTime(n.year, n.month, 1);
        return ExportPeriod(
          type: type,
          start: start,
          endExclusive: DateTime(n.year, n.month + 1, 1),
          key: '${n.year}-${_two(n.month)}',
        );
    }
  }
}
