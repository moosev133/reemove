import 'package:flutter/foundation.dart';

import 'crash_reporting_firebase.dart';

abstract interface class CrashReportingService {
  Future<void> record(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal,
  });

  Future<void> breadcrumb(String message);
}

final class DebugCrashReportingService implements CrashReportingService {
  const DebugCrashReportingService();

  @override
  Future<void> breadcrumb(String message) async {
    debugPrint('[breadcrumb] $message');
  }

  @override
  Future<void> record(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    debugPrint('[$reason] $error\n$stackTrace');
  }
}

/// Creates the best available crash reporter for the current platform.
CrashReportingService createCrashReportingService({
  required bool firebaseReady,
}) {
  if (!firebaseReady || kIsWeb) {
    return const DebugCrashReportingService();
  }
  return createFirebaseCrashReportingService();
}
