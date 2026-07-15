import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/challenges/data/dto/challenge_dto.dart';
import '../../features/marketplace/data/dto/marketplace_listing_dto.dart';
import '../../features/profile/data/dto/user_profile_dto.dart';
import '../../features/settings/data/dto/app_configuration_dto.dart';
import '../../features/settings/data/dto/feature_flag_dto.dart';
import '../../features/sports/shared/data/dto/sport_definition_dto.dart';
import '../../features/sports/shared/data/dto/sport_place_dto.dart';
import '../../features/sports/shared/data/dto/sports_event_dto.dart';
import '../constants/firestore_paths.dart';

class ReeMoveFirestore {
  const ReeMoveFirestore(this.instance);

  final FirebaseFirestore instance;

  CollectionReference<UserProfileDto> get users => instance
      .collection(FirestoreCollections.users)
      .withConverter<UserProfileDto>(
        fromFirestore: UserProfileDto.fromFirestore,
        toFirestore: (UserProfileDto value, SetOptions? options) =>
            value.toFirestore(options),
      );

  CollectionReference<SportDefinitionDto> get sports => instance
      .collection(FirestoreCollections.sports)
      .withConverter<SportDefinitionDto>(
        fromFirestore: SportDefinitionDto.fromFirestore,
        toFirestore: (SportDefinitionDto value, SetOptions? options) =>
            value.toFirestore(options),
      );

  CollectionReference<SportPlaceDto> get places => instance
      .collection(FirestoreCollections.places)
      .withConverter<SportPlaceDto>(
        fromFirestore: SportPlaceDto.fromFirestore,
        toFirestore: (SportPlaceDto value, SetOptions? options) =>
            value.toFirestore(options),
      );

  CollectionReference<SportsEventDto> get events => instance
      .collection(FirestoreCollections.events)
      .withConverter<SportsEventDto>(
        fromFirestore: SportsEventDto.fromFirestore,
        toFirestore: (SportsEventDto value, SetOptions? options) =>
            value.toFirestore(options),
      );

  CollectionReference<ChallengeDto> get challenges => instance
      .collection(FirestoreCollections.challenges)
      .withConverter<ChallengeDto>(
        fromFirestore: ChallengeDto.fromFirestore,
        toFirestore: (ChallengeDto value, SetOptions? options) =>
            value.toFirestore(options),
      );

  CollectionReference<MarketplaceListingDto> get marketplaceListings => instance
      .collection(FirestoreCollections.marketplaceListings)
      .withConverter<MarketplaceListingDto>(
        fromFirestore: MarketplaceListingDto.fromFirestore,
        toFirestore: (MarketplaceListingDto value, SetOptions? options) =>
            value.toFirestore(options),
      );

  CollectionReference<AppConfigurationDto> get appConfig => instance
      .collection(FirestoreCollections.appConfig)
      .withConverter<AppConfigurationDto>(
        fromFirestore: AppConfigurationDto.fromFirestore,
        toFirestore: (AppConfigurationDto value, SetOptions? options) =>
            value.toFirestore(options),
      );

  CollectionReference<FeatureFlagDto> get featureFlags => instance
      .collection(FirestoreCollections.featureFlags)
      .withConverter<FeatureFlagDto>(
        fromFirestore: FeatureFlagDto.fromFirestore,
        toFirestore: (FeatureFlagDto value, SetOptions? options) =>
            value.toFirestore(options),
      );
}
