import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/notifications/data/dto/app_notification_dto.dart';
import 'package:reemove/features/notifications/data/mappers/notification_mapper.dart';
import 'package:reemove/features/notifications/domain/entities/app_notification.dart';

void main() {
  test('maps grouped marketplace notification into the domain model', () {
    final DateTime now = DateTime.utc(2026, 7, 14, 10);
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
    final DateTime now = DateTime.utc(2026, 7, 14, 10);
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
