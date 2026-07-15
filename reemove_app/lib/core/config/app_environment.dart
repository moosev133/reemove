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
    required this.webRecaptchaV3SiteKey,
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
    const String recaptchaKey = String.fromEnvironment(
      'FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY',
    );

    return AppEnvironment(
      flavor: AppFlavor.parse(rawFlavor),
      enableAppCheck: enableAppCheck,
      webRecaptchaV3SiteKey: recaptchaKey.trim().isEmpty
          ? null
          : recaptchaKey.trim(),
    );
  }

  final AppFlavor flavor;
  final bool enableAppCheck;
  final String? webRecaptchaV3SiteKey;

  bool get isDevelopment => flavor == AppFlavor.development;
  bool get isProduction => flavor == AppFlavor.production;

  String get displayName => switch (flavor) {
    AppFlavor.development => 'Development',
    AppFlavor.staging => 'Staging',
    AppFlavor.production => 'Production',
  };
}
