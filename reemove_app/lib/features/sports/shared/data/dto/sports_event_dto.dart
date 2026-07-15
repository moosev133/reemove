import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../../core/database/dto/geo_location_dto.dart';
import '../../../../../core/database/dto/media_asset_dto.dart';
import '../../../../../core/database/dto/money_dto.dart';
import '../../../../../core/database/firestore_parser.dart';

class SportsEventDto {
  const SportsEventDto({
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

  factory SportsEventDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Event ${snapshot.id} has no data.');
    }
    final Object? priceData = data['price'];
    return SportsEventDto(
      id: snapshot.id,
      ownerId: FirestoreParser.string(data, 'ownerId'),
      sportId: FirestoreParser.string(data, 'sportId'),
      type: FirestoreParser.string(data, 'type'),
      title: FirestoreParser.string(data, 'title'),
      description: FirestoreParser.string(data, 'description', fallback: ''),
      startAt: FirestoreParser.dateTime(data, 'startAt'),
      endAt: FirestoreParser.dateTime(data, 'endAt'),
      timezone: FirestoreParser.string(data, 'timezone'),
      location: GeoLocationDto.fromMap(data),
      placeId: FirestoreParser.nullableString(data, 'placeId'),
      capacity: FirestoreParser.integer(data, 'capacity', fallback: 0),
      attendeeCount: FirestoreParser.integer(
        data,
        'attendeeCount',
        fallback: 0,
      ),
      minimumLevel: FirestoreParser.string(
        data,
        'minimumLevel',
        fallback: 'beginner',
      ),
      maximumLevel: FirestoreParser.string(
        data,
        'maximumLevel',
        fallback: 'professional',
      ),
      price: priceData is Map
          ? MoneyDto.fromMap(priceData.cast<String, Object?>())
          : null,
      visibility: FirestoreParser.string(
        data,
        'visibility',
        fallback: 'public',
      ),
      status: FirestoreParser.string(data, 'status', fallback: 'published'),
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      media: FirestoreParser.mapList(
        data,
        'media',
      ).map(MediaAssetDto.fromMap).toList(growable: false),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String ownerId;
  final String sportId;
  final String type;
  final String title;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;
  final GeoLocationDto location;
  final String? placeId;
  final int capacity;
  final int attendeeCount;
  final String minimumLevel;
  final String maximumLevel;
  final MoneyDto? price;
  final String visibility;
  final String status;
  final String moderationState;
  final List<MediaAssetDto> media;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'ownerId': ownerId,
    'sportId': sportId,
    'type': type,
    'title': title,
    'description': description,
    'startAt': Timestamp.fromDate(startAt.toUtc()),
    'endAt': Timestamp.fromDate(endAt.toUtc()),
    'timezone': timezone,
    ...location.toMap(),
    if (placeId != null) 'placeId': placeId,
    'capacity': capacity,
    'attendeeCount': attendeeCount,
    'minimumLevel': minimumLevel,
    'maximumLevel': maximumLevel,
    if (price != null) 'price': price!.toMap(),
    'visibility': visibility,
    'status': status,
    'moderationState': moderationState,
    'media': media.map((MediaAssetDto item) => item.toMap()).toList(),
    ...audit.toMap(),
  };
}
