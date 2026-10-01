import 'package:flutter/foundation.dart';

/// Lets you fake "now" during development to test date-sensitive logic
/// (export periods, reminders) without waiting for real time to pass.
///
/// Only works in debug/profile builds — in release builds [now] always
/// returns the real current time, so this can never ship as a backdoor.
class DebugClock {
  DebugClock._();

  static DateTime? _override;

  /// The time the rest of the app should treat as "now".
  static DateTime now() {
    if (kReleaseMode) return DateTime.now();
    return _override ?? DateTime.now();
  }

  /// Call with a specific DateTime to freeze "now" at that moment.
  /// Call with null to go back to the real clock.
  static void set(DateTime? fakeNow) {
    if (kReleaseMode) return; // no-op in release, just in case
    _override = fakeNow;
  }

  static bool get isOverridden => !kReleaseMode && _override != null;
}
