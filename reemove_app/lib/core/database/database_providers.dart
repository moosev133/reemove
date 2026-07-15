import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/repositories/firebase_user_profile_repository.dart';
import '../../features/profile/domain/repositories/user_profile_repository.dart';
import '../../features/settings/data/repositories/firebase_app_configuration_repository.dart';
import '../../features/settings/domain/repositories/app_configuration_repository.dart';
import '../../features/sports/shared/data/repositories/firebase_sports_catalog_repository.dart';
import '../../features/sports/shared/domain/repositories/sports_catalog_repository.dart';
import '../firebase/firebase_providers.dart';
import 'reemove_firestore.dart';

export '../firebase/firebase_providers.dart' show firebaseFirestoreProvider;

final Provider<ReeMoveFirestore> reeMoveFirestoreProvider =
    Provider<ReeMoveFirestore>((Ref ref) {
      return ReeMoveFirestore(ref.watch(firebaseFirestoreProvider));
    });

final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>((Ref ref) {
      final ReeMoveFirestore database = ref.watch(reeMoveFirestoreProvider);
      return FirebaseUserProfileRepository(users: database.users);
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

final Provider<AppConfigurationRepository> appConfigurationRepositoryProvider =
    Provider<AppConfigurationRepository>((Ref ref) {
      final ReeMoveFirestore database = ref.watch(reeMoveFirestoreProvider);
      return FirebaseAppConfigurationRepository(
        appConfig: database.appConfig,
        featureFlags: database.featureFlags,
      );
    });
