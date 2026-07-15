class OnboardingPolicy {
  const OnboardingPolicy({
    this.minimumAge = 13,
    this.maximumAge = 120,
    this.termsVersion = '1.0',
    this.privacyVersion = '1.0',
  });

  final int minimumAge;
  final int maximumAge;
  final String termsVersion;
  final String privacyVersion;
}
