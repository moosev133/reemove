import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/database/dto/entity_audit_dto.dart';
import '../../../../../core/database/dto/money_dto.dart';
import '../../../../../core/database/firestore_parser.dart';

class SportTrainerDto {
  const SportTrainerDto({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.sportIds,
    required this.specialties,
    required this.yearsExperience,
    required this.rating,
    required this.reviewCount,
    required this.city,
    required this.countryCode,
    required this.acceptingClients,
    required this.isVerified,
    required this.audit,
    this.avatarUrl,
    this.headline,
    this.minimumPrice,
  });

  factory SportTrainerDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Trainer ${snapshot.id} has no data.');
    }
    final Object? price = data['minimumPrice'];
    return SportTrainerDto(
      id: snapshot.id,
      userId: FirestoreParser.string(data, 'userId', fallback: snapshot.id),
      displayName: FirestoreParser.string(data, 'displayName'),
      username: FirestoreParser.string(data, 'username'),
      bio: FirestoreParser.string(data, 'bio', fallback: ''),
      sportIds: FirestoreParser.stringList(data, 'sportIds'),
      specialties: FirestoreParser.stringList(data, 'specialties'),
      yearsExperience: FirestoreParser.integer(
        data,
        'yearsExperience',
        fallback: 0,
      ),
      rating: FirestoreParser.number(data, 'rating', fallback: 0),
      reviewCount: FirestoreParser.integer(data, 'reviewCount', fallback: 0),
      city: FirestoreParser.string(data, 'city', fallback: ''),
      countryCode: FirestoreParser.string(data, 'countryCode', fallback: ''),
      acceptingClients: FirestoreParser.boolean(
        data,
        'acceptingClients',
        fallback: false,
      ),
      isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
      avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
      headline: FirestoreParser.nullableString(data, 'headline'),
      minimumPrice: price is Map
          ? MoneyDto.fromMap(price.cast<String, Object?>())
          : null,
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String userId;
  final String displayName;
  final String username;
  final String bio;
  final List<String> sportIds;
  final List<String> specialties;
  final int yearsExperience;
  final double rating;
  final int reviewCount;
  final String city;
  final String countryCode;
  final bool acceptingClients;
  final bool isVerified;
  final String? avatarUrl;
  final String? headline;
  final MoneyDto? minimumPrice;
  final EntityAuditDto audit;
}

class TrainerServiceDto {
  const TrainerServiceDto({
    required this.id,
    required this.trainerId,
    required this.sportId,
    required this.title,
    required this.description,
    required this.type,
    required this.deliveryMode,
    required this.durationMinutes,
    required this.price,
    required this.isActive,
    required this.audit,
  });

  factory TrainerServiceDto.fromFirestore(
    DocumentSnapshot<FirestoreMap> snapshot,
    SnapshotOptions? _,
  ) {
    final FirestoreMap? data = snapshot.data();
    if (data == null) {
      throw FormatException('Trainer service ${snapshot.id} has no data.');
    }
    return TrainerServiceDto(
      id: snapshot.id,
      trainerId: FirestoreParser.string(data, 'trainerId'),
      sportId: FirestoreParser.string(data, 'sportId'),
      title: FirestoreParser.string(data, 'title'),
      description: FirestoreParser.string(data, 'description', fallback: ''),
      type: FirestoreParser.string(data, 'type', fallback: 'personalTraining'),
      deliveryMode: FirestoreParser.string(
        data,
        'deliveryMode',
        fallback: 'inPerson',
      ),
      durationMinutes: FirestoreParser.integer(
        data,
        'durationMinutes',
        fallback: 60,
      ),
      price: MoneyDto.fromMap(FirestoreParser.map(data, 'price')),
      isActive: FirestoreParser.boolean(data, 'isActive', fallback: true),
      audit: EntityAuditDto.fromMap(data),
    );
  }

  final String id;
  final String trainerId;
  final String sportId;
  final String title;
  final String description;
  final String type;
  final String deliveryMode;
  final int durationMinutes;
  final MoneyDto price;
  final bool isActive;
  final EntityAuditDto audit;
}
