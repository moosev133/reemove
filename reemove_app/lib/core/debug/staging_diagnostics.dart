import 'package:flutter/foundation.dart';

/// Temporary staging-only diagnostics to trace permission propagation bugs.
///
/// Enable by building with `--dart-define=APP_FLAVOR=staging`.
class StagingDiagnostics {
  static bool get enabled => const String.fromEnvironment('APP_FLAVOR') == 'staging';

  static void log(
    String tag,
    Map<String, Object?> data,
  ) {
    if (!enabled) return;
    final String payload = data.entries
        .map((MapEntry<String, Object?> e) => '${e.key}=${e.value}')
        .join(', ');
    debugPrint('[STAGING_DIAG][$tag] $payload');
  }
}


