import 'package:flutter/foundation.dart';

/// Compile-time switches shared by integration and emulator-backed tests.
final class TestEnvironment {
  const TestEnvironment._();

  static const bool useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );

  static const String emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  /// Defaults to the production emulator project id (`demo-reemove`).
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'demo-reemove',
  );

  static const bool isIntegrationTest = bool.fromEnvironment(
    'INTEGRATION_TEST',
    defaultValue: false,
  );

  static void assertNotProduction() {
    const Set<String> forbidden = <String>{
      'reemove-prod',
      'reemove-production',
    };
    if (useEmulators && forbidden.contains(projectId.toLowerCase())) {
      throw StateError(
        'Refusing to run emulator tests with a production project ID.',
      );
    }
    if (kReleaseMode && useEmulators) {
      throw StateError(
        'Release builds must not connect to Firebase emulators.',
      );
    }
  }
}
