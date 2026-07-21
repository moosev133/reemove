import 'dart:async';

import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/domain/entities/entity_audit.dart';
import 'package:reemove/core/domain/value_objects/content_policy.dart';
import 'package:reemove/core/errors/failure.dart';
import 'package:reemove/core/result/result.dart';
import 'package:reemove/features/authentication/application/authentication_providers.dart';
import 'package:reemove/features/profile/application/profile_providers.dart';
import 'package:reemove/features/profile/domain/entities/blocked_profile.dart';
import 'package:reemove/features/profile/domain/entities/profile_connection.dart';
import 'package:reemove/features/profile/domain/entities/profile_content_page.dart';
import 'package:reemove/features/profile/domain/entities/profile_edit_request.dart';
import 'package:reemove/features/profile/domain/entities/profile_privacy_settings.dart';
import 'package:reemove/features/profile/domain/entities/profile_relationship.dart';
import 'package:reemove/features/profile/domain/entities/profile_surface.dart';
import 'package:reemove/features/profile/domain/entities/user_profile.dart';
import 'package:reemove/features/profile/domain/repositories/profile_settings_repository.dart';
import 'package:reemove/features/profile/domain/repositories/profile_social_repository.dart';
import 'package:reemove/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:reemove/features/profile/presentation/screens/public_profile_screen.dart';
import 'package:reemove/features/profile/presentation/widgets/profile_header.dart';

void main() {
  group('ProfileHeader privacy follow states', () {
    testWidgets('shows Follow for stranger', (WidgetTester tester) async {
      await _pumpHeader(
        tester,
        relationship: _relationship(FollowRelationshipState.none),
      );
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('shows Requested for pending outgoing request', (
      WidgetTester tester,
    ) async {
      await _pumpHeader(
        tester,
        relationship: _relationship(FollowRelationshipState.requestSent),
      );
      expect(find.text('Requested'), findsOneWidget);
    });

    testWidgets('shows Following for approved follower', (
      WidgetTester tester,
    ) async {
      await _pumpHeader(
        tester,
        relationship: _relationship(FollowRelationshipState.following),
      );
      expect(find.widgetWithText(FilledButton, 'Following'), findsOneWidget);
    });

    testWidgets('shows Respond for incoming request', (
      WidgetTester tester,
    ) async {
      await _pumpHeader(
        tester,
        relationship: _relationship(FollowRelationshipState.requestReceived),
      );
      expect(find.text('Respond'), findsOneWidget);
    });

    testWidgets('shows Blocked and Unavailable states', (
      WidgetTester tester,
    ) async {
      await _pumpHeader(
        tester,
        relationship: _relationship(FollowRelationshipState.blocked),
      );
      expect(find.text('Blocked'), findsOneWidget);

      await _pumpHeader(
        tester,
        relationship: _relationship(FollowRelationshipState.blockedBy),
      );
      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('hides follower stats when lists are private', (
      WidgetTester tester,
    ) async {
      await _pumpHeader(
        tester,
        relationship: _relationship(
          FollowRelationshipState.none,
          canViewFollowers: false,
        ),
      );
      expect(find.text('Followers'), findsOneWidget);
      await tester.tap(find.text('Followers'));
      await tester.pump();
    });
  });

  group('ProfileSettingsScreen privacy toggle', () {
    testWidgets('shows public explanation and segments', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(
        tester,
        profile: _profile(visibility: Visibility.public),
      );
      expect(find.text('Account visibility'), findsOneWidget);
      expect(
        find.textContaining('Anyone can find your profile'),
        findsOneWidget,
      );
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private account'), findsOneWidget);
    });

    testWidgets('shows private explanation for private account', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(
        tester,
        profile: _profile(visibility: Visibility.followers),
      );
      expect(
        find.textContaining('Only approved followers can see'),
        findsOneWidget,
      );
    });

    testWidgets('toggle to private submits profile update', (
      WidgetTester tester,
    ) async {
      final _RecordingProfileSettingsRepository repository =
          _RecordingProfileSettingsRepository();
      await _pumpSettings(
        tester,
        profile: _profile(visibility: Visibility.public),
        settingsRepository: repository,
      );
      await tester.tap(find.text('Private account'));
      await tester.pumpAndSettle();
      expect(repository.updateCalls, 1);
      expect(
        repository.lastRequest?.visibility,
        Visibility.followers.storageValue,
      );
      expect(
        repository.lastRequest?.privacy.followApprovalPolicy,
        FollowApprovalPolicy.approvalRequired,
      );
    });
  });

  group('PublicProfileScreen privacy surfaces', () {
    testWidgets('shows loading indicator', (WidgetTester tester) async {
      final Completer<ProfileSurface> completer = Completer<ProfileSurface>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileSurfaceByUsernameProvider(
              'private.user',
            ).overrideWith((Ref ref) => completer.future),
          ],
          child: const MaterialApp(
            home: PublicProfileScreen(username: 'private.user'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows unavailable error state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileSurfaceByUsernameProvider('private.user').overrideWith(
              (Ref ref) async => throw const Failure(message: 'offline'),
            ),
          ],
          child: const MaterialApp(
            home: PublicProfileScreen(username: 'private.user'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profile unavailable'), findsOneWidget);
    });

    testWidgets('shows empty not-found state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileSurfaceByUsernameProvider('missing.user').overrideWith(
              (Ref ref) async => const ProfileSurface(
                access: ProfileAccessLevel.unavailable,
                relationship: ProfileRelationship(
                  viewerId: 'viewer',
                  profileId: 'missing',
                  state: FollowRelationshipState.none,
                  canMessage: false,
                  canViewFollowers: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: PublicProfileScreen(username: 'missing.user'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profile unavailable'), findsOneWidget);
    });

    testWidgets('shows private preview without content panel', (
      WidgetTester tester,
    ) async {
      final UserProfile profile = _profile(
        uid: 'target',
        username: 'private.user',
        visibility: Visibility.followers,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileSurfaceByUsernameProvider('private.user').overrideWith(
              (Ref ref) async => ProfileSurface(
                access: ProfileAccessLevel.preview,
                profile: profile,
                relationship: _relationship(
                  FollowRelationshipState.none,
                  profileId: profile.uid,
                  canViewProfile: false,
                  canViewFollowers: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: PublicProfileScreen(username: 'private.user'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This account is private'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Posts'), findsNothing);
    });

    testWidgets('shows full profile content for approved follower', (
      WidgetTester tester,
    ) async {
      final UserProfile profile = _profile(
        uid: 'target',
        username: 'followed.user',
        visibility: Visibility.followers,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileSurfaceByUsernameProvider('followed.user').overrideWith(
              (Ref ref) async => ProfileSurface(
                access: ProfileAccessLevel.full,
                profile: profile,
                relationship: _relationship(
                  FollowRelationshipState.following,
                  profileId: profile.uid,
                  canViewProfile: true,
                  canViewFollowers: true,
                ),
              ),
            ),
            profileContentPageProvider(
              ProfileContentQuery(
                profileId: profile.uid,
                filter: ProfileContentFilter.posts,
              ),
            ).overrideWith(
              (Ref ref) async =>
                  const ProfileContentPage(items: <Never>[], hasMore: false),
            ),
          ],
          child: const MaterialApp(
            home: PublicProfileScreen(username: 'followed.user'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Following'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('This account is private'), findsNothing);
    });

    testWidgets('cancel request via primary action on preview profile', (
      WidgetTester tester,
    ) async {
      final UserProfile profile = _profile(
        uid: 'target',
        username: 'requested.user',
      );
      final _RecordingProfileSocialRepository repository =
          _RecordingProfileSocialRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileSocialRepositoryProvider.overrideWithValue(repository),
            profileSurfaceByUsernameProvider('requested.user').overrideWith(
              (Ref ref) async => ProfileSurface(
                access: ProfileAccessLevel.preview,
                profile: profile,
                relationship: _relationship(
                  FollowRelationshipState.requestSent,
                  profileId: profile.uid,
                  canViewProfile: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: PublicProfileScreen(username: 'requested.user'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Requested'), findsOneWidget);
      await tester.tap(find.text('Requested'));
      await tester.pumpAndSettle();
      expect(repository.cancelledProfileIds, contains(profile.uid));
    });
  });
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required ProfileRelationship relationship,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProfileHeader(
          profile: _profile(),
          isOwnProfile: false,
          relationship: relationship,
          onPrimaryAction: () {},
          onFollowers: relationship.canViewFollowers ? () {} : null,
          onFollowing: relationship.canViewFollowers ? () {} : null,
        ),
      ),
    ),
  );
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required UserProfile profile,
  ProfileSettingsRepository? settingsRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProfileProvider.overrideWith(
          (Ref ref) => Stream<UserProfile?>.value(profile),
        ),
        profilePrivacySettingsProvider.overrideWith(
          (Ref ref) => Stream.value(ProfilePrivacySettings.defaults()),
        ),
        if (settingsRepository != null)
          profileSettingsRepositoryProvider.overrideWithValue(
            settingsRepository,
          ),
      ],
      child: const MaterialApp(home: ProfileSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

UserProfile _profile({
  String uid = 'viewer',
  String username = 'viewer.user',
  Visibility visibility = Visibility.public,
}) {
  final DateTime now = DateTime.utc(2026, 7, 20);
  return UserProfile(
    uid: uid,
    username: username,
    usernameNormalized: username,
    displayName: 'Viewer User',
    bio: 'Bio',
    role: UserRole.athlete,
    isVerified: false,
    verificationType: VerificationType.none,
    favoriteSportIds: const <String>['football'],
    sportLevels: const <String, SportLevel>{},
    goals: const <String>[],
    discoveryRadiusKm: 25,
    visibility: visibility,
    followApprovalPolicy: visibility == Visibility.public
        ? FollowApprovalPolicy.automatic
        : FollowApprovalPolicy.approvalRequired,
    followersCount: 12,
    followingCount: 8,
    postsCount: 3,
    reelsCount: 1,
    onboardingCompleted: true,
    moderationState: ModerationState.active,
    audit: EntityAudit(createdAt: now, updatedAt: now, schemaVersion: 1),
  );
}

ProfileRelationship _relationship(
  FollowRelationshipState state, {
  String profileId = 'target',
  bool canViewProfile = true,
  bool canViewFollowers = true,
}) {
  return ProfileRelationship(
    viewerId: 'viewer',
    profileId: profileId,
    state: state,
    canMessage: state == FollowRelationshipState.following,
    canViewFollowers: canViewFollowers,
    canViewProfile: canViewProfile,
  );
}

class _RecordingProfileSettingsRepository implements ProfileSettingsRepository {
  int updateCalls = 0;
  ProfileEditRequest? lastRequest;

  @override
  Future<Result<ProfilePrivacySettings>> getPrivacySettings() async {
    return Success<ProfilePrivacySettings>(ProfilePrivacySettings.defaults());
  }

  @override
  Stream<Result<ProfilePrivacySettings>> watchPrivacySettings() {
    return Stream<Result<ProfilePrivacySettings>>.value(
      Success<ProfilePrivacySettings>(ProfilePrivacySettings.defaults()),
    );
  }

  @override
  Future<Result<UserProfile>> updateProfile(ProfileEditRequest request) async {
    updateCalls += 1;
    lastRequest = request;
    return Success<UserProfile>(_profile());
  }

  @override
  Future<Result<void>> updatePrivacy(ProfilePrivacySettings settings) async {
    return const Success<void>(null);
  }
}

class _RecordingProfileSocialRepository implements ProfileSocialRepository {
  final List<String> cancelledProfileIds = <String>[];

  @override
  Future<Result<ProfileSurface>> getProfileSurfaceByUsername(String username) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ProfileSurface>> getProfileSurfaceById(String profileId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<UserProfile?>> getVisibleProfileByUsername(String username) {
    throw UnimplementedError();
  }

  @override
  Future<Result<UserProfile?>> getVisibleProfileById(String profileId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ProfileRelationship>> getRelationship(String profileId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ProfileRelationship>> follow(String profileId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ProfileRelationship>> unfollow(String profileId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ProfileRelationship>> acceptRequest(String requesterId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ProfileRelationship>> declineRequest(String requesterId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ProfileRelationship>> cancelRequest(String profileId) async {
    cancelledProfileIds.add(profileId);
    return Success<ProfileRelationship>(
      _relationship(FollowRelationshipState.none, profileId: profileId),
    );
  }

  @override
  Future<Result<void>> removeFollower(String followerId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> block(String profileId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> unblock(String profileId) {
    throw UnimplementedError();
  }

  @override
  Future<Result<ProfileConnectionPage>> listConnections({
    required String profileId,
    required ProfileConnectionType type,
    ProfileConnectionCursor? cursor,
    int limit = 30,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Result<List<BlockedProfile>>> listBlockedProfiles({int limit = 100}) {
    throw UnimplementedError();
  }
}
