import 'package:flutter/foundation.dart';

/// Temporary staging/debug trace for profile deep-link investigations.
abstract final class RouterDiagnosticLog {
  static const int _maxEntries = 200;
  static final List<String> entries = <String>[];

  static void record(String message) {
    if (!kDebugMode) {
      return;
    }
    final String line =
        '${DateTime.now().toIso8601String()} $message';
    entries.add(line);
    if (entries.length > _maxEntries) {
      entries.removeAt(0);
    }
    debugPrint('[router-diag] $message');
  }

  static void clear() => entries.clear();
}
