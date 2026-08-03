import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/domain/entities/entity_audit.dart';
import 'package:reemove/core/domain/value_objects/content_policy.dart';
import 'package:reemove/core/result/result.dart';
import 'package:reemove/features/feed/application/feed_providers.dart';
import 'package:reemove/features/feed/domain/entities/content_report.dart';
import 'package:reemove/features/feed/domain/entities/post_comment.dart';
import 'package:reemove/features/feed/domain/repositories/post_interaction_repository.dart';
import 'package:reemove/features/profile/application/profile_providers.dart';
import 'package:reemove/features/profile/domain/entities/profile_privacy_settings.dart';
import 'package:reemove/features/profile/domain/entities/profile_relationship.dart';
import 'package:reemove/features/profile/domain/entities/profile_surface.dart';
import 'package:reemove/features/profile/domain/entities/user_profile.dart';
import 'package:reemove/features/profile/presentation/screens/public_profile_screen.dart';

void main() {
  testWidgets('Report profile submits user reportContent request', (
    WidgetTester tester,
  ) async {
    final _FakePostInteractionRepository interactions =
        _FakePostInteractionRepository();
    final UserProfile profile = _profile();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileSurfaceByUsernameProvider('athlete').overrideWith(
            (Ref ref) async => ProfileSurface(
              access: ProfileAccessLevel.full,
              profile: profile,
              relationship: const ProfileRelationship(
                viewerId: 'viewer',
                profileId: 'target-1',
                state: FollowRelationshipState.none,
                canMessage: true,
                canViewFollowers: true,
              ),
            ),
          ),
          postInteractionRepositoryProvider.overrideWithValue(interactions),
        ],
        child: const MaterialApp(
          home: PublicProfileScreen(username: 'athlete'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profile actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report profile'));
    await tester.pumpAndSettle();

    expect(find.text('Why are you reporting this profile?'), findsOneWidget);
    await tester.tap(find.text('Spam or scam'));
    await tester.pumpAndSettle();

    expect(interactions.lastReport, isNotNull);
    expect(interactions.lastReport!.targetType, 'user');
    expect(interactions.lastReport!.targetId, 'target-1');
    expect(interactions.lastReport!.reason, ContentReportReason.spam);
    expect(find.text('Report submitted for review.'), findsOneWidget);
  });
}

UserProfile _profile() {
  final DateTime now = DateTime.utc(2026, 1, 1);
  return UserProfile(
    uid: 'target-1',
    username: 'athlete',
    usernameNormalized: 'athlete',
    displayName: 'Athlete',
    bio: '',
    role: UserRole.athlete,
    isVerified: false,
    verificationType: VerificationType.none,
    favoriteSportIds: const <String>[],
    sportLevels: const <String, SportLevel>{},
    goals: const <String>[],
    discoveryRadiusKm: 25,
    visibility: Visibility.public,
    followApprovalPolicy: FollowApprovalPolicy.automatic,
    followersCount: 1,
    followingCount: 0,
    postsCount: 0,
    reelsCount: 0,
    onboardingCompleted: true,
    moderationState: ModerationState.active,
    audit: EntityAudit(createdAt: now, updatedAt: now, schemaVersion: 1),
  );
}

class _FakePostInteractionRepository implements PostInteractionRepository {
  ContentReportRequest? lastReport;

  @override
  Future<Result<ReactionMutationResult>> togglePostReaction({
    required String postId,
    required PostReactionType type,
  }) async =>
      const Success<ReactionMutationResult>(
        ReactionMutationResult(active: true, count: 1),
      );

  @override
  Future<Result<CommentPage>> loadComments({
    required String postId,
    DateTime? cursorCreatedAt,
    String? cursorDocumentId,
    int limit = 20,
  }) async =>
      const Success<CommentPage>(
        CommentPage(items: <PostComment>[], hasMore: false),
      );

  @override
  Future<Result<PostComment>> createComment({
    required String postId,
    required String text,
    String? parentCommentId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<ReactionMutationResult>> toggleCommentLike({
    required String postId,
    required String commentId,
  }) async =>
      const Success<ReactionMutationResult>(
        ReactionMutationResult(active: true, count: 1),
      );

  @override
  Future<Result<void>> deleteComment({
    required String postId,
    required String commentId,
  }) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> recordPostView(String postId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> report(ContentReportRequest request) async {
    lastReport = request;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> blockUser(String targetUserId) async =>
      const Success<void>(null);
}
