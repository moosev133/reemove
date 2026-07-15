import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/challenges/data/repositories/firebase_challenge_repository.dart';
import '../../features/challenges/domain/repositories/challenge_repository.dart';
import '../../features/marketplace/data/repositories/firebase_marketplace_catalog_repository.dart';
import '../../features/marketplace/domain/repositories/marketplace_catalog_repository.dart';
import '../../features/profile/data/repositories/firebase_user_profile_repository.dart';
import '../../features/profile/domain/repositories/user_profile_repository.dart';
import '../../features/settings/data/repositories/firebase_app_configuration_repository.dart';
import '../../features/settings/domain/repositories/app_configuration_repository.dart';
import '../../features/sports/shared/data/repositories/firebase_sports_catalog_repository.dart';
import '../../features/sports/shared/domain/repositories/sports_catalog_repository.dart';
import '../firebase/firebase_bootstrap.dart';
import '../providers/core_providers.dart';
import 'reemove_firestore.dart';

final Provider<FirebaseFirestore>
firebaseFirestoreProvider = Provider<FirebaseFirestore>((Ref ref) {
  final FirebaseBootstrapReport report = ref.watch(
    firebaseBootstrapReportProvider,
  );
  if (!report.isReady) {
    throw StateError(
      'Cloud Firestore is unavailable because Firebase failed to initialize.',
    );
  }
  return FirebaseFirestore.instance;
});

final Provider<ReeMoveFirestore> reeMoveFirestoreProvider =
    Provider<ReeMoveFirestore>((Ref ref) {
      return ReeMoveFirestore(ref.watch(firebaseFirestoreProvider));
    });

final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>((Ref ref) {
      final ReeMoveFirestore database = ref.watch(reeMoveFirestoreProvider);
      return FirebaseUserProfileRepository(
        users: database.users,
        usernames: database.usernames,
      );
    });

final Provider<SportsCatalogRepository> sportsCatalogRepositoryProvider =
    Provider<SportsCatalogRepository>((Ref ref) {
      final ReeMoveFirestore database = ref.watch(reeMoveFirestoreProvider);
      return FirebaseSportsCatalogRepository(
        sports: database.sports,
        places: database.places,
        events: database.events,
      );
    });

final Provider<ChallengeRepository> challengeRepositoryProvider =
    Provider<ChallengeRepository>((Ref ref) {
      return FirebaseChallengeRepository(
        ref.watch(reeMoveFirestoreProvider).challenges,
      );
    });

final Provider<MarketplaceCatalogRepository>
marketplaceCatalogRepositoryProvider = Provider<MarketplaceCatalogRepository>((
  Ref ref,
) {
  return FirebaseMarketplaceCatalogRepository(
    ref.watch(reeMoveFirestoreProvider).marketplaceListings,
  );
});

final Provider<AppConfigurationRepository> appConfigurationRepositoryProvider =
    Provider<AppConfigurationRepository>((Ref ref) {
      final ReeMoveFirestore database = ref.watch(reeMoveFirestoreProvider);
      return FirebaseAppConfigurationRepository(
        appConfig: database.appConfig,
        featureFlags: database.featureFlags,
      );
    });
