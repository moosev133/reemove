enum AuthProviderType {
  password('password'),
  google('google.com'),
  apple('apple.com'),
  unknown('unknown');

  const AuthProviderType(this.providerId);

  final String providerId;

  static AuthProviderType fromProviderId(String value) {
    return AuthProviderType.values.firstWhere(
      (AuthProviderType provider) => provider.providerId == value,
      orElse: () => AuthProviderType.unknown,
    );
  }
}

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.isAnonymous,
    required this.providers,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.lastSignInAt,
  });

  final String uid;
  final String? email;
  final bool emailVerified;
  final bool isAnonymous;
  final String? displayName;
  final String? photoUrl;
  final Set<AuthProviderType> providers;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;

  bool get usesPassword => providers.contains(AuthProviderType.password);
  bool get usesGoogle => providers.contains(AuthProviderType.google);
  bool get usesApple => providers.contains(AuthProviderType.apple);
}
