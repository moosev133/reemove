import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import '../logging/app_logger.dart';

enum FirebaseBootstrapStatus { ready, unavailable }

class FirebaseBootstrapReport {
  const FirebaseBootstrapReport({
    required this.status,
    required this.appCheckEnabled,
    this.details,
  });

  final FirebaseBootstrapStatus status;
  final bool appCheckEnabled;
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
        details: error.toString(),
      );
    }
  }
}
