import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/notifications/domain/entities/app_notification.dart';
import 'package:reemove/features/notifications/presentation/widgets/notification_tile.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 7, 22);

  testWidgets('pending follow request tile exposes Accept and Decline', (
    WidgetTester tester,
  ) async {
    bool accepted = false;
    bool declined = false;
    bool actorOpened = false;
    final AppNotification notification = AppNotification(
      id: 'n1',
      category: AppNotificationCategory.activity,
      kind: AppNotificationKind.followRequest,
      title: 'Follow request',
      body: 'Requester (@requester) requested to follow you.',
      route: '/profile/user/requester',
      groupKey: 'follow_request_pending:requester',
      groupCount: 1,
      actors: const <NotificationActor>[
        NotificationActor(
          id: 'requester',
          username: 'requester',
          displayName: 'Requester',
          isVerified: false,
        ),
      ],
      entityId: 'requester',
      data: const <String, String>{
        'profileId': 'requester',
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
            onActorTap: () => actorOpened = true,
            onAcceptFollowRequest: () => accepted = true,
            onDeclineFollowRequest: () => declined = true,
          ),
        ),
      ),
    );

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.textContaining('@requester'), findsWidgets);
    await tester.tap(find.text('Follow request'));
    await tester.pump();
    expect(actorOpened, isTrue);
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(accepted, isTrue);
    await tester.tap(find.text('Decline'));
    await tester.pump();
    expect(declined, isTrue);
  });

  testWidgets('accepted follow request has no Accept/Decline actions', (
    WidgetTester tester,
  ) async {
    final AppNotification notification = AppNotification(
      id: 'n2',
      category: AppNotificationCategory.activity,
      kind: AppNotificationKind.followRequestAccepted,
      title: 'Follow request accepted',
      body: 'Target (@target) accepted your follow request.',
      route: '/profile/user/target',
      groupKey: 'follow_request_accepted:target',
      groupCount: 1,
      actors: const <NotificationActor>[
        NotificationActor(
          id: 'target',
          username: 'target',
          displayName: 'Target',
          isVerified: false,
        ),
      ],
      entityId: 'target',
      data: const <String, String>{'status': 'accepted'},
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
            onAcceptFollowRequest: () {},
            onDeclineFollowRequest: () {},
          ),
        ),
      ),
    );

    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
  });

  testWidgets('resolved follow_request status hides actions', (
    WidgetTester tester,
  ) async {
    final AppNotification notification = AppNotification(
      id: 'n3',
      category: AppNotificationCategory.activity,
      kind: AppNotificationKind.followRequest,
      title: 'Follow request',
      body: 'Old request',
      route: '/profile/user/requester',
      groupKey: 'follow_request_pending:requester',
      groupCount: 1,
      actors: const <NotificationActor>[],
      entityId: 'requester',
      data: const <String, String>{'status': 'resolved'},
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
            onAcceptFollowRequest: () {},
            onDeclineFollowRequest: () {},
          ),
        ),
      ),
    );

    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
  });
}
