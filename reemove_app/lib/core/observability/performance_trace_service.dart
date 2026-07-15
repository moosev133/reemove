import 'performance_trace_firebase.dart';

abstract interface class PerformanceTraceService {
  Future<T> trace<T>(
    String name,
    Future<T> Function() action, {
    Map<String, String> attributes,
    Map<String, int> metrics,
  });
}

final class NoopPerformanceTraceService implements PerformanceTraceService {
  const NoopPerformanceTraceService();

  @override
  Future<T> trace<T>(
    String name,
    Future<T> Function() action, {
    Map<String, String> attributes = const <String, String>{},
    Map<String, int> metrics = const <String, int>{},
  }) => action();
}

PerformanceTraceService createPerformanceTraceService({
  required bool firebaseReady,
  required bool isWeb,
}) {
  if (!firebaseReady || isWeb) {
    return const NoopPerformanceTraceService();
  }
  return createFirebasePerformanceTraceService();
}
