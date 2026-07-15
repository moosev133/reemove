import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/reemove_app.dart';
import 'core/config/app_environment.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/logging/app_logger.dart';
import 'core/observability/crash_reporting_service.dart';
import 'core/providers/core_providers.dart';

Future<void> bootstrap(AppEnvironment environment) async {
  final AppLogger logger = AppLogger(environment: environment);
  CrashReportingService crashReporting = const DebugCrashReportingService();

  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        logger.error(
          'Flutter framework error',
          error: details.exception,
          stackTrace: details.stack,
        );
        unawaited(
          crashReporting.record(
            details.exception,
            details.stack ?? StackTrace.current,
            reason: 'flutter_framework_error',
            fatal: false,
          ),
        );
      };

      PlatformDispatcher.instance.onError =
          (Object error, StackTrace stackTrace) {
            logger.error(
              'Unhandled platform error',
              error: error,
              stackTrace: stackTrace,
            );
            unawaited(
              crashReporting.record(
                error,
                stackTrace,
                reason: 'platform_error',
                fatal: true,
              ),
            );
            return true;
          };

      final FirebaseBootstrapReport firebaseReport =
          await FirebaseBootstrap.initialize(
            environment: environment,
            logger: logger,
          );
      crashReporting = createCrashReportingService(
        firebaseReady: firebaseReport.isReady,
      );

      runApp(
        ProviderScope(
          overrides: [
            appEnvironmentProvider.overrideWithValue(environment),
            appLoggerProvider.overrideWithValue(logger),
            firebaseBootstrapReportProvider.overrideWithValue(firebaseReport),
          ],
          child: const ReeMoveApp(),
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      logger.error(
        'Unhandled bootstrap zone error',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(
        crashReporting.record(
          error,
          stackTrace,
          reason: 'bootstrap_zone_error',
          fatal: true,
        ),
      );
    },
  );
}
