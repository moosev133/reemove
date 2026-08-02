import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/notifications/data/dto/app_notification_dto.dart';
import 'package:reemove/features/notifications/data/mappers/notification_mapper.dart';
import 'package:reemove/features/notifications/domain/entities/app_notification.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 7, 24, 12);

  AppNotificationDto buildDto({
    required String kind,
    Map<String, String> data = const <String, String>{},
    DateTime? deletedAt,
  }) {
    return AppNotificationDto(
      id: 'n1',
      category: 'activity',
      kind: kind,
      title: kind == 'follow_request' ? 'Follow request' : 'Title',
      body: 'Body',
      route: '/profile/user/mmmmmm',
      groupKey: 'group',
      groupCount: 1,
      actors: const <NotificationActorDto>[
        NotificationActorDto(
          id: 'SXYHRzqwvnawTyxgEEdpfwNqRnG2',
          username: 'mmmmmm',
          displayName: 'mustafaa',
          isVerified: false,
        ),
      ],
      data: data,
      entityType: 'user',
      entityId: 'SXYHRzqwvnawTyxgEEdpfwNqRnG2',
      createdAt: now,
      latestAt: now,
      updatedAt: now,
      deletedAt: deletedAt,
    );
  }

  test('pending follow_request wire shape maps into actionable Activity item', () {
    final AppNotification notification = buildDto(
      kind: 'follow_request',
      data: const <String, String>{
        'profileId': 'SXYHRzqwvnawTyxgEEdpfwNqRnG2',
        'requesterId': 'SXYHRzqwvnawTyxgEEdpfwNqRnG2',
        'targetId': 'rAVFw0NRryd4nYjXMUU2qjIDUAy1',
        'requestId':
            'SXYHRzqwvnawTyxgEEdpfwNqRnG2--rAVFw0NRryd4nYjXMUU2qjIDUAy1',
        'status': 'pending',
        'source': 'follow_request_pending',
      },
    ).toDomain();

    expect(notification.kind, AppNotificationKind.followRequest);
    expect(notification.category, AppNotificationCategory.activity);
    expect(notification.deletedAt, isNull);
    expect(notification.data['status'], 'pending');
    expect(notification.entityId, 'SXYHRzqwvnawTyxgEEdpfwNqRnG2');
    expect(notification.actors.single.username, 'mmmmmm');
  });

  test('soft-deleted and unknown kinds are excluded from Activity rendering', () {
    final AppNotification active = buildDto(
      kind: 'follow_request',
      data: const <String, String>{'status': 'pending'},
    ).toDomain();
    final AppNotification deleted = buildDto(
      kind: 'follow_request',
      data: const <String, String>{'status': 'pending'},
      deletedAt: now,
    ).toDomain();
    final AppNotification orphanNewFollower = buildDto(
      kind: 'new_follower',
      data: const <String, String>{
        'relationshipStatus': 'confirmed',
        'source': 'stale_new_follower_cleanup',
        'status': 'resolved',
      },
    ).toDomain();

    final List<AppNotification> visible = <AppNotification>[
      active,
      deleted,
      orphanNewFollower,
    ].where(
      (AppNotification notification) =>
          notification.deletedAt == null &&
          notification.kind != AppNotificationKind.unknown,
    ).toList(growable: false);

    expect(visible, hasLength(1));
    expect(visible.single.kind, AppNotificationKind.followRequest);
  });

  test('Activity Social filter keeps follow_request category activity', () {
    final AppNotification notification = buildDto(
      kind: 'follow_request',
      data: const <String, String>{'status': 'pending'},
    ).toDomain();
    expect(notification.category, AppNotificationCategory.activity);
  });

  test('inbox over-fetch stays within firestore notifications list limit', () {
    // Mirrors FirebaseNotificationRepository._queryFetchLimit — rules require
    // request.query.limit <= 100 on users/{uid}/notifications.
    int fetchLimit(int boundedLimit) => (boundedLimit * 3).clamp(1, 100).toInt();

    expect(fetchLimit(50), 100);
    expect(fetchLimit(20), 60);
    expect(fetchLimit(100), 100);
    expect(fetchLimit(1), 3);
  });
}
