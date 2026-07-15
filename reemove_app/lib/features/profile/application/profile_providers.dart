import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/result/result.dart';
import '../../authentication/application/authentication_providers.dart';
import '../../authentication/domain/entities/auth_user.dart';
import '../../feed/application/feed_providers.dart';
import '../data/repositories/firebase_profile_content_repository.dart';
import '../data/repositories/firebase_profile_image_repository.dart';
import '../data/repositories/firebase_profile_settings_repository.dart';
import '../data/repositories/firebase_profile_social_repository.dart';
import '../data/repositories/firebase_verification_evidence_repository.dart';
import '../data/repositories/firebase_verification_repository.dart';
import '../data/services/platform_profile_image_picker.dart';
import '../domain/entities/blocked_profile.dart';
import '../domain/entities/profile_connection.dart';
import '../domain/entities/profile_content_page.dart';
import '../domain/entities/profile_edit_request.dart';
import '../domain/entities/profile_privacy_settings.dart';
import '../domain/entities/profile_relationship.dart';
import '../domain/entities/user_profile.dart';
import '../domain/entities/verification_request.dart';
import '../domain/repositories/profile_content_repository.dart';
import '../domain/repositories/profile_image_repository.dart';
import '../domain/repositories/profile_settings_repository.dart';
import '../domain/repositories/profile_social_repository.dart';
import '../domain/repositories/verification_evidence_repository.dart';
import '../domain/repositories/verification_repository.dart';
import '../domain/services/profile_image_picker.dart';

final Provider<ProfileImageRepository> profileImageRepositoryProvider =
    Provider<ProfileImageRepository>((Ref ref) {
      return FirebaseProfileImageRepository(ref.watch(firebaseStorageProvider));
    });

final Provider<ProfileImagePicker> profileImagePickerProvider =
    Provider<ProfileImagePicker>((Ref ref) {
      return PlatformProfileImagePicker();
    });

final Provider<ProfileSocialRepository> profileSocialRepositoryProvider =
    Provider<ProfileSocialRepository>((Ref ref) {
      return FirebaseProfileSocialRepository(
        ref.watch(firebaseFunctionsProvider),
      );
    });

final Provider<ProfileSettingsRepository> profileSettingsRepositoryProvider =
    Provider<ProfileSettingsRepository>((Ref ref) {
      return FirebaseProfileSettingsRepository(
        auth: ref.watch(firebaseAuthProvider),
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
      );
    });

final Provider<ProfileContentRepository> profileContentRepositoryProvider =
    Provider<ProfileContentRepository>((Ref ref) {
      return FirebaseProfileContentRepository(
        ref.watch(firebaseFunctionsProvider),
      );
    });

final Provider<VerificationEvidenceRepository>
verificationEvidenceRepositoryProvider =
    Provider<VerificationEvidenceRepository>((Ref ref) {
      return FirebaseVerificationEvidenceRepository(
        ref.watch(firebaseStorageProvider),
      );
    });

final Provider<VerificationRepository> verificationRepositoryProvider =
    Provider<VerificationRepository>((Ref ref) {
      return FirebaseVerificationRepository(
        auth: ref.watch(firebaseAuthProvider),
        firestore: ref.watch(firebaseFirestoreProvider),
        functions: ref.watch(firebaseFunctionsProvider),
      );
    });

final publicProfileByUsernameProvider =
    FutureProvider.family<UserProfile?, String>((
      Ref ref,
      String username,
    ) async {
      final Result<UserProfile?> result = await ref
          .watch(profileSocialRepositoryProvider)
          .getVisibleProfileByUsername(username);
      return _value(result);
    });

final publicProfileByIdProvider = FutureProvider.family<UserProfile?, String>((
  Ref ref,
  String uid,
) async {
  final Result<UserProfile?> result = await ref
      .watch(profileSocialRepositoryProvider)
      .getVisibleProfileById(uid);
  return _value(result);
});

final profileRelationshipProvider =
    FutureProvider.family<ProfileRelationship, String>((
      Ref ref,
      String profileId,
    ) async {
      final Result<ProfileRelationship> result = await ref
          .watch(profileSocialRepositoryProvider)
          .getRelationship(profileId);
      return _value(result);
    });

final StreamProvider<ProfilePrivacySettings> profilePrivacySettingsProvider =
    StreamProvider<ProfilePrivacySettings>((Ref ref) async* {
      await for (final Result<ProfilePrivacySettings> result
          in ref
              .watch(profileSettingsRepositoryProvider)
              .watchPrivacySettings()) {
        yield _value(result);
      }
    });

final StreamProvider<VerificationRequest?> currentVerificationRequestProvider =
    StreamProvider<VerificationRequest?>((Ref ref) async* {
      await for (final Result<VerificationRequest?> result
          in ref.watch(verificationRepositoryProvider).watchCurrent()) {
        yield _value(result);
      }
    });

class ProfileContentQuery {
  const ProfileContentQuery({
    required this.profileId,
    required this.filter,
    this.cursor,
  });

  final String profileId;
  final ProfileContentFilter filter;
  final ProfileContentCursor? cursor;

  @override
  bool operator ==(Object other) =>
      other is ProfileContentQuery &&
      other.profileId == profileId &&
      other.filter == filter &&
      other.cursor?.documentId == cursor?.documentId;

  @override
  int get hashCode => Object.hash(profileId, filter, cursor?.documentId);
}

final profileContentPageProvider =
    FutureProvider.family<ProfileContentPage, ProfileContentQuery>((
      Ref ref,
      ProfileContentQuery query,
    ) async {
      final AuthUser? viewer = await ref.watch(currentAuthUserProvider.future);
      if (viewer == null) {
        return const ProfileContentPage(items: <Never>[], hasMore: false);
      }
      final Result<ProfileContentPage> result = await ref
          .watch(profileContentRepositoryProvider)
          .load(
            profileId: query.profileId,
            viewerId: viewer.uid,
            filter: query.filter,
            cursor: query.cursor,
          );
      return _value(result);
    });

class ProfileConnectionsQuery {
  const ProfileConnectionsQuery({
    required this.profileId,
    required this.type,
    this.cursor,
  });

  final String profileId;
  final ProfileConnectionType type;
  final ProfileConnectionCursor? cursor;

  @override
  bool operator ==(Object other) =>
      other is ProfileConnectionsQuery &&
      other.profileId == profileId &&
      other.type == type &&
      other.cursor?.documentId == cursor?.documentId;

  @override
  int get hashCode => Object.hash(profileId, type, cursor?.documentId);
}

final profileConnectionsProvider =
    FutureProvider.family<ProfileConnectionPage, ProfileConnectionsQuery>((
      Ref ref,
      ProfileConnectionsQuery query,
    ) async {
      final Result<ProfileConnectionPage> result = await ref
          .watch(profileSocialRepositoryProvider)
          .listConnections(
            profileId: query.profileId,
            type: query.type,
            cursor: query.cursor,
          );
      return _value(result);
    });

final FutureProvider<List<BlockedProfile>> blockedProfilesProvider =
    FutureProvider<List<BlockedProfile>>((Ref ref) async {
      final Result<List<BlockedProfile>> result = await ref
          .watch(profileSocialRepositoryProvider)
          .listBlockedProfiles();
      return _value(result);
    });

final NotifierProvider<ProfileActionController, AsyncValue<void>>
profileActionControllerProvider =
    NotifierProvider<ProfileActionController, AsyncValue<void>>(
      ProfileActionController.new,
    );

class ProfileActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  Future<bool> follow(String profileId) => _relationshipMutation(
    profileId,
    () => ref.read(profileSocialRepositoryProvider).follow(profileId),
  );

  Future<bool> unfollow(String profileId) => _relationshipMutation(
    profileId,
    () => ref.read(profileSocialRepositoryProvider).unfollow(profileId),
  );

  Future<bool> acceptRequest(String requesterId) => _relationshipMutation(
    requesterId,
    () => ref.read(profileSocialRepositoryProvider).acceptRequest(requesterId),
  );

  Future<bool> declineRequest(String requesterId) => _relationshipMutation(
    requesterId,
    () => ref.read(profileSocialRepositoryProvider).declineRequest(requesterId),
  );

  Future<bool> cancelRequest(String profileId) => _relationshipMutation(
    profileId,
    () => ref.read(profileSocialRepositoryProvider).cancelRequest(profileId),
  );

  Future<bool> removeFollower(String followerId) => _run(
    () => ref.read(profileSocialRepositoryProvider).removeFollower(followerId),
    onSuccess: () {
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(profileConnectionsProvider);
    },
  );

  Future<bool> block(String profileId) => _run(
    () => ref.read(profileSocialRepositoryProvider).block(profileId),
    onSuccess: () {
      ref.invalidate(blockedProfilesProvider);
      ref.invalidate(profileRelationshipProvider);
      ref.invalidate(feedControllerProvider);
    },
  );

  Future<bool> unblock(String profileId) => _run(
    () => ref.read(profileSocialRepositoryProvider).unblock(profileId),
    onSuccess: () {
      ref.invalidate(blockedProfilesProvider);
      ref.invalidate(profileRelationshipProvider);
      ref.invalidate(feedControllerProvider);
    },
  );

  Future<bool> updateProfile(ProfileEditRequest request) => _run(
    () => ref.read(profileSettingsRepositoryProvider).updateProfile(request),
    onSuccess: () {
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(publicProfileByIdProvider);
      ref.invalidate(publicProfileByUsernameProvider);
      ref.invalidate(profilePrivacySettingsProvider);
    },
  );

  Future<bool> updatePrivacy(ProfilePrivacySettings settings) => _run(
    () => ref.read(profileSettingsRepositoryProvider).updatePrivacy(settings),
    onSuccess: () {
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(profilePrivacySettingsProvider);
    },
  );

  Future<bool> submitVerification(VerificationSubmission submission) => _run(
    () => ref.read(verificationRepositoryProvider).submit(submission),
    onSuccess: () {
      ref.invalidate(currentVerificationRequestProvider);
    },
  );

  Future<bool> cancelVerification(String requestId) => _run(
    () => ref.read(verificationRepositoryProvider).cancel(requestId),
    onSuccess: () {
      ref.invalidate(currentVerificationRequestProvider);
    },
  );

  Future<bool> _relationshipMutation(
    String profileId,
    Future<Result<ProfileRelationship>> Function() operation,
  ) async {
    state = const AsyncValue<void>.loading();
    final Result<ProfileRelationship> result = await operation();
    return result.when<bool>(
      success: (ProfileRelationship value) {
        state = const AsyncValue<void>.data(null);
        ref.invalidate(profileRelationshipProvider(profileId));
        ref.invalidate(publicProfileByIdProvider(profileId));
        ref.invalidate(currentUserProfileProvider);
        ref.invalidate(profileConnectionsProvider);
        return true;
      },
      failure: (Failure failure) {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> _run<T>(
    Future<Result<T>> Function() operation, {
    void Function()? onSuccess,
  }) async {
    state = const AsyncValue<void>.loading();
    final Result<T> result = await operation();
    return result.when<bool>(
      success: (T value) {
        state = const AsyncValue<void>.data(null);
        onSuccess?.call();
        return true;
      },
      failure: (Failure failure) {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
  }
}

T _value<T>(Result<T> result) => result.when<T>(
  success: (T value) => value,
  failure: (Failure failure) => throw StateError(failure.message),
);
