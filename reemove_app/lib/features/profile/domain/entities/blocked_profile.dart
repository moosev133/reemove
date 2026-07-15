import 'user_profile.dart';

class BlockedProfile {
  const BlockedProfile({required this.profile, required this.blockedAt});

  final UserProfile profile;
  final DateTime blockedAt;
}
