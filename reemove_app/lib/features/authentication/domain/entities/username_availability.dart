enum UsernameAvailabilityState { available, taken, invalid }

class UsernameAvailability {
  const UsernameAvailability({
    required this.state,
    required this.normalizedUsername,
    this.message,
  });

  final UsernameAvailabilityState state;
  final String normalizedUsername;
  final String? message;

  bool get isAvailable => state == UsernameAvailabilityState.available;
}
