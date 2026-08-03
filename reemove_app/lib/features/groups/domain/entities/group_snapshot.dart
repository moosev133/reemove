import 'group_enums.dart';

/// Lightweight group summary embedded in membership, invitation, and
/// notification payloads so lists can render without an extra round trip.
class GroupSnapshot {
  const GroupSnapshot({
    required this.name,
    required this.privacy,
    required this.category,
    required this.memberCount,
    this.avatarUrl,
  });

  final String name;
  final GroupPrivacy privacy;
  final String category;
  final int memberCount;
  final String? avatarUrl;
}
