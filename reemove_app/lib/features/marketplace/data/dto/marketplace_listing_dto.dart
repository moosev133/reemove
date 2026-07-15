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
  });

  factory SellerSnapshotDto.fromMap(FirestoreMap data) => SellerSnapshotDto(
    uid: FirestoreParser.string(data, 'uid'),
    username: FirestoreParser.string(data, 'username'),
    displayName: FirestoreParser.string(data, 'displayName'),
    avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
    isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
  );

  final String uid;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  FirestoreMap toMap() => <String, Object?>{
    'uid': uid,
    'username': username,
    'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'isVerified': isVerified,
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
    required this.moderationState,
    required this.audit,
  });

  factory MarketplaceListingDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Listing ${snapshot.id} has no data.');
    }
    return MarketplaceListingDto(
      id: snapshot.id,
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
      moderationState: FirestoreParser.string(
        data,
        'moderationState',
        fallback: 'active',
      ),
      audit: EntityAuditDto.fromMap(data),
    );
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
  final String moderationState;
  final EntityAuditDto audit;

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
    'moderationState': moderationState,
    ...audit.toMap(),
  };
}
