import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/profile_edit_request.dart';
import '../../domain/entities/profile_privacy_settings.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_settings_repository.dart';
import '../dto/profile_privacy_settings_dto.dart';
import '../dto/user_profile_dto.dart';
import '../mappers/user_profile_mapper.dart';
import '../services/profile_failure_mapper.dart';

class FirebaseProfileSettingsRepository implements ProfileSettingsRepository {
  const FirebaseProfileSettingsRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _auth = auth,
       _firestore = firestore,
       _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _settingsRef => _firestore
      .collection('users')
      .doc(_requireUid())
      .collection('private')
      .doc('profile_settings');

  @override
  Future<Result<ProfilePrivacySettings>> getPrivacySettings() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _settingsRef
          .get();
      return Success<ProfilePrivacySettings>(
        snapshot.exists
            ? ProfilePrivacySettingsDto.fromMap(
                snapshot.data() ?? const <String, dynamic>{},
              ).toDomain()
            : ProfilePrivacySettings.defaults(),
      );
    } on FirebaseException catch (error) {
      return FailureResult<ProfilePrivacySettings>(
        ProfileFailureMapper.fromFirestore(error),
      );
    } catch (error) {
      return FailureResult<ProfilePrivacySettings>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<ProfilePrivacySettings>> watchPrivacySettings() async* {
    try {
      await for (final DocumentSnapshot<Map<String, dynamic>> snapshot
          in _settingsRef.snapshots()) {
        yield Success<ProfilePrivacySettings>(
          snapshot.exists
              ? ProfilePrivacySettingsDto.fromMap(
                  snapshot.data() ?? const <String, dynamic>{},
                ).toDomain()
              : ProfilePrivacySettings.defaults(),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<ProfilePrivacySettings>(
        ProfileFailureMapper.fromFirestore(error),
      );
    } catch (error) {
      yield FailureResult<ProfilePrivacySettings>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<UserProfile>> updateProfile(ProfileEditRequest request) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('updateProfile')
          .call<dynamic>(<String, Object?>{
            'displayName': request.displayName,
            if (request.username != null) 'username': request.username,
            'bio': request.bio,
            'avatarUrl': request.avatarUrl,
            'avatarStoragePath': request.avatarStoragePath,
            'coverUrl': request.coverUrl,
            'coverStoragePath': request.coverStoragePath,
            'websiteUrl': request.websiteUrl,
            'primarySportId': request.primarySportId,
            'favoriteSportIds': request.favoriteSportIds,
            'goals': request.goals,
            'visibility': request.visibility,
            'professionalDetails': request.professional?.toJson(),
            'privacy': _privacyMap(request.privacy),
          });
      final Map<String, dynamic> data = _map(response.data);
      final Map<String, dynamic> profile = (data['profile'] as Map)
          .cast<String, dynamic>();
      return Success<UserProfile>(
        UserProfileDto.fromMap(profile, documentId: _requireUid()).toDomain(),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<UserProfile>(
        ProfileFailureMapper.fromFunctions(error),
      );
    } catch (error) {
      return FailureResult<UserProfile>(ProfileFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> updatePrivacy(ProfilePrivacySettings settings) async {
    try {
      await _functions.httpsCallable('updateProfilePrivacy').call<dynamic>(
        <String, Object?>{'privacy': _privacyMap(settings)},
      );
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(ProfileFailureMapper.fromFunctions(error));
    } catch (error) {
      return FailureResult<void>(ProfileFailureMapper.unexpected(error));
    }
  }

  String _requireUid() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('A signed-in account is required.');
    }
    return uid;
  }

  static Map<String, Object?> _privacyMap(ProfilePrivacySettings value) =>
      <String, Object?>{
        'followApprovalPolicy': value.followApprovalPolicy.name,
        'messageAudience': value.messageAudience.name,
        'mentionAudience': value.mentionAudience.name,
        'tagAudience': value.tagAudience.name,
        'showActivityStatus': value.showActivityStatus,
        'showSportLevels': value.showSportLevels,
        'showGoals': value.showGoals,
        'showLocation': value.showLocation,
        'followerListAudience': value.followerListAudience.name,
        'showFollowerLists': value.showFollowerLists,
        'hideLikeCounts': value.hideLikeCounts,
        'discoverableByUsername': value.discoverableByUsername,
        'personalizedSuggestions': value.personalizedSuggestions,
      };

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const FormatException('The profile service returned invalid data.');
  }
}
