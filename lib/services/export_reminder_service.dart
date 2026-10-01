import 'package:inventory_plus/services/debug_clock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'export_period.dart';

/// Tracks whether a period's report has been exported, and tells the UI
/// which periods are "due" for a reminder. One Supabase table (`export_log`)
/// backs both the Sales report and the Inventory report — `reportType`
/// keeps them separate.
class ExportReminderService {
  final SupabaseClient supabase;
  final String? locationId;

  ExportReminderService({required this.supabase, required this.locationId});

  /// Local hour (24h) after which a period is considered "due" to remind
  /// about. Change this in one place to affect every report type.
  static const int reminderHour = 17; // 5:00 PM

  Future<void> logExport({
    required String reportType, // 'sales' | 'inventory'
    required ExportPeriod period,
    int? exportedBy,
  }) async {
    final locId = locationId;
    if (locId == null) return;
    await supabase.from('export_log').upsert({
      'location_id': locId,
      'report_type': reportType,
      'period_type': period.type.name,
      'period_key': period.key,
      'exported_by': exportedBy,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'location_id,report_type,period_type,period_key');
  }

  /// Returns which period types (daily/weekly/monthly) are due right now
  /// for [reportType] and haven't been exported yet. Issues exactly ONE
  /// query — cheap enough for a free-tier deployment even called on every
  /// page visit.
  Future<List<ExportPeriodType>> dueReminders(String reportType) async {
    final locId = locationId;
    if (locId == null) return [];

    final now = DebugClock.now();
    if (now.hour < reminderHour) return []; // too early to nag

    // Only consider a period "checkable" once it's actually ending.
    final candidates = <ExportPeriodType, ExportPeriod>{};
    for (final type in ExportPeriodType.values) {
      final period = ExportPeriod.current(type, now: now);
      if (type != ExportPeriodType.daily && !period.isFinalDay) continue;
      candidates[type] = period;
    }
    if (candidates.isEmpty) return [];

    final keys = candidates.values.map((p) => p.key).toList();
    final rows = await supabase
        .from('export_log')
        .select('period_type, period_key')
        .eq('location_id', locId)
        .eq('report_type', reportType)
        .inFilter('period_key', keys);

    final exported = List<Map<String, dynamic>>.from(
      rows,
    ).map((r) => '${r['period_type']}_${r['period_key']}').toSet();

    return candidates.entries
        .where((e) => !exported.contains('${e.key.name}_${e.value.key}'))
        .map((e) => e.key)
        .toList();
  }

  Future<void> clearExportLog({String? reportType}) async {
    final locId = locationId;
    if (locId == null) return;
    var query = supabase.from('export_log').delete().eq('location_id', locId);
    if (reportType != null) query = query.eq('report_type', reportType);
    await query;
  }
}

