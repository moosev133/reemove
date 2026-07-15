import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../core/database/dto/geo_location_dto.dart';
import '../../../../core/database/dto/media_asset_dto.dart';
import '../../../../core/database/dto/money_dto.dart';
import '../../../../core/database/firestore_parser.dart';

class SellerSnapshotDto {
  const SellerSnapshotDto({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.isVerified,
    this.avatarUrl,
    this.verificationType,
  });

  factory SellerSnapshotDto.fromMap(FirestoreMap data) => SellerSnapshotDto(
    uid: FirestoreParser.string(
      data,
      'uid',
      fallback: FirestoreParser.string(data, 'id', fallback: ''),
    ),
    username: FirestoreParser.string(data, 'username', fallback: ''),
    displayName: FirestoreParser.string(
      data,
      'displayName',
      fallback: 'Athlete',
    ),
    avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
    isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
    verificationType: FirestoreParser.nullableString(data, 'verificationType'),
  );

  final String uid;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final String? verificationType;

  FirestoreMap toMap() => <String, Object?>{
    'uid': uid,
    'username': username,
    'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'isVerified': isVerified,
    if (verificationType != null) 'verificationType': verificationType,
  };
}

class MarketplaceListingDto {
  const MarketplaceListingDto({
    required this.id,
    required this.sellerId,
    required this.seller,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.sportId,
    required this.condition,
    required this.price,
    required this.media,
    required this.location,
    required this.deliveryOptions,
    required this.status,
    required this.favoriteCount,
    required this.viewCount,
    required this.conversationCount,
    required this.isNegotiable,
    required this.isFavorited,
    required this.moderationState,
    required this.audit,
    this.distanceKm,
    this.publishedAt,
    this.expiresAt,
    this.reservedAt,
    this.soldAt,
    this.rejectionReason,
  });

  factory MarketplaceListingDto.fromMap(String id, FirestoreMap data) {
    return MarketplaceListingDto(
      id: id,
      sellerId: FirestoreParser.string(data, 'sellerId'),
      seller: SellerSnapshotDto.fromMap(FirestoreParser.map(data, 'seller')),
      title: FirestoreParser.string(data, 'title'),
      description: FirestoreParser.string(data, 'description'),
      categoryId: FirestoreParser.string(data, 'categoryId'),
      sportId: FirestoreParser.string(data, 'sportId'),
      condition: FirestoreParser.string(data, 'condition'),
      price: MoneyDto.fromMap(FirestoreParser.map(data, 'price')),
      media: FirestoreParser.mapList(
        data,
        'media',
      ).map(MediaAssetDto.fromMap).toList(growable: false),
      location: GeoLocationDto.fromMap(data),
      deliveryOptions: FirestoreParser.stringList(data, 'deliveryOptions'),
      status: FirestoreParser.string(data, 'status'),
      favoriteCount: FirestoreParser.integer(
        data,
        'favoriteCount',
        fallback: 0,
      ),
      viewCount: FirestoreParser.integer(data, 'viewCount', fallback: 0),
      conversationCount: FirestoreParser.integer(
        data,
        'conversationCount',
        fallback: 0,
      ),
      isNegotiable: FirestoreParser.boolean(
        data,
        'isNegotiable',
        fallback: false,
      ),
      isFavorited: FirestoreParser.boolean(
        data,
        'isFavorited',
        fallback: false,
      ),
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      audit: EntityAuditDto.fromMap(data),
      distanceKm: data['distanceKm'] is num
          ? (data['distanceKm'] as num).toDouble()
          : null,
      publishedAt: FirestoreParser.nullableDateTime(data, 'publishedAt'),
      expiresAt: FirestoreParser.nullableDateTime(data, 'expiresAt'),
      reservedAt: FirestoreParser.nullableDateTime(data, 'reservedAt'),
      soldAt: FirestoreParser.nullableDateTime(data, 'soldAt'),
      rejectionReason: FirestoreParser.nullableString(data, 'rejectionReason'),
    );
  }

  factory MarketplaceListingDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Listing ${snapshot.id} has no data.');
    }
    return MarketplaceListingDto.fromMap(snapshot.id, data);
  }

  final String id;
  final String sellerId;
  final SellerSnapshotDto seller;
  final String title;
  final String description;
  final String categoryId;
  final String sportId;
  final String condition;
  final MoneyDto price;
  final List<MediaAssetDto> media;
  final GeoLocationDto location;
  final List<String> deliveryOptions;
  final String status;
  final int favoriteCount;
  final int viewCount;
  final int conversationCount;
  final bool isNegotiable;
  final bool isFavorited;
  final String moderationState;
  final EntityAuditDto audit;
  final double? distanceKm;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? reservedAt;
  final DateTime? soldAt;
  final String? rejectionReason;

  FirestoreMap toFirestore([SetOptions? _]) => <String, Object?>{
    'sellerId': sellerId,
    'seller': seller.toMap(),
    'title': title,
    'description': description,
    'categoryId': categoryId,
    'sportId': sportId,
    'condition': condition,
    'price': price.toMap(),
    'media': media.map((MediaAssetDto item) => item.toMap()).toList(),
    ...location.toMap(),
    'deliveryOptions': deliveryOptions,
    'status': status,
    'favoriteCount': favoriteCount,
    'viewCount': viewCount,
    'conversationCount': conversationCount,
    'isNegotiable': isNegotiable,
    'moderationState': moderationState,
    if (publishedAt != null)
      'publishedAt': Timestamp.fromDate(publishedAt!.toUtc()),
    if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!.toUtc()),
    if (reservedAt != null)
      'reservedAt': Timestamp.fromDate(reservedAt!.toUtc()),
    if (soldAt != null) 'soldAt': Timestamp.fromDate(soldAt!.toUtc()),
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
    ...audit.toMap(),
  };
}
