import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/groups/domain/entities/group.dart';
import 'package:reemove/features/groups/domain/entities/group_enums.dart';
import 'package:reemove/features/groups/domain/entities/group_location.dart';

void main() {
  group('Group entity', () {
    test('manager and membership helpers', () {
      const Group group = Group(
        groupId: 'g1',
        name: 'Trail Crew',
        description: 'Runs',
        category: 'running',
        privacy: GroupPrivacy.private,
        joinPolicy: GroupJoinPolicy.approvalRequired,
        status: GroupStatus.active,
        memberCount: 3,
        capacity: 10,
        ownerId: 'owner',
        location: GroupLocation(locality: 'Haifa'),
        membershipStatus: GroupMembershipStatus.admin,
        viewerRole: GroupMemberRole.admin,
      );
      expect(group.isManager, isTrue);
      expect(group.isMember, isTrue);
      expect(group.isOwner, isFalse);
      expect(group.isFull, isFalse);
    });

    test('pending request flag', () {
      const Group group = Group(
        groupId: 'g2',
        name: 'Hidden',
        description: 'Invite',
        category: 'gym',
        privacy: GroupPrivacy.hidden,
        joinPolicy: GroupJoinPolicy.inviteOnly,
        status: GroupStatus.active,
        memberCount: 1,
        capacity: 0,
        ownerId: 'owner',
        location: GroupLocation.empty,
        membershipStatus: GroupMembershipStatus.pending,
      );
      expect(group.hasPendingRequest, isTrue);
      expect(group.isMember, isFalse);
    });
  });

  group('Group enum parsing', () {
    test('parses privacy and join policy wire values', () {
      expect(parseGroupPrivacy('hidden'), GroupPrivacy.hidden);
      expect(parseGroupJoinPolicy('inviteOnly'), GroupJoinPolicy.inviteOnly);
      expect(parseGroupMediaMode('view_once'), GroupMediaMode.viewOnce);
      expect(parseGroupMediaMode('keep_in_chat'), GroupMediaMode.keepInChat);
    });
  });
}
