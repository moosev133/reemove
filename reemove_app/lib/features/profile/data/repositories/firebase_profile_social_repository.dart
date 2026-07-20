import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../core/result/result.dart';
import '../../domain/entities/blocked_profile.dart';
import '../../domain/entities/profile_connection.dart';
import '../../domain/entities/profile_relationship.dart';
import '../../domain/entities/profile_surface.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_social_repository.dart';
import '../dto/user_profile_dto.dart';
import '../mappers/user_profile_mapper.dart';
import '../services/profile_failure_mapper.dart';

class FirebaseProfileSocialRepository implements ProfileSocialRepository {
  const FirebaseProfileSocialRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Result<UserProfile?>> getVisibleProfileByUsername(
    String username,
  ) async {
    final Result<ProfileSurface> surface = await getProfileSurfaceByUsername(
      username,
    );
    return surface.when<Result<UserProfile?>>(
      success: (ProfileSurface value) => Success<UserProfile?>(value.profile),
      failure: (failure) => FailureResult<UserProfile?>(failure),
    );
  }

  @override
  Future<Result<UserProfile?>> getVisibleProfileById(String profileId) async {
    final Result<ProfileSurface> surface = await getProfileSurfaceById(
      profileId,
    );
    return surface.when<Result<UserProfile?>>(
      success: (ProfileSurface value) => Success<UserProfile?>(value.profile),
      failure: (failure) => FailureResult<UserProfile?>(failure),
    );
  }

  @override
  Future<Result<ProfileSurface>> getProfileSurfaceByUsername(String username) =>
      _surfaceCall(<String, Object?>{'username': username});

  @override
  Future<Result<ProfileSurface>> getProfileSurfaceById(String profileId) =>
      _surfaceCall(<String, Object?>{'profileId': profileId});

  @override
  Future<Result<ProfileRelationship>> getRelationship(String profileId) =>
      _relationshipCall('getProfileRelationship', profileId);

  @override
  Future<Result<ProfileRelationship>> follow(String profileId) =>
      _relationshipCall('followProfile', profileId);

  @override
  Future<Result<ProfileRelationship>> unfollow(String profileId) =>
      _relationshipCall('unfollowProfile', profileId);

  @override
  Future<Result<ProfileRelationship>> acceptRequest(String requesterId) =>
      _relationshipCall(
        'respondToFollowRequest',
        requesterId,
        extra: const <String, Object?>{'response': 'accept'},
      );

  @override
  Future<Result<ProfileRelationship>> declineRequest(String requesterId) =>
      _relationshipCall(
        'respondToFollowRequest',
        requesterId,
        extra: const <String, Object?>{'response': 'decline'},
      );

  @override
  Future<Result<ProfileRelationship>> cancelRequest(String profileId) =>
      _relationshipCall('cancelFollowRequest', profileId);

  @override
  Future<Result<void>> removeFollower(String followerId) =>
      _voidCall('removeFollower', <String, Object?>{'profileId': followerId});

  @override
  Future<Result<ProfileConnectionPage>> listConnections({
    required String profileId,
    required ProfileConnectionType type,
    ProfileConnectionCursor? cursor,
    int limit = 30,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('listProfileConnections')
          .call<dynamic>(<String, Object?>{
            'profileId': profileId,
            'type': type.name,
            'limit': limit,
            if (cursor != null) ...<String, Object?>{
              'cursorId': cursor.documentId,
              'cursorAt': cursor.createdAt.toUtc().toIso8601String(),
            },
          });
      final Map<String, dynamic> data = _map(response.data);
      final List<UserProfile>
      items = (data['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> item) {
            final Map<String, dynamic> map = Map<String, dynamic>.from(item);
            final String id = map['uid'] is String ? map['uid'] as String : '';
            return UserProfileDto.fromMap(map, documentId: id).toDomain();
          })
          .where((UserProfile profile) => profile.uid.isNotEmpty)
          .toList(growable: false);
      final Map<String, dynamic>? cursorMap = data['nextCursor'] is Map
          ? (data['nextCursor'] as Map).cast<String, dynamic>()
          : null;
      return Success<ProfileConnectionPage>(
        ProfileConnectionPage(
          items: items,
          hasMore: data['hasMore'] == true,
          nextCursor: cursorMap == null
              ? null
              : ProfileConnectionCursor(
                  documentId: cursorMap['documentId'] as String,
                  createdAt: DateTime.parse(
                    cursorMap['createdAt'] as String,
                  ).toUtc(),
                ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<ProfileConnectionPage>(
        ProfileFailureMapper.fromFunctions(error),
      );
    } catch (error) {
      return FailureResult<ProfileConnectionPage>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<List<BlockedProfile>>> listBlockedProfiles({
    int limit = 100,
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('listBlockedProfiles')
          .call<dynamic>(<String, Object?>{'limit': limit});
      final Map<String, dynamic> data = _map(response.data);
      final List<BlockedProfile> items =
          (data['items'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<Object?, Object?>>()
              .map((Map<Object?, Object?> item) {
                final Map<String, dynamic> map = Map<String, dynamic>.from(
                  item,
                );
                final Map<String, dynamic> profileMap =
                    Map<String, dynamic>.from(map['profile'] as Map);
                final String uid = profileMap['uid'] as String;
                return BlockedProfile(
                  profile: UserProfileDto.fromMap(
                    profileMap,
                    documentId: uid,
                  ).toDomain(),
                  blockedAt: DateTime.parse(map['blockedAt'] as String).toUtc(),
                );
              })
              .toList(growable: false);
      return Success<List<BlockedProfile>>(items);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<List<BlockedProfile>>(
        ProfileFailureMapper.fromFunctions(error),
      );
    } catch (error) {
      return FailureResult<List<BlockedProfile>>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> block(String profileId) =>
      _voidCall('blockUser', <String, Object?>{'targetUserId': profileId});

  @override
  Future<Result<void>> unblock(String profileId) =>
      _voidCall('unblockUser', <String, Object?>{'profileId': profileId});

  Future<Result<ProfileSurface>> _surfaceCall(Map<String, Object?> data) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable('getPublicProfile')
          .call<dynamic>(data);
      final Map<String, dynamic> payload = _map(response.data);
      final ProfileRelationship relationship = payload['relationship'] is Map
          ? _relationship(
              (payload['relationship'] as Map).cast<String, dynamic>(),
            )
          : ProfileRelationship(
              viewerId: '',
              profileId: '',
              state: FollowRelationshipState.none,
              canMessage: false,
              canViewFollowers: false,
              canViewProfile: false,
            );
      final String access = payload['access'] is String
          ? payload['access'] as String
          : (payload['profile'] is Map ? 'full' : 'unavailable');
      final Map<String, dynamic>? profileMap = switch (access) {
        'full' when payload['profile'] is Map =>
          (payload['profile'] as Map).cast<String, dynamic>(),
        'preview' when payload['preview'] is Map =>
          (payload['preview'] as Map).cast<String, dynamic>(),
        'preview' when payload['profile'] is Map =>
          (payload['profile'] as Map).cast<String, dynamic>(),
        _ => null,
      };
      UserProfile? profile;
      if (profileMap != null) {
        final String uid = profileMap['uid'] is String
            ? profileMap['uid'] as String
            : '';
        if (uid.isNotEmpty) {
          profile = UserProfileDto.fromMap(
            profileMap,
            documentId: uid,
          ).toDomain();
        }
      }
      return Success<ProfileSurface>(
        ProfileSurface(
          access: ProfileAccessLevel.values.byName(access),
          profile: profile,
          relationship: relationship,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found' || error.code == 'permission-denied') {
        return Success<ProfileSurface>(
          ProfileSurface(
            access: ProfileAccessLevel.unavailable,
            relationship: ProfileRelationship(
              viewerId: '',
              profileId: '',
              state: FollowRelationshipState.none,
              canMessage: false,
              canViewFollowers: false,
              canViewProfile: false,
            ),
          ),
        );
      }
      return FailureResult<ProfileSurface>(
        ProfileFailureMapper.fromFunctions(error),
      );
    } catch (error) {
      return FailureResult<ProfileSurface>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  Future<Result<ProfileRelationship>> _relationshipCall(
    String name,
    String profileId, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable(name)
          .call<dynamic>(<String, Object?>{'profileId': profileId, ...extra});
      return Success<ProfileRelationship>(_relationship(_map(response.data)));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<ProfileRelationship>(
        ProfileFailureMapper.fromFunctions(error),
      );
    } catch (error) {
      return FailureResult<ProfileRelationship>(
        ProfileFailureMapper.unexpected(error),
      );
    }
  }

  Future<Result<void>> _voidCall(String name, Map<String, Object?> data) async {
    try {
      await _functions.httpsCallable(name).call<dynamic>(data);
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(ProfileFailureMapper.fromFunctions(error));
    } catch (error) {
      return FailureResult<void>(ProfileFailureMapper.unexpected(error));
    }
  }

  static ProfileRelationship _relationship(Map<String, dynamic> data) =>
      ProfileRelationship(
        viewerId: data['viewerId'] as String,
        profileId: data['profileId'] as String,
        state: FollowRelationshipState.values.byName(data['state'] as String),
        canMessage: data['canMessage'] == true,
        canViewFollowers: data['canViewFollowers'] == true,
        canViewProfile: data['canViewProfile'] != false,
        requestedAt: data['requestedAt'] is String
            ? DateTime.parse(data['requestedAt'] as String).toUtc()
            : null,
      );

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
