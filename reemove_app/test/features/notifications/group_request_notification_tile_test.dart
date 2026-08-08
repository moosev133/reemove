import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reemove/features/notifications/domain/entities/app_notification.dart';
import 'package:reemove/features/notifications/presentation/widgets/notification_tile.dart';

void main() {
  testWidgets('pending group join request tile exposes Accept and Decline', (
    WidgetTester tester,
  ) async {
    bool accepted = false;
    bool declined = false;
    final DateTime now = DateTime.utc(2026, 7, 22);

    final AppNotification notification = AppNotification(
      id: 'n-group-join-1',
      category: AppNotificationCategory.activity,
      kind: AppNotificationKind.groupJoinRequest,
      title: 'Group join request',
      body: 'Alice requested to join',
      route: '/discover/groups/g1/requests',
      groupKey: 'group_join_request:g1:requester',
      groupCount: 1,
      actors: <NotificationActor>[
        NotificationActor(
          id: 'requester',
          username: 'requester',
          displayName: 'Alice',
          isVerified: false,
        ),
      ],
      entityId: 'g1',
      data: <String, String>{
        'groupId': 'g1',
        'requesterId': 'requester',
        'status': 'pending',
      },
      latestAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationTile(
            notification: notification,
            onTap: () {},
            onDelete: () {},
            onAcceptGroupJoinRequest: () => accepted = true,
            onDeclineGroupJoinRequest: () => declined = true,
          ),
        ),
      ),
    );

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(accepted, isTrue);

    await tester.tap(find.text('Decline'));
    await tester.pump();
    expect(declined, isTrue);
  });

  testWidgets('pending group invitation tile exposes Accept and Decline', (
    WidgetTester tester,
  ) async {
    bool accepted = false;
    bool declined = false;
    final DateTime now = DateTime.utc(2026, 7, 22);

    final AppNotification notification = AppNotification(
      id: 'n-group-invite-1',
      category: AppNotificationCategory.activity,
      kind: AppNotificationKind.groupInvitation,
      title: 'Group invitation',
      body: 'Bob invited you',
      route: '/discover/groups/invitations',
      groupKey: 'group_invitation:g1:invitee',
      groupCount: 1,
      actors: <NotificationActor>[
        NotificationActor(
          id: 'inviter',
          username: 'inviter',
          displayName: 'Bob',
          isVerified: false,
        ),
      ],
      entityId: 'g1',
      data: <String, String>{
        'groupId': 'g1',
        'inviterId': 'inviter',
        'status': 'pending',
      },
      latestAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationTile(
            notification: notification,
            onTap: () {},
            onDelete: () {},
            onAcceptGroupInvitation: () => accepted = true,
            onDeclineGroupInvitation: () => declined = true,
          ),
        ),
      ),
    );

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(accepted, isTrue);

    await tester.tap(find.text('Decline'));
    await tester.pump();
    expect(declined, isTrue);
  });
}


