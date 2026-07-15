import '../../../../../core/domain/entities/entity_audit.dart';
import '../../../../../core/domain/value_objects/content_policy.dart';
import '../../../../../core/domain/value_objects/geo_location.dart';
import '../../../../../core/domain/value_objects/media_asset.dart';
import '../../../../../core/domain/value_objects/money.dart';

enum SportsEventType {
  match,
  meetup,
  training,
  classSession,
  competition,
  community,
}

enum SportsEventStatus { draft, published, cancelled, completed }

class SportsEvent {
  const SportsEvent({
    required this.id,
    required this.ownerId,
    required this.sportId,
    required this.type,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.timezone,
    required this.location,
    required this.capacity,
    required this.attendeeCount,
    required this.minimumLevel,
    required this.maximumLevel,
    required this.visibility,
    required this.status,
    required this.moderationState,
    required this.media,
    required this.audit,
    this.placeId,
    this.price,
  });

  final String id;
  final String ownerId;
  final String sportId;
  final SportsEventType type;
  final String title;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;
  final GeoLocation location;
  final String? placeId;
  final int capacity;
  final int attendeeCount;
  final String minimumLevel;
  final String maximumLevel;
  final Money? price;
  final Visibility visibility;
  final SportsEventStatus status;
  final ModerationState moderationState;
  final List<MediaAsset> media;
  final EntityAudit audit;
}
