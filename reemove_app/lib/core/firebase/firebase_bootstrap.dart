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

import '../config/app_environment.dart';
import '../logging/app_logger.dart';

@pragma('vm:entry-point')
Future<void> reemoveFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

enum FirebaseBootstrapStatus { ready, unavailable }

class FirebaseBootstrapReport {
  const FirebaseBootstrapReport({
    required this.status,
    required this.appCheckEnabled,
    required this.emulatorsEnabled,
    this.details,
  });

  final FirebaseBootstrapStatus status;
  final bool appCheckEnabled;
  final bool emulatorsEnabled;
  final String? details;

  bool get isReady => status == FirebaseBootstrapStatus.ready;
}

abstract final class FirebaseBootstrap {
  static Future<FirebaseBootstrapReport> initialize({
    required AppEnvironment environment,
    required AppLogger logger,
  }) async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        reemoveFirebaseMessagingBackgroundHandler,
      );

      if (environment.useFirebaseEmulators) {
        await _connectEmulators(environment, logger);
      }

      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
        environment.enableAnalytics && !environment.useFirebaseEmulators,
      );

      bool appCheckEnabled = false;
      if (environment.enableAppCheck) {
        if (kIsWeb && environment.webRecaptchaV3SiteKey == null) {
          throw StateError(
            'FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY is required when App Check '
            'is enabled for web.',
          );
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
        appCheckEnabled = true;
      }

      logger.info('Firebase initialized successfully.');
      return FirebaseBootstrapReport(
        status: FirebaseBootstrapStatus.ready,
        appCheckEnabled: appCheckEnabled,
        emulatorsEnabled: environment.useFirebaseEmulators,
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
    FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
    logger.info('Connected Firebase SDKs to local emulators at $host.');
  }
}
