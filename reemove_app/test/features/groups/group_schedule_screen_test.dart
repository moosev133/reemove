import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/groups/application/groups_providers.dart';
import 'package:reemove/features/groups/domain/entities/group.dart';
import 'package:reemove/features/groups/domain/entities/group_enums.dart';
import 'package:reemove/features/groups/domain/entities/group_location.dart';
import 'package:reemove/features/groups/domain/entities/group_session.dart';
import 'package:reemove/features/groups/presentation/screens/group_schedule_screen.dart';

void main() {
  test('GroupSession maps typed kinds and RSVP counts', () {
    const GroupSession session = GroupSession(
      sessionId: 's1',
      title: 'Track',
      sessionType: GroupSessionType.training,
      activity: 'intervals',
      description: '',
      location: GroupLocation.empty,
      capacity: 8,
      status: GroupSessionStatus.scheduled,
      rsvpCounts: GroupSessionRsvpCounts(going: 3, maybe: 1),
      viewerRsvp: GroupSessionRsvpStatus.going,
    );
    expect(session.sessionType.displayLabel, 'Training');
    expect(session.rsvpCounts.going, 3);
    expect(session.isAtCapacity, isFalse);
  });

  testWidgets('GroupScheduleScreen shows type and RSVP chips for members', (
    WidgetTester tester,
  ) async {
    const Group memberGroup = Group(
      groupId: 'g1',
      name: 'Crew',
      description: '',
      category: 'running',
      privacy: GroupPrivacy.public,
      joinPolicy: GroupJoinPolicy.open,
      status: GroupStatus.active,
      memberCount: 2,
      capacity: 0,
      ownerId: 'owner',
      location: GroupLocation.empty,
      membershipStatus: GroupMembershipStatus.member,
      viewerRole: GroupMemberRole.member,
    );
    final List<GroupSession> sessions = <GroupSession>[
      GroupSession(
        sessionId: 's1',
        title: 'Friday match',
        sessionType: GroupSessionType.match,
        activity: 'match',
        description: '',
        location: GroupLocation.empty,
        capacity: 10,
        status: GroupSessionStatus.scheduled,
        startAt: DateTime.utc(2026, 9, 4, 16),
        endAt: DateTime.utc(2026, 9, 4, 18),
        rsvpCounts: const GroupSessionRsvpCounts(going: 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupProvider('g1').overrideWith((Ref ref) async => memberGroup),
          groupSessionsProvider('g1').overrideWith((Ref ref) async => sessions),
        ],
        child: const MaterialApp(home: GroupScheduleScreen(groupId: 'g1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Friday match'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Going'), findsOneWidget);
    expect(find.text('Maybe'), findsOneWidget);
  });
}

