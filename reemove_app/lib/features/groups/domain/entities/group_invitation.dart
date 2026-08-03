import 'group_snapshot.dart';

class GroupInvitation {
  const GroupInvitation({
    required this.groupId,
    required this.inviterId,
    required this.snapshot,
    this.createdAt,
  });

  final String groupId;
  final String inviterId;
  final GroupSnapshot snapshot;
  final DateTime? createdAt;
}
