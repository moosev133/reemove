import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../../core/database/dto/geo_location_dto.dart';
import '../../../../../core/database/dto/media_asset_dto.dart';
import '../../../../../core/database/firestore_parser.dart';

class SportPlaceDto {
  const SportPlaceDto({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.sportIds,
    required this.location,
    required this.addressLine,
    required this.city,
    required this.countryCode,
    required this.media,
    required this.rating,
    required this.reviewCount,
    required this.isVerified,
    required this.visibility,
    required this.moderationState,
    required this.audit,
    this.pricingText,
  });

  factory SportPlaceDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Place ${snapshot.id} has no data.');
    }
    return SportPlaceDto(
      id: snapshot.id,
      name: FirestoreParser.string(data, 'name'),
      description: FirestoreParser.string(data, 'description', fallback: ''),
      type: FirestoreParser.string(data, 'type', fallback: 'other'),
      sportIds: FirestoreParser.stringList(data, 'sportIds'),
      location: GeoLocationDto.fromMap(data),
      addressLine: FirestoreParser.string(data, 'addressLine', fallback: ''),
      city: FirestoreParser.string(data, 'city', fallback: ''),
      countryCode: FirestoreParser.string(data, 'countryCode', fallback: ''),
      media: FirestoreParser.mapList(
        data,
        'media',
      ).map(MediaAssetDto.fromMap).toList(growable: false),
      pricingText: FirestoreParser.nullableString(data, 'pricingText'),
      rating: FirestoreParser.number(data, 'rating', fallback: 0),
      reviewCount: FirestoreParser.integer(data, 'reviewCount', fallback: 0),
      isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
      visibility: FirestoreParser.string(
        data,
        'visibility',
        fallback: 'public',
      ),
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String name;
  final String description;
  final String type;
  final List<String> sportIds;
  final GeoLocationDto location;
  final String addressLine;
  final String city;
  final String countryCode;
  final List<MediaAssetDto> media;
  final String? pricingText;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final String visibility;
  final String moderationState;
  final EntityAuditDto audit;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'name': name,
    'description': description,
    'type': type,
    'sportIds': sportIds,
    ...location.toMap(),
    'addressLine': addressLine,
    'city': city,
    'countryCode': countryCode,
    'media': media.map((MediaAssetDto item) => item.toMap()).toList(),
    if (pricingText != null) 'pricingText': pricingText,
    'rating': rating,
    'reviewCount': reviewCount,
    'isVerified': isVerified,
    'visibility': visibility,
    'moderationState': moderationState,
    ...audit.toMap(),
  };
}
