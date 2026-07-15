import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/observability/crash_reporting_service.dart';
import 'package:reemove/core/observability/performance_trace_service.dart';
import 'package:reemove/core/testing/test_environment.dart';

void main() {
  test('createCrashReportingService falls back when Firebase is not ready', () {
    final CrashReportingService service = createCrashReportingService(
      firebaseReady: false,
    );
    expect(service, isA<DebugCrashReportingService>());
  });

  test('createPerformanceTraceService falls back on web-style path', () {
    final PerformanceTraceService service = createPerformanceTraceService(
      firebaseReady: false,
      isWeb: true,
    );
    expect(service, isA<NoopPerformanceTraceService>());
  });

  test('TestEnvironment defaults to the demo emulator project', () {
    expect(TestEnvironment.projectId, 'demo-reemove');
    expect(TestEnvironment.emulatorHost, '127.0.0.1');
  });
}
