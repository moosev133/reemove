import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reemove/app/router/app_routes.dart';
import 'package:reemove/features/authentication/application/authentication_providers.dart';
import 'package:reemove/features/authentication/domain/entities/auth_user.dart';
import 'package:reemove/features/groups/application/groups_providers.dart';
import 'package:reemove/features/groups/domain/entities/group.dart';
import 'package:reemove/features/groups/domain/entities/group_enums.dart';
import 'package:reemove/features/groups/domain/entities/group_location.dart';
import 'package:reemove/features/groups/domain/entities/group_member.dart';
import 'package:reemove/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:reemove/features/groups/presentation/screens/group_members_screen.dart';
Group _group({required GroupMemberRole role}) {
  return Group(
    groupId: 'g1',
    name: 'C2 Manual Test',
    description: 'Invite entry points',
    category: 'running',
    privacy: GroupPrivacy.hidden,
    joinPolicy: GroupJoinPolicy.inviteOnly,
    status: GroupStatus.active,
    memberCount: 2,
    capacity: 20,
    ownerId: 'owner',
    location: GroupLocation.empty,
    membershipStatus: role == GroupMemberRole.owner
        ? GroupMembershipStatus.owner
        : GroupMembershipStatus.member,
    viewerRole: role,
  );
}

const AuthUser viewer = AuthUser(
  uid: 'viewer',
  email: 'viewer@test.com',
  emailVerified: true,
  isAnonymous: false,
  providers: <AuthProviderType>{AuthProviderType.password},
);

GoRouter _detailRouter() {
  return GoRouter(
    initialLocation: AppRoutes.group('g1'),
    routes: <RouteBase>[
      GoRoute(
        path: '/discover/groups/:groupId',
        builder: (BuildContext context, GoRouterState state) =>
            const GroupDetailScreen(groupId: 'g1'),
        routes: <RouteBase>[
          GoRoute(
            path: 'invite',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('invite-route')),
          ),
          GoRoute(
            path: 'members',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('members-route')),
          ),
          GoRoute(
            path: 'requests',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('requests-route')),
          ),
        ],
      ),
    ],
  );
}

GoRouter _membersRouter() {
  return GoRouter(
    initialLocation: AppRoutes.groupMembers('g1'),
    routes: <RouteBase>[
      GoRoute(
        path: '/discover/groups/:groupId',
        builder: (BuildContext context, GoRouterState state) =>
            const SizedBox.shrink(),
        routes: <RouteBase>[
          GoRoute(
            path: 'members',
            builder: (BuildContext context, GoRouterState state) =>
                const GroupMembersScreen(groupId: 'g1'),
          ),
          GoRoute(
            path: 'invite',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('invite-route')),
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpDetail(WidgetTester tester, Group group) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupProvider('g1').overrideWith((Ref ref) async => group),
        currentAuthUserProvider.overrideWith(
          (Ref ref) => Stream<AuthUser?>.value(viewer),
        ),
      ],
      child: MaterialApp.router(routerConfig: _detailRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMembers(WidgetTester tester, Group group) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupProvider('g1').overrideWith((Ref ref) async => group),
        currentAuthUserProvider.overrideWith(
          (Ref ref) => Stream<AuthUser?>.value(viewer),
        ),
        groupMembersProvider('g1').overrideWith(
          (Ref ref) async => const <GroupMember>[
            GroupMember(
              userId: 'owner',
              role: GroupMemberRole.owner,
              displayName: 'Owner',
              username: 'owner',
            ),
          ],
        ),
      ],
      child: MaterialApp.router(routerConfig: _membersRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('owner sees Invite members in Manage and overflow menu', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, _group(role: GroupMemberRole.owner));

    expect(find.byKey(const Key('group-detail-invite-members')), findsOneWidget);
    expect(find.text('Invite followers to this group'), findsOneWidget);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-menu-invite-members')), findsOneWidget);
  });

  testWidgets('admin sees Invite members entry points', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, _group(role: GroupMemberRole.admin));

    expect(find.byKey(const Key('group-detail-invite-members')), findsOneWidget);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-menu-invite-members')), findsOneWidget);
  });

  testWidgets('normal member does not see Invite members entry points', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, _group(role: GroupMemberRole.member));

    expect(find.byKey(const Key('group-detail-invite-members')), findsNothing);
    expect(find.text('Invite members'), findsNothing);
    expect(find.text('Join requests'), findsNothing);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-menu-invite-members')), findsNothing);
    expect(find.text('Invite members'), findsNothing);
    expect(find.text('Edit group'), findsNothing);
  });

  testWidgets('owner Manage Invite members navigates to invite route', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, _group(role: GroupMemberRole.owner));
    final Finder tile = find.byKey(const Key('group-detail-invite-members'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('invite-route'), findsOneWidget);
  });

  testWidgets('owner overflow Invite members navigates to invite route', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, _group(role: GroupMemberRole.owner));
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-menu-invite-members')));
    await tester.pumpAndSettle();
    expect(find.text('invite-route'), findsOneWidget);
  });

  testWidgets('owner Members screen shows Invite FAB and navigates', (
    WidgetTester tester,
  ) async {
    await _pumpMembers(tester, _group(role: GroupMemberRole.owner));
    expect(find.byKey(const Key('group-members-invite-fab')), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-members-invite-fab')));
    await tester.pumpAndSettle();
    expect(find.text('invite-route'), findsOneWidget);
  });

  testWidgets('admin Members screen shows Invite FAB', (
    WidgetTester tester,
  ) async {
    await _pumpMembers(tester, _group(role: GroupMemberRole.admin));
    expect(find.byKey(const Key('group-members-invite-fab')), findsOneWidget);
  });

  testWidgets('normal member Members screen hides Invite FAB', (
    WidgetTester tester,
  ) async {
    await _pumpMembers(tester, _group(role: GroupMemberRole.member));
    expect(find.byKey(const Key('group-members-invite-fab')), findsNothing);
    expect(find.text('Invite'), findsNothing);
  });
}

