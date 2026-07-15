abstract final class AppRoutes {
  static const String startup = '/';
  static const String authUnavailable = '/auth/unavailable';
  static const String authWelcome = '/auth';
  static const String signIn = '/auth/sign-in';
  static const String signUp = '/auth/sign-up';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyEmail = '/auth/verify-email';
  static const String usernameSetup = '/auth/username';
  static const String accountBlocked = '/auth/blocked';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String accountSecurity = '/account/security';
}

abstract final class AppRouteNames {
  static const String startup = 'startup';
  static const String authUnavailable = 'auth-unavailable';
  static const String authWelcome = 'auth-welcome';
  static const String signIn = 'sign-in';
  static const String signUp = 'sign-up';
  static const String forgotPassword = 'forgot-password';
  static const String verifyEmail = 'verify-email';
  static const String usernameSetup = 'username-setup';
  static const String accountBlocked = 'account-blocked';
  static const String onboarding = 'onboarding';
  static const String home = 'home';
  static const String accountSecurity = 'account-security';
}
