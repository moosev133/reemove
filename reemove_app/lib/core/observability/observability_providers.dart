import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_bootstrap.dart';
import '../providers/core_providers.dart';
import 'crash_reporting_service.dart';
import 'performance_trace_service.dart';

/// Crash reporting with graceful fallback when Firebase is unavailable or
/// when the platform cannot host Crashlytics (e.g. Flutter web).
final Provider<CrashReportingService> crashReportingServiceProvider =
    Provider<CrashReportingService>((Ref ref) {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      return createCrashReportingService(firebaseReady: report.isReady);
    });

/// Performance tracing with a no-op fallback for web / Firebase-unavailable.
final Provider<PerformanceTraceService> performanceTraceServiceProvider =
    Provider<PerformanceTraceService>((Ref ref) {
      final FirebaseBootstrapReport report = ref.watch(
        firebaseBootstrapReportProvider,
      );
      return createPerformanceTraceService(
        firebaseReady: report.isReady,
        isWeb: kIsWeb,
      );
    });
