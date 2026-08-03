import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/notifications/domain/entities/app_notification.dart';
import 'package:reemove/features/notifications/presentation/widgets/notification_tile.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 7, 22);

  testWidgets('pending message request tile exposes Accept and Decline', (
    WidgetTester tester,
  ) async {
    bool accepted = false;
    bool declined = false;
    final AppNotification notification = AppNotification(
      id: 'n-msg-1',
      category: AppNotificationCategory.activity,
      kind: AppNotificationKind.messageRequest,
      title: 'Message request',
      body: 'Requester (@requester) wants to message you.',
      route: '/profile/user/requester',
      groupKey: 'message_request_pending:requester',
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
            onAcceptFollowRequest: () => accepted = true,
            onDeclineFollowRequest: () => declined = true,
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

  testWidgets('resolved message request hides Accept and Decline', (
    WidgetTester tester,
  ) async {
    final AppNotification notification = AppNotification(
      id: 'n-msg-2',
      category: AppNotificationCategory.activity,
      kind: AppNotificationKind.messageRequest,
      title: 'Message request',
      body: 'Requester (@requester) wants to message you.',
      route: '/profile/user/requester',
      groupKey: 'message_request_pending:requester',
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
        'status': 'resolved',
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
