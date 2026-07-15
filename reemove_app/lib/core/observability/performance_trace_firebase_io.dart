import 'package:firebase_performance/firebase_performance.dart';

import 'performance_trace_service.dart';

PerformanceTraceService createFirebasePerformanceTraceService() =>
    FirebasePerformanceTraceService();

final class FirebasePerformanceTraceService implements PerformanceTraceService {
  FirebasePerformanceTraceService({FirebasePerformance? performance})
    : _performance = performance ?? FirebasePerformance.instance;

  final FirebasePerformance _performance;

  @override
  Future<T> trace<T>(
    String name,
    Future<T> Function() action, {
    Map<String, String> attributes = const <String, String>{},
    Map<String, int> metrics = const <String, int>{},
  }) async {
    _validateTraceName(name);
    final Trace trace = _performance.newTrace(name);
    for (final MapEntry<String, String> entry in attributes.entries) {
      if (_isSafeAttribute(entry.key, entry.value)) {
        trace.putAttribute(entry.key, entry.value);
      }
    }
    for (final MapEntry<String, int> entry in metrics.entries) {
      trace.setMetric(entry.key, entry.value);
    }

    await trace.start();
    try {
      final T result = await action();
      trace.putAttribute('outcome', 'success');
      return result;
    } catch (_) {
      trace.putAttribute('outcome', 'error');
      rethrow;
    } finally {
      await trace.stop();
    }
  }

  void _validateTraceName(String name) {
    final bool valid = RegExp(r'^[a-z][a-z0-9_]{2,79}$').hasMatch(name);
    if (!valid) {
      throw ArgumentError.value(name, 'name', 'Invalid performance trace name');
    }
  }

  bool _isSafeAttribute(String key, String value) {
    const Set<String> forbiddenKeys = <String>{
      'email',
      'username',
      'message',
      'prompt',
      'latitude',
      'longitude',
      'token',
      'phone',
    };
    return !forbiddenKeys.contains(key.toLowerCase()) &&
        key.length <= 40 &&
        value.length <= 100;
  }
}
