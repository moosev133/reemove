import '../../../../../core/domain/entities/entity_audit.dart';
import '../../../../../core/domain/value_objects/money.dart';

enum TrainerServiceType {
  personalTraining,
  groupSession,
  program,
  consultation,
  clinic,
}

enum TrainerDeliveryMode { inPerson, online, hybrid }

class SportTrainer {
  const SportTrainer({
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
  final EntityAudit audit;
  final String? avatarUrl;
  final String? headline;
  final Money? minimumPrice;
}

class TrainerService {
  const TrainerService({
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

  final String id;
  final String trainerId;
  final String sportId;
  final String title;
  final String description;
  final TrainerServiceType type;
  final TrainerDeliveryMode deliveryMode;
  final int durationMinutes;
  final Money price;
  final bool isActive;
  final EntityAudit audit;
}
