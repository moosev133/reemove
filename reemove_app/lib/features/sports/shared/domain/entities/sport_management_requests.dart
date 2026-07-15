import '../../../../../core/domain/value_objects/geo_location.dart';
import '../../../../../core/domain/value_objects/money.dart';
import 'sport_community.dart';
import 'sport_trainer.dart';
import 'sports_event.dart';

class CreateSportCommunityRequest {
  const CreateSportCommunityRequest({
    required this.sportId,
    required this.name,
    required this.description,
    required this.type,
    required this.joinPolicy,
    required this.capacity,
    required this.tags,
    required this.city,
    required this.countryCode,
    this.pricingText,
  });

  final String sportId;
  final String name;
  final String description;
  final SportCommunityType type;
  final SportCommunityJoinPolicy joinPolicy;
  final int capacity;
  final List<String> tags;
  final String city;
  final String countryCode;
  final String? pricingText;
}

class CreateSportsEventRequest {
  const CreateSportsEventRequest({
    required this.sportId,
    required this.type,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.timezone,
    required this.location,
    required this.capacity,
    required this.minimumLevel,
    required this.maximumLevel,
    this.placeId,
    this.price,
  });

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
  final String minimumLevel;
  final String maximumLevel;
  final Money? price;
}

class UpsertTrainerServiceRequest {
  const UpsertTrainerServiceRequest({
    required this.sportId,
    required this.title,
    required this.description,
    required this.type,
    required this.deliveryMode,
    required this.durationMinutes,
    required this.price,
    this.serviceId,
  });

  final String? serviceId;
  final String sportId;
  final String title;
  final String description;
  final TrainerServiceType type;
  final TrainerDeliveryMode deliveryMode;
  final int durationMinutes;
  final Money price;
}
