import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/domain/entities/entity_audit.dart';
import 'package:reemove/core/domain/value_objects/content_policy.dart';
import 'package:reemove/features/authentication/application/authentication_providers.dart';
import 'package:reemove/features/authentication/domain/entities/auth_user.dart';
import 'package:reemove/features/groups/application/groups_providers.dart';
import 'package:reemove/features/groups/domain/entities/group.dart';
import 'package:reemove/features/groups/domain/entities/group_enums.dart';
import 'package:reemove/features/groups/domain/entities/group_location.dart';
import 'package:reemove/features/groups/domain/entities/group_member.dart';
import 'package:reemove/features/groups/presentation/screens/group_invite_screen.dart';
import 'package:reemove/features/profile/application/profile_providers.dart';
import 'package:reemove/features/profile/domain/entities/profile_connection.dart';
import 'package:reemove/features/profile/domain/entities/profile_privacy_settings.dart';
import 'package:reemove/features/profile/domain/entities/user_profile.dart';

UserProfile _profile({
  required String uid,
  required String username,
  required String displayName,
}) {
  final DateTime now = DateTime.utc(2026, 1, 1);
  return UserProfile(
    uid: uid,
    username: username,
    usernameNormalized: username,
    displayName: displayName,
    bio: '',
    role: UserRole.athlete,
    isVerified: false,
    verificationType: VerificationType.none,
    favoriteSportIds: const <String>[],
    sportLevels: const <String, SportLevel>{},
    goals: const <String>[],
    discoveryRadiusKm: 25,
    visibility: Visibility.public,
    followApprovalPolicy: FollowApprovalPolicy.automatic,
    followersCount: 1,
    followingCount: 0,
    postsCount: 0,
    reelsCount: 0,
    onboardingCompleted: true,
    moderationState: ModerationState.active,
    audit: EntityAudit(createdAt: now, updatedAt: now, schemaVersion: 1),
  );
}

void main() {
  const AuthUser owner = AuthUser(
    uid: 'owner',
    email: 'owner@test.com',
    emailVerified: true,
    isAnonymous: false,
    providers: <AuthProviderType>{AuthProviderType.password},
  );

  const Group managerGroup = Group(
    groupId: 'g1',
    name: 'Crew',
    description: '',
    category: 'running',
    privacy: GroupPrivacy.hidden,
    joinPolicy: GroupJoinPolicy.inviteOnly,
    status: GroupStatus.active,
    memberCount: 1,
    capacity: 20,
    ownerId: 'owner',
    location: GroupLocation.empty,
    membershipStatus: GroupMembershipStatus.owner,
    viewerRole: GroupMemberRole.owner,
  );

  const Group memberGroup = Group(
    groupId: 'g1',
    name: 'Crew',
    description: '',
    category: 'running',
    privacy: GroupPrivacy.hidden,
    joinPolicy: GroupJoinPolicy.inviteOnly,
    status: GroupStatus.active,
    memberCount: 2,
    capacity: 20,
    ownerId: 'owner',
    location: GroupLocation.empty,
    membershipStatus: GroupMembershipStatus.member,
    viewerRole: GroupMemberRole.member,
  );

  testWidgets('non-managers see locked invite screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(owner),
          ),
          groupProvider('g1').overrideWith((Ref ref) async => memberGroup),
        ],
        child: const MaterialApp(home: GroupInviteScreen(groupId: 'g1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Managers only'), findsOneWidget);
  });

  testWidgets('managers see pending invites and eligible followers', (
    WidgetTester tester,
  ) async {
    final UserProfile follower = _profile(
      uid: 'f1',
      username: 'follower1',
      displayName: 'Follower One',
    );
    final UserProfile alreadyMember = _profile(
      uid: 'm1',
      username: 'member1',
      displayName: 'Member One',
    );
    final UserProfile pendingInvitee = _profile(
      uid: 'p1',
      username: 'pending1',
      displayName: 'Pending One',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAuthUserProvider.overrideWith(
            (Ref ref) => Stream<AuthUser?>.value(owner),
          ),
          groupProvider('g1').overrideWith((Ref ref) async => managerGroup),
          groupMembersProvider('g1').overrideWith(
            (Ref ref) async => const <GroupMember>[
              GroupMember(
                userId: 'owner',
                role: GroupMemberRole.owner,
                displayName: 'Owner',
                username: 'owner',
              ),
              GroupMember(
                userId: 'm1',
                role: GroupMemberRole.member,
                displayName: 'Member One',
                username: 'member1',
              ),
            ],
          ),
          groupPendingInvitationsProvider('g1').overrideWith(
            (Ref ref) async => const <GroupPendingInvitation>[
              GroupPendingInvitation(
                inviteeId: 'p1',
                inviterId: 'owner',
                displayName: 'Pending One',
                username: 'pending1',
              ),
            ],
          ),
          profileConnectionsProvider(
            const ProfileConnectionsQuery(
              profileId: 'owner',
              type: ProfileConnectionType.followers,
            ),
          ).overrideWith(
            (Ref ref) async => ProfileConnectionPage(
              items: <UserProfile>[follower, alreadyMember, pendingInvitee],
              hasMore: false,
            ),
          ),
        ],
        child: const MaterialApp(home: GroupInviteScreen(groupId: 'g1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending One'), findsOneWidget);
    expect(find.text('@pending1 · Pending'), findsOneWidget);
    expect(find.text('Follower One'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('Member One'), findsNothing);
  });
}

