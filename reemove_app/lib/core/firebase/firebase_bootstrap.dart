import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options_production.dart';
import '../../firebase_options_staging.dart';
import '../config/app_environment.dart';
import '../logging/app_logger.dart';

@pragma('vm:entry-point')
Future<void> reemoveFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (Firebase.apps.isEmpty) {
    await FirebaseBootstrap.initializeFirebaseApp(
      AppEnvironment.fromCompileTime(),
    );
  }
}

enum FirebaseBootstrapStatus { ready, unavailable }

class FirebaseBootstrapReport {
  const FirebaseBootstrapReport({
    required this.status,
    required this.appCheckEnabled,
    required this.emulatorsEnabled,
    this.details,
    this.projectId,
  });

  final FirebaseBootstrapStatus status;
  final bool appCheckEnabled;
  final bool emulatorsEnabled;
  final String? details;
  final String? projectId;

  bool get isReady => status == FirebaseBootstrapStatus.ready;
}

abstract final class FirebaseBootstrap {
  /// Resolves flavor-specific [FirebaseOptions].
  ///
  /// Staging uses [StagingFirebaseOptions]. Production uses
  /// [ProductionFirebaseOptions]. Development keeps the prior bare
  /// [Firebase.initializeApp] path (native files, emulators, or unavailable).
  static FirebaseOptions? optionsFor(AppEnvironment environment) {
    if (environment.isStaging) {
      return StagingFirebaseOptions.currentPlatform;
    }
    if (environment.isProduction) {
      return ProductionFirebaseOptions.currentPlatform;
    }
    return null;
  }

  static Future<FirebaseApp> initializeFirebaseApp(
    AppEnvironment environment,
  ) async {
    final FirebaseOptions? options = optionsFor(environment);
    if (options != null) {
      return Firebase.initializeApp(options: options);
    }
    return Firebase.initializeApp();
  }

  static Future<FirebaseBootstrapReport> initialize({
    required AppEnvironment environment,
    required AppLogger logger,
  }) async {
    try {
      final FirebaseApp app = await initializeFirebaseApp(environment);
      FirebaseMessaging.onBackgroundMessage(
        reemoveFirebaseMessagingBackgroundHandler,
      );

      if (environment.useFirebaseEmulators) {
        await _connectEmulators(environment, logger);
      }

      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        environment.enableAnalytics && !environment.useFirebaseEmulators,
      );

      final bool appCheckEnabled = await _activateAppCheck(
        environment: environment,
        logger: logger,
      );

      logger.info(
        'Firebase initialized successfully '
        '(flavor=${environment.flavor.name}, projectId=${app.options.projectId}).',
      );
      return FirebaseBootstrapReport(
        status: FirebaseBootstrapStatus.ready,
        appCheckEnabled: appCheckEnabled,
        emulatorsEnabled: environment.useFirebaseEmulators,
        projectId: app.options.projectId,
      );
    } on Object catch (error, stackTrace) {
      logger.warning(
        'Firebase is not configured for this build yet.',
        error: error,
        stackTrace: stackTrace,
      );
      return FirebaseBootstrapReport(
        status: FirebaseBootstrapStatus.unavailable,
        appCheckEnabled: false,
        emulatorsEnabled: false,
        details: error.toString(),
      );
    }
  }

  static Future<bool> _activateAppCheck({
    required AppEnvironment environment,
    required AppLogger logger,
  }) async {
    if (!environment.enableAppCheck) {
      return false;
    }
    try {
      if (kIsWeb && environment.webRecaptchaV3SiteKey == null) {
        logger.warning(
          'App Check skipped on web: FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY is missing.',
        );
        return false;
      }

      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        providerWeb: environment.webRecaptchaV3SiteKey == null
            ? null
            : ReCaptchaV3Provider(environment.webRecaptchaV3SiteKey!),
      );
      return true;
    } on Object catch (error, stackTrace) {
      logger.warning(
        'App Check failed to activate; continuing without it.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static Future<void> _connectEmulators(
    AppEnvironment environment,
    AppLogger logger,
  ) async {
    final String host = environment.firebaseEmulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8180);
    FirebaseFunctions.instanceFor(
      region: environment.firebaseFunctionsRegion,
    ).useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    // Must match [FirebaseSdk.databaseFor] so emulator binding and runtime share
    // the same Realtime Database instance.
    final String? databaseUrl = environment.firebaseDatabaseUrl;
    final FirebaseDatabase database =
        databaseUrl == null || environment.useFirebaseEmulators
        ? FirebaseDatabase.instance
        : FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: databaseUrl,
          );
    database.useDatabaseEmulator(host, 9000);
    logger.info('Connected Firebase SDKs to local emulators at $host.');
  }
}
