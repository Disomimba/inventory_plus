// Save as: lib/ui/reports/report_range.dart
import '../../services/export_period.dart';
import 'report_period_text.dart';

/// A concrete report window (e.g. "the week of Sep 21") plus the rules for
/// how far back each report type may go.
///
///   Daily   -> today + previous 7 days
///   Weekly  -> this week + previous 2 weeks (Mon-Sun)
///   Monthly -> this month + previous month
class ReportRange {
  final String period; // 'Daily' | 'Weekly' | 'Monthly'
  final int offset; // 0 = current, 1 = one period back, ...
  final DateTime start; // inclusive, midnight
  final DateTime endExclusive; // midnight after the last day

  const ReportRange._(this.period, this.offset, this.start, this.endExclusive);

  static const periods = ['Daily', 'Weekly', 'Monthly'];
  static const _maxBack = {'Daily': 7, 'Weekly': 2, 'Monthly': 1};

  static int maxBack(String period) => _maxBack[period] ?? 0;

  factory ReportRange.of(String period, int offset, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final limit = maxBack(period);
    final o = offset < 0 ? 0 : (offset > limit ? limit : offset);

    if (period == 'Daily') {
      return ReportRange._(
        period,
        o,
        DateTime(n.year, n.month, n.day - o),
        DateTime(n.year, n.month, n.day - o + 1),
      );
    }
    if (period == 'Weekly') {
      final monday = n.day - (n.weekday - 1);
      final start = DateTime(n.year, n.month, monday - 7 * o);
      return ReportRange._(
        period,
        o,
        start,
        DateTime(start.year, start.month, start.day + 7),
      );
    }
    if (period == 'Monthly') {
      return ReportRange._(
        period,
        o,
        DateTime(n.year, n.month - o, 1),
        DateTime(n.year, n.month - o + 1, 1),
      );
    }
    throw ArgumentError('Unknown report period: $period');
  }

  /// Every selectable range for a period type, newest first.
  static List<ReportRange> options(String period, {DateTime? now}) => [
    for (var i = 0; i <= maxBack(period); i++)
      ReportRange.of(period, i, now: now),
  ];

  static String limitText(String period) {
    switch (period) {
      case 'Daily':
        return 'Daily reports can go back up to 7 days.';
      case 'Weekly':
        return 'Weekly reports can go back up to 2 weeks.';
      default:
        return 'Monthly reports can go back to the previous month only.';
    }
  }

  bool get isCurrent => offset == 0;

  /// Last day covered by the period (midnight) - for display in the PDF.
  DateTime get displayEnd =>
      DateTime(endExclusive.year, endExclusive.month, endExclusive.day - 1);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(endExclusive);

  ExportPeriodType get type {
    if (period == 'Daily') return ExportPeriodType.daily;
    if (period == 'Weekly') return ExportPeriodType.weekly;
    return ExportPeriodType.monthly;
  }

  /// yyyy-mm-dd of the period start, for unique file names.
  String get fileTag =>
      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';

  /// Text shown in the dropdown, e.g. "Last week  (Sep 21, 2026 - Sep 27, 2026)".
  String get optionLabel {
    final text = ReportPeriodText.label(period, start, displayEnd);
    String? lead;
    if (period == 'Daily') {
      lead = offset == 0 ? 'Today' : (offset == 1 ? 'Yesterday' : null);
    } else if (period == 'Weekly') {
      lead = offset == 0
          ? 'This week'
          : (offset == 1 ? 'Last week' : '$offset weeks ago');
    } else {
      lead = offset == 0 ? 'This month' : 'Last month';
    }
    return lead == null ? text : '$lead  ($text)';
  }
}
