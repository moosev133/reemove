enum AuthDestination {
  configurationRequired,
  signedOut,
  profileRequired,
  emailVerificationRequired,
  onboardingRequired,
  ready,
  blocked,
}

class AuthRoutingState {
  const AuthRoutingState({required this.destination, this.reason});

  final AuthDestination destination;
  final String? reason;
}
