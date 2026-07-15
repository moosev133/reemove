import '../../domain/entities/sport_trainer.dart';
import '../dto/sport_trainer_dto.dart';

extension SportTrainerDtoMapper on SportTrainerDto {
  SportTrainer toDomain() => SportTrainer(
    id: id,
    userId: userId,
    displayName: displayName,
    username: username,
    bio: bio,
    sportIds: sportIds,
    specialties: specialties,
    yearsExperience: yearsExperience,
    rating: rating,
    reviewCount: reviewCount,
    city: city,
    countryCode: countryCode,
    acceptingClients: acceptingClients,
    isVerified: isVerified,
    audit: audit.toDomain(),
    avatarUrl: avatarUrl,
    headline: headline,
    minimumPrice: minimumPrice?.toDomain(),
  );
}

extension TrainerServiceDtoMapper on TrainerServiceDto {
  TrainerService toDomain() => TrainerService(
    id: id,
    trainerId: trainerId,
    sportId: sportId,
    title: title,
    description: description,
    type: TrainerServiceType.values.byName(type),
    deliveryMode: TrainerDeliveryMode.values.byName(deliveryMode),
    durationMinutes: durationMinutes,
    price: price.toDomain(),
    isActive: isActive,
    audit: audit.toDomain(),
  );
}
