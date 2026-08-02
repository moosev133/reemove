import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/notifications/data/dto/app_notification_dto.dart';
import 'package:reemove/features/notifications/data/mappers/notification_mapper.dart';
import 'package:reemove/features/notifications/domain/entities/app_notification.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 7, 23);

  AppNotificationDto buildDto({
    required String kind,
    Map<String, String> data = const <String, String>{},
  }) {
    return AppNotificationDto(
      id: 'n1',
      category: 'activity',
      kind: kind,
      title: 'Title',
      body: 'Body',
      route: '/home/activity',
      groupKey: 'group',
      groupCount: 1,
      actors: const <NotificationActorDto>[],
      data: data,
      createdAt: now,
      latestAt: now,
      updatedAt: now,
    );
  }

  test('new_follower requires confirmed direct_follow metadata', () {
    expect(
      buildDto(kind: 'new_follower').toDomain().kind,
      AppNotificationKind.unknown,
    );
    expect(
      buildDto(
        kind: 'new_follower',
        data: const <String, String>{'relationshipStatus': 'confirmed'},
      ).toDomain().kind,
      AppNotificationKind.unknown,
    );
    expect(
      buildDto(
        kind: 'new_follower',
        data: const <String, String>{
          'relationshipStatus': 'confirmed',
          'source': 'accepted_follow_request',
        },
      ).toDomain().kind,
      AppNotificationKind.unknown,
    );
    expect(
      buildDto(
        kind: 'new_follower',
        data: const <String, String>{
          'relationshipStatus': 'confirmed',
          'source': 'direct_follow',
          'status': 'orphaned',
        },
      ).toDomain().kind,
      AppNotificationKind.unknown,
    );
    expect(
      buildDto(
        kind: 'new_follower',
        data: const <String, String>{
          'relationshipStatus': 'confirmed',
          'source': 'direct_follow',
          'status': 'confirmed',
        },
      ).toDomain().kind,
      AppNotificationKind.newFollower,
    );
  });

  test('follow_request kinds still map for pending and accepted flows', () {
    expect(
      buildDto(
        kind: 'follow_request',
        data: const <String, String>{'status': 'pending'},
      ).toDomain().kind,
      AppNotificationKind.followRequest,
    );
    expect(
      buildDto(
        kind: 'follow_request',
        data: const <String, String>{'status': 'resolved'},
      ).toDomain().kind,
      AppNotificationKind.unknown,
    );
    expect(
      buildDto(
        kind: 'follow_request_accepted',
        data: const <String, String>{'status': 'accepted'},
      ).toDomain().kind,
      AppNotificationKind.followRequestAccepted,
    );
  });

  test('pending follow_request wire shape maps into Activity social filter', () {
    final AppNotificationDto dto = AppNotificationDto(
      id: 'pending-wire',
      category: 'activity',
      kind: 'follow_request',
      title: 'Follow request',
      body: 'mustafaa (@mmmmmm) requested to follow you.',
      route: '/profile/user/mmmmmm',
      groupKey: 'follow_request_pending:requester',
      groupCount: 1,
      actors: const <NotificationActorDto>[
        NotificationActorDto(
          id: 'requester',
          username: 'mmmmmm',
          displayName: 'mustafaa',
          isVerified: false,
        ),
      ],
      data: const <String, String>{
        'profileId': 'requester',
        'requesterId': 'requester',
        'targetId': 'target',
        'requestId': 'requester--target',
        'status': 'pending',
        'source': 'follow_request_pending',
      },
      entityType: 'user',
      entityId: 'requester',
      createdAt: now,
      latestAt: now,
      updatedAt: now,
    );

    final AppNotification notification = dto.toDomain();
    expect(notification.kind, AppNotificationKind.followRequest);
    expect(notification.category, AppNotificationCategory.activity);
    expect(notification.data['status'], 'pending');
    expect(notification.entityId, 'requester');
    expect(notification.deletedAt, isNull);
    expect(notification.isUnread, isTrue);
    expect(notification.route, '/profile/user/mmmmmm');
  });

  test('maps grouped marketplace notification into the domain model', () {
    final AppNotificationDto dto = AppNotificationDto(
      id: 'listing-update',
      category: 'marketplace',
      kind: 'marketplace_update',
      title: 'Listing reserved',
      body: 'Your listing was reserved.',
      route: '/discover/marketplace/listing-1',
      groupKey: 'marketplace:listing-1',
      groupCount: 3,
      actors: const <NotificationActorDto>[
        NotificationActorDto(
          id: 'buyer',
          username: 'runner',
          displayName: 'Runner',
          isVerified: true,
        ),
      ],
      data: const <String, String>{'listingId': 'listing-1'},
      entityType: 'marketplace_listing',
      entityId: 'listing-1',
      createdAt: now,
      latestAt: now,
      updatedAt: now,
    );

    final AppNotification notification = dto.toDomain();

    expect(notification.category, AppNotificationCategory.marketplace);
    expect(notification.kind, AppNotificationKind.marketplaceUpdate);
    expect(notification.isUnread, isTrue);
    expect(notification.actors.single.isVerified, isTrue);
    expect(notification.displayBody, contains('2 more updates'));
  });

  test('unknown values fall back safely', () {
    final AppNotification notification = AppNotificationDto(
      id: 'unknown',
      category: 'future-category',
      kind: 'future-kind',
      title: 'Update',
      body: 'A future update.',
      route: '/home/activity',
      groupKey: 'future',
      groupCount: 1,
      actors: const <NotificationActorDto>[],
      data: const <String, String>{},
      createdAt: now,
      latestAt: now,
      updatedAt: now,
    ).toDomain();

    expect(notification.category, AppNotificationCategory.activity);
    expect(notification.kind, AppNotificationKind.unknown);
  });
}
