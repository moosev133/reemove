import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../firebase/firebase_bootstrap.dart';
import '../logging/app_logger.dart';

final Provider<AppEnvironment> appEnvironmentProvider =
    Provider<AppEnvironment>((Ref ref) {
      throw StateError(
        'appEnvironmentProvider must be overridden at bootstrap.',
      );
    });

final Provider<AppLogger> appLoggerProvider = Provider<AppLogger>((Ref ref) {
  throw StateError('appLoggerProvider must be overridden at bootstrap.');
});

final Provider<FirebaseBootstrapReport> firebaseBootstrapReportProvider =
    Provider<FirebaseBootstrapReport>((Ref ref) {
      throw StateError(
        'firebaseBootstrapReportProvider must be overridden at bootstrap.',
      );
    });
