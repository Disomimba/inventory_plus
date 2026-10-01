// Save as: lib/ui/reports/report_period_text.dart
// Shared by SalesReportGenerator and InventoryReportGenerator so both
// reports always word the period the same way.

class ReportPeriodText {
  ReportPeriodText._();

  static const _full = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _short = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _date(DateTime d) =>
      '${_short[d.month - 1]} ${d.day}, ${d.year}';

  /// Monthly -> "October 2026"
  /// Weekly  -> "Sep 28, 2026 - Oct 4, 2026"   (full period, even if unfinished)
  /// Daily   -> "Oct 1, 2026"
  static String label(String period, DateTime start, DateTime end) {
    if (period == 'Monthly') return '${_full[start.month - 1]} ${start.year}';
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    return sameDay ? _date(start) : '${_date(start)} - ${_date(end)}';
  }

  /// Returns a "Data as of ..." note while the period is still in progress,
  /// or null once the period has ended (nothing to explain).
  static String? asOf(DateTime generatedAt, DateTime periodEnd) {
    final endOfPeriod = DateTime(
      periodEnd.year,
      periodEnd.month,
      periodEnd.day,
      23,
      59,
      59,
    );
    if (!generatedAt.isBefore(endOfPeriod)) return null;

    final h = generatedAt.hour % 12 == 0 ? 12 : generatedAt.hour % 12;
    final m = generatedAt.minute.toString().padLeft(2, '0');
    final ap = generatedAt.hour >= 12 ? 'PM' : 'AM';
    return 'Data as of ${_date(generatedAt)}, $h:$m $ap';
  }
}
