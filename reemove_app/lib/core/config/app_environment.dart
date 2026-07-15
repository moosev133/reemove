enum AppFlavor {
  development,
  staging,
  production;

  static AppFlavor parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'development' || 'dev' => AppFlavor.development,
      'staging' || 'stage' => AppFlavor.staging,
      'production' || 'prod' => AppFlavor.production,
      _ => throw ArgumentError.value(value, 'APP_FLAVOR', 'Unknown flavor'),
    };
  }
}

class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.enableAppCheck,
    required this.enableAnalytics,
    required this.webRecaptchaV3SiteKey,
    required this.firebaseFunctionsRegion,
    required this.googleServerClientId,
    required this.useFirebaseEmulators,
    required this.firebaseEmulatorHost,
    required this.firebaseDatabaseUrl,
    this.supportUrl,
    this.statusUrl,
    this.storeUrl,
  });

  factory AppEnvironment.fromCompileTime() {
    const String rawFlavor = String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'development',
    );
    const bool enableAppCheck = bool.fromEnvironment(
      'ENABLE_APP_CHECK',
      defaultValue: false,
    );
    const bool enableAnalytics = bool.fromEnvironment(
      'ENABLE_ANALYTICS',
      defaultValue: false,
    );
    const String recaptchaKey = String.fromEnvironment(
      'FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY',
    );
    const String functionsRegion = String.fromEnvironment(
      'FIREBASE_FUNCTIONS_REGION',
      defaultValue: 'europe-west1',
    );
    const String serverClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    );
    const bool useEmulators = bool.fromEnvironment(
      'USE_FIREBASE_EMULATORS',
      defaultValue: false,
    );
    const String emulatorHost = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '127.0.0.1',
    );
    const String databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
    const String supportUrl = String.fromEnvironment('SUPPORT_URL');
    const String statusUrl = String.fromEnvironment('STATUS_URL');
    const String storeUrl = String.fromEnvironment('STORE_URL');

    return AppEnvironment(
      flavor: AppFlavor.parse(rawFlavor),
      enableAppCheck: enableAppCheck,
      enableAnalytics: enableAnalytics,
      webRecaptchaV3SiteKey: recaptchaKey.trim().isEmpty
          ? null
          : recaptchaKey.trim(),
      firebaseFunctionsRegion: functionsRegion.trim(),
      googleServerClientId: serverClientId.trim().isEmpty
          ? null
          : serverClientId.trim(),
      useFirebaseEmulators: useEmulators,
      firebaseEmulatorHost: emulatorHost.trim(),
      firebaseDatabaseUrl: databaseUrl.trim().isEmpty
          ? null
          : databaseUrl.trim(),
      supportUrl: supportUrl.trim().isEmpty ? null : supportUrl.trim(),
      statusUrl: statusUrl.trim().isEmpty ? null : statusUrl.trim(),
      storeUrl: storeUrl.trim().isEmpty ? null : storeUrl.trim(),
    );
  }

  final AppFlavor flavor;
  final bool enableAppCheck;
  final bool enableAnalytics;
  final String? webRecaptchaV3SiteKey;
  final String firebaseFunctionsRegion;
  final String? googleServerClientId;
  final bool useFirebaseEmulators;
  final String firebaseEmulatorHost;
  final String? firebaseDatabaseUrl;
  final String? supportUrl;
  final String? statusUrl;
  final String? storeUrl;

  bool get isDevelopment => flavor == AppFlavor.development;
  bool get isProduction => flavor == AppFlavor.production;

  String get displayName => switch (flavor) {
    AppFlavor.development => 'Development',
    AppFlavor.staging => 'Staging',
    AppFlavor.production => 'Production',
  };
}
