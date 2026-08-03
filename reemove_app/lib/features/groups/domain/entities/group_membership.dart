import 'group_enums.dart';
import 'group_snapshot.dart';

/// An entry from `listMyGroups`: a group the current user actively belongs to.
class MyGroupMembership {
  const MyGroupMembership({
    required this.groupId,
    required this.role,
    required this.snapshot,
    this.joinedAt,
  });

  final String groupId;
  final GroupMemberRole role;
  final GroupSnapshot snapshot;
  final DateTime? joinedAt;
}
