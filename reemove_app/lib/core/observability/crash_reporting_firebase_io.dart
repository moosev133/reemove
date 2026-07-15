import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'crash_reporting_service.dart';

CrashReportingService createFirebaseCrashReportingService() =>
    FirebaseCrashReportingService();

final class FirebaseCrashReportingService implements CrashReportingService {
  FirebaseCrashReportingService({FirebaseCrashlytics? crashlytics})
    : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> record(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    return _crashlytics.recordError(
      error,
      stackTrace,
      reason: _redact(reason),
      fatal: fatal,
    );
  }

  @override
  Future<void> breadcrumb(String message) =>
      _crashlytics.log(_redact(message) ?? 'event');

  String? _redact(String? value) {
    if (value == null) {
      return null;
    }
    var output = value;
    output = output.replaceAll(
      RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
      '[email]',
    );
    output = output.replaceAll(
      RegExp(
        r'\b(?:token|secret|password|authorization)\s*[:=]\s*\S+',
        caseSensitive: false,
      ),
      '[redacted]',
    );
    return output.length <= 500 ? output : '${output.substring(0, 500)}…';
  }
}
