import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import '../providers/core_providers.dart';
import 'firebase_bootstrap.dart';

/// Shared Firebase SDK accessors for all features.
///
/// Feature modules must not redefine Auth, Firestore, Functions, Storage, or
/// Realtime Database providers. Call sites that run before bootstrap readiness
/// must gate on [FirebaseBootstrapReport.isReady] instead of watching these.
abstract final class FirebaseSdk {
  static void ensureReady(FirebaseBootstrapReport report, String service) {
    if (!report.isReady) {
      throw StateError(
        '$service is unavailable because Firebase failed to initialize.',
      );
    }
  }

  /// Resolves the Realtime Database instance that bootstrap and providers share.
  ///
  /// When emulators are enabled, always use [FirebaseDatabase.instance] so the
  /// emulator binding from bootstrap matches the instance used at runtime.
  static FirebaseDatabase databaseFor(AppEnvironment environment) {
    final String? databaseUrl = environment.firebaseDatabaseUrl;
    if (databaseUrl == null || environment.useFirebaseEmulators) {
      return FirebaseDatabase.instance;
    }
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseUrl,
    );
  }
}

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>((
  Ref ref,
) {
  FirebaseSdk.ensureReady(
    ref.watch(firebaseBootstrapReportProvider),
    'Firebase Authentication',
  );
  return FirebaseAuth.instance;
});

final Provider<FirebaseFirestore> firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) {
      FirebaseSdk.ensureReady(
        ref.watch(firebaseBootstrapReportProvider),
        'Cloud Firestore',
      );
      return FirebaseFirestore.instance;
    });

final Provider<FirebaseFunctions> firebaseFunctionsProvider =
    Provider<FirebaseFunctions>((Ref ref) {
      FirebaseSdk.ensureReady(
        ref.watch(firebaseBootstrapReportProvider),
        'Cloud Functions',
      );
      final AppEnvironment environment = ref.watch(appEnvironmentProvider);
      return FirebaseFunctions.instanceFor(
        region: environment.firebaseFunctionsRegion,
      );
    });

final Provider<FirebaseStorage> firebaseStorageProvider =
    Provider<FirebaseStorage>((Ref ref) {
      FirebaseSdk.ensureReady(
        ref.watch(firebaseBootstrapReportProvider),
        'Firebase Storage',
      );
      return FirebaseStorage.instance;
    });

final Provider<FirebaseDatabase> firebaseDatabaseProvider =
    Provider<FirebaseDatabase>((Ref ref) {
      FirebaseSdk.ensureReady(
        ref.watch(firebaseBootstrapReportProvider),
        'Realtime Database',
      );
      return FirebaseSdk.databaseFor(ref.watch(appEnvironmentProvider));
    });
