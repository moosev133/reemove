import '../../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/sports_event.dart';
import '../dto/sports_event_dto.dart';

extension SportsEventDtoMapper on SportsEventDto {
  SportsEvent toDomain() => SportsEvent(
    id: id,
    ownerId: ownerId,
    sportId: sportId,
    type: SportsEventType.values.byName(type),
    title: title,
    description: description,
    startAt: startAt,
    endAt: endAt,
    timezone: timezone,
    location: location.toDomain(),
    placeId: placeId,
    capacity: capacity,
    attendeeCount: attendeeCount,
    minimumLevel: minimumLevel,
    maximumLevel: maximumLevel,
    price: price?.toDomain(),
    visibility: VisibilityStorageValue.fromStorage(visibility),
    status: SportsEventStatus.values.byName(status),
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    media: media.map((item) => item.toDomain()).toList(growable: false),
    audit: audit.toDomain(),
  );
}
