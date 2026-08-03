import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/groups/domain/entities/group_enums.dart';
import 'package:reemove/features/groups/presentation/widgets/group_membership_badge.dart';

void main() {
  group('GroupMembershipBadge', () {
    testWidgets('renders role and pending labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                GroupMembershipBadge(status: GroupMembershipStatus.owner),
                GroupMembershipBadge(status: GroupMembershipStatus.admin),
                GroupMembershipBadge(status: GroupMembershipStatus.member),
                GroupMembershipBadge(status: GroupMembershipStatus.pending),
                GroupMembershipBadge(status: GroupMembershipStatus.none),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });
  });

  group('group label helpers', () {
    test('privacy and join-policy labels', () {
      expect(groupPrivacyLabel(GroupPrivacy.hidden), 'Hidden');
      expect(groupJoinPolicyLabel(GroupJoinPolicy.inviteOnly), 'Invite only');
      expect(groupMemberRoleLabel(GroupMemberRole.owner), 'Owner');
    });
  });
}
