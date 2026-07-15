import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/firestore_parser.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/challenge.dart';
import '../../domain/entities/challenge_requests.dart';
import '../../domain/repositories/challenge_repository.dart';
import '../dto/challenge_dto.dart';
import '../mappers/challenge_mapper.dart';
import '../services/challenge_failure_mapper.dart';

class FirebaseChallengeRepository implements ChallengeRepository {
  const FirebaseChallengeRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required FirebaseStorage storage,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _functions = functions,
       _storage = storage,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  CollectionReference<ChallengeDto> get _challenges => _firestore
      .collection('challenges')
      .withConverter<ChallengeDto>(
        fromFirestore: ChallengeDto.fromFirestore,
        toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
      );

  @override
  Stream<Result<List<Challenge>>> watchActiveForSport(
    String sportId, {
    int limit = 20,
  }) async* {
    try {
      final Query<ChallengeDto> query = _challenges
          .where('sportId', isEqualTo: sportId)
          .where('status', isEqualTo: 'active')
          .where('moderationState', isEqualTo: 'active')
          .where('visibility', isEqualTo: 'public')
          .orderBy('endsAt')
          .limit(limit.clamp(1, 50).toInt());
      await for (final QuerySnapshot<ChallengeDto> snapshot
          in query.snapshots()) {
        yield Success<List<Challenge>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<ChallengeDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<Challenge>>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<Challenge>>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<ChallengePage>> loadChallenges({
    String? sportId,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      Query<ChallengeDto> query = _challenges
          .where('status', isEqualTo: 'active')
          .where('moderationState', isEqualTo: 'active')
          .where('visibility', isEqualTo: 'public')
          .orderBy('isFeatured', descending: true)
          .orderBy('endsAt')
          .limit(limit.clamp(1, 50).toInt());
      if (sportId != null && sportId.isNotEmpty) {
        query = query.where('sportId', isEqualTo: sportId);
      }
      if (cursor != null && cursor.isNotEmpty) {
        final DocumentSnapshot<ChallengeDto> anchor = await _challenges
            .doc(cursor)
            .get();
        if (anchor.exists) {
          query = query.startAfterDocument(anchor);
        }
      }
      final QuerySnapshot<ChallengeDto> snapshot = await query.get();
      final List<Challenge> items = snapshot.docs
          .map(
            (QueryDocumentSnapshot<ChallengeDto> item) =>
                item.data().toDomain(),
          )
          .toList(growable: false);
      return Success<ChallengePage>(
        ChallengePage(
          items: items,
          nextCursor: snapshot.docs.length == limit
              ? snapshot.docs.last.id
              : null,
        ),
      );
    } on FirebaseException catch (error) {
      return FailureResult<ChallengePage>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      return FailureResult<ChallengePage>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<Challenge?>> watchChallenge(String challengeId) async* {
    try {
      await for (final DocumentSnapshot<ChallengeDto> snapshot
          in _challenges.doc(challengeId).snapshots()) {
        yield Success<Challenge?>(snapshot.data()?.toDomain());
      }
    } on FirebaseException catch (error) {
      yield FailureResult<Challenge?>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<Challenge?>(ChallengeFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<Challenge?>> getById(String challengeId) async {
    try {
      final DocumentSnapshot<ChallengeDto> snapshot = await _challenges
          .doc(challengeId)
          .get();
      return Success<Challenge?>(snapshot.data()?.toDomain());
    } on FirebaseException catch (error) {
      return FailureResult<Challenge?>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      return FailureResult<Challenge?>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<ChallengeParticipation?>> watchParticipation(
    String challengeId,
  ) async* {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield const Success<ChallengeParticipation?>(null);
      return;
    }
    try {
      final DocumentReference<ChallengeParticipationDto> reference = _firestore
          .doc('challenges/$challengeId/participants/$uid')
          .withConverter<ChallengeParticipationDto>(
            fromFirestore: ChallengeParticipationDto.fromFirestore,
            toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
          );
      await for (final DocumentSnapshot<ChallengeParticipationDto> snapshot
          in reference.snapshots()) {
        yield Success<ChallengeParticipation?>(snapshot.data()?.toDomain());
      }
    } on FirebaseException catch (error) {
      yield FailureResult<ChallengeParticipation?>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<ChallengeParticipation?>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<ChallengeSubmission>>> watchSubmissions(
    String challengeId, {
    int limit = 100,
  }) async* {
    try {
      final Query<FirestoreMap> query = _firestore
          .collection('challenges/$challengeId/submissions')
          .where('status', whereIn: const <String>['pending', 'flagged'])
          .orderBy('createdAt')
          .limit(limit.clamp(1, 100).toInt());
      await for (final QuerySnapshot<FirestoreMap> snapshot
          in query.snapshots()) {
        final List<ChallengeSubmission> submissions = snapshot.docs
            .map((doc) {
              final FirestoreMap data = doc.data();
              return ChallengeSubmission(
                id: doc.id,
                challengeId: FirestoreParser.string(
                  data,
                  'challengeId',
                  fallback: challengeId,
                ),
                userId: FirestoreParser.string(data, 'userId'),
                displayName: FirestoreParser.string(
                  data,
                  'displayName',
                  fallback: 'Athlete',
                ),
                username: FirestoreParser.string(
                  data,
                  'username',
                  fallback: '',
                ),
                avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
                progressDelta: FirestoreParser.number(data, 'progressDelta'),
                activityId: FirestoreParser.nullableString(data, 'activityId'),
                proofStoragePath: FirestoreParser.nullableString(
                  data,
                  'proofStoragePath',
                ),
                note: FirestoreParser.nullableString(data, 'note'),
                status: ChallengeSubmissionStatus.values.byName(
                  FirestoreParser.string(data, 'status', fallback: 'pending'),
                ),
                riskScore: FirestoreParser.number(
                  data,
                  'riskScore',
                  fallback: 0,
                ),
                riskReasons: FirestoreParser.stringList(data, 'riskReasons'),
                createdAt: FirestoreParser.dateTime(data, 'createdAt'),
                reviewedAt: FirestoreParser.nullableDateTime(
                  data,
                  'reviewedAt',
                ),
              );
            })
            .toList(growable: false);
        yield Success<List<ChallengeSubmission>>(submissions);
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<ChallengeSubmission>>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<ChallengeSubmission>>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<ChallengeLeaderboardEntry>>> watchLeaderboard(
    String challengeId, {
    int limit = 50,
  }) async* {
    try {
      final Query<ChallengeLeaderboardEntryDto> query = _firestore
          .collection('challenges/$challengeId/leaderboard')
          .withConverter<ChallengeLeaderboardEntryDto>(
            fromFirestore: ChallengeLeaderboardEntryDto.fromFirestore,
            toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
          )
          .orderBy('rank')
          .limit(limit.clamp(1, 100).toInt());
      await for (final QuerySnapshot<ChallengeLeaderboardEntryDto> snapshot
          in query.snapshots()) {
        yield Success<List<ChallengeLeaderboardEntry>>(
          snapshot.docs
              .map((item) => item.data().toDomain())
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<ChallengeLeaderboardEntry>>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<ChallengeLeaderboardEntry>>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<EarnedChallengeBadge>>> watchMyBadges() async* {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield const Success<List<EarnedChallengeBadge>>(<EarnedChallengeBadge>[]);
      return;
    }
    try {
      final Query<FirestoreMap> query = _firestore
          .collection('users/$uid/challenge_badges')
          .orderBy('earnedAt', descending: true)
          .limit(100);
      await for (final QuerySnapshot<FirestoreMap> snapshot
          in query.snapshots()) {
        final List<EarnedChallengeBadge> badges = snapshot.docs
            .map((doc) {
              final FirestoreMap data = doc.data();
              final FirestoreMap badge = FirestoreParser.map(data, 'badge');
              return EarnedChallengeBadge(
                badge: ChallengeBadgeDto.fromMap(badge, doc.id).toDomain(),
                challengeId: FirestoreParser.string(data, 'challengeId'),
                earnedAt: FirestoreParser.dateTime(data, 'earnedAt'),
              );
            })
            .toList(growable: false);
        yield Success<List<EarnedChallengeBadge>>(badges);
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<EarnedChallengeBadge>>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<EarnedChallengeBadge>>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<ChallengeRewardClaim>>> watchMyRewardClaims() async* {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield const Success<List<ChallengeRewardClaim>>(<ChallengeRewardClaim>[]);
      return;
    }
    try {
      final Query<FirestoreMap> query = _firestore
          .collection('reward_claims')
          .where('userId', isEqualTo: uid)
          .orderBy('claimedAt', descending: true)
          .limit(100);
      await for (final QuerySnapshot<FirestoreMap> snapshot
          in query.snapshots()) {
        final List<ChallengeRewardClaim> claims = snapshot.docs
            .map((doc) {
              final FirestoreMap data = doc.data();
              final FirestoreMap reward = FirestoreParser.map(data, 'reward');
              return ChallengeRewardClaim(
                id: doc.id,
                reward: ChallengeReward(
                  id: FirestoreParser.string(
                    reward,
                    'id',
                    fallback: FirestoreParser.string(data, 'rewardId'),
                  ),
                  title: FirestoreParser.string(reward, 'title'),
                  description: FirestoreParser.string(reward, 'description'),
                  type: FirestoreParser.string(reward, 'type'),
                  valueText: FirestoreParser.string(reward, 'valueText'),
                  expiresAt: FirestoreParser.nullableDateTime(
                    reward,
                    'expiresAt',
                  ),
                  sponsorName: FirestoreParser.nullableString(
                    reward,
                    'sponsorName',
                  ),
                ),
                challengeId: FirestoreParser.string(data, 'challengeId'),
                status: FirestoreParser.string(
                  data,
                  'status',
                  fallback: 'claimed',
                ),
                claimedAt: FirestoreParser.dateTime(data, 'claimedAt'),
              );
            })
            .toList(growable: false);
        yield Success<List<ChallengeRewardClaim>>(claims);
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<ChallengeRewardClaim>>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<ChallengeRewardClaim>>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<Challenge>>> watchMyChallengeHistory({
    int limit = 50,
  }) async* {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield const Success<List<Challenge>>(<Challenge>[]);
      return;
    }
    try {
      final Query<FirestoreMap> query = _firestore
          .collectionGroup('participants')
          .where('userId', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .limit(limit.clamp(1, 100).toInt());
      await for (final QuerySnapshot<FirestoreMap> snapshot
          in query.snapshots()) {
        final List<String> ids = snapshot.docs
            .map((doc) => FirestoreParser.string(doc.data(), 'challengeId'))
            .toList(growable: false);
        if (ids.isEmpty) {
          yield const Success<List<Challenge>>(<Challenge>[]);
          continue;
        }
        final List<Challenge> values = <Challenge>[];
        for (final String id in ids) {
          final ChallengeDto? challenge = (await _challenges.doc(id).get())
              .data();
          if (challenge != null) {
            values.add(challenge.toDomain());
          }
        }
        yield Success<List<Challenge>>(values);
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<Challenge>>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<Challenge>>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<List<ChallengeActivityOption>>> loadEligibleActivities(
    String challengeId,
  ) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const FailureResult<List<ChallengeActivityOption>>(
        Failure(message: 'Sign in again to select a verified activity.'),
      );
    }
    try {
      final ChallengeDto? challengeDto =
          (await _challenges.doc(challengeId).get()).data();
      if (challengeDto == null) {
        return const FailureResult<List<ChallengeActivityOption>>(
          Failure(message: 'This challenge is no longer available.'),
        );
      }
      final Challenge challenge = challengeDto.toDomain();
      final QuerySnapshot<FirestoreMap> snapshot = await _firestore
          .collection('activities')
          .where('userId', isEqualTo: uid)
          .where('sportId', isEqualTo: challenge.sportId)
          .where('status', isEqualTo: 'verified')
          .where(
            'occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              challenge.startsAt.toUtc(),
            ),
          )
          .where(
            'occurredAt',
            isLessThanOrEqualTo: Timestamp.fromDate(challenge.endsAt.toUtc()),
          )
          .orderBy('occurredAt', descending: true)
          .limit(50)
          .get();
      final List<ChallengeActivityOption> activities = snapshot.docs
          .map((doc) {
            final FirestoreMap data = doc.data();
            final FirestoreMap rawMetrics = FirestoreParser.map(
              data,
              'metrics',
            );
            final Map<String, double> metrics = <String, double>{};
            for (final MapEntry<String, dynamic> entry in rawMetrics.entries) {
              if (entry.value is num) {
                metrics[entry.key] = (entry.value as num).toDouble();
              }
            }
            return ChallengeActivityOption(
              id: doc.id,
              sportId: FirestoreParser.string(data, 'sportId'),
              occurredAt: FirestoreParser.dateTime(data, 'occurredAt'),
              metrics: Map<String, double>.unmodifiable(metrics),
            );
          })
          .toList(growable: false);
      return Success<List<ChallengeActivityOption>>(activities);
    } on FirebaseException catch (error) {
      return FailureResult<List<ChallengeActivityOption>>(
        ChallengeFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      return FailureResult<List<ChallengeActivityOption>>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<String>> createChallenge(CreateChallengeRequest request) async {
    final Result<Map<String, dynamic>> response =
        await _call('createChallenge', <String, Object?>{
          'sportId': request.sportId,
          'title': request.title,
          'description': request.description,
          'difficulty': request.difficulty.name,
          'startsAt': request.startsAt.toUtc().toIso8601String(),
          'endsAt': request.endsAt.toUtc().toIso8601String(),
          'metric': request.metric.name,
          'target': request.target,
          'unit': request.unit,
          'verificationMethod': request.verificationMethod.name,
          'maximumDailyProgress': request.maximumDailyProgress,
          'minimumAge': request.minimumAge,
          'requiresRestDays': request.requiresRestDays,
          'maximumEffortMinutesPerDay': request.maximumEffortMinutesPerDay,
          if (request.communityId != null) 'communityId': request.communityId,
        });
    return response.when<Result<String>>(
      success: (data) => Success<String>(data['challengeId'] as String),
      failure: FailureResult<String>.new,
    );
  }

  @override
  Future<Result<void>> joinChallenge(String challengeId) =>
      _callVoid('joinChallenge', <String, Object?>{'challengeId': challengeId});

  @override
  Future<Result<void>> leaveChallenge(String challengeId) => _callVoid(
    'leaveChallenge',
    <String, Object?>{'challengeId': challengeId},
  );

  @override
  Future<Result<void>> submitProgress(SubmitChallengeProgressRequest request) =>
      _callVoid('submitChallengeProgress', <String, Object?>{
        'challengeId': request.challengeId,
        'progressDelta': request.progressDelta,
        if (request.activityId != null) 'activityId': request.activityId,
        if (request.proofStoragePath != null)
          'proofStoragePath': request.proofStoragePath,
        if (request.note != null) 'note': request.note,
      });

  @override
  Future<Result<void>> setReminder(
    String challengeId, {
    required bool enabled,
  }) => _callVoid('setChallengeReminder', <String, Object?>{
    'challengeId': challengeId,
    'enabled': enabled,
  });

  @override
  Future<Result<void>> claimRewards(String challengeId) => _callVoid(
    'claimChallengeRewards',
    <String, Object?>{'challengeId': challengeId},
  );

  @override
  Future<Result<void>> reviewSubmission({
    required String challengeId,
    required String submissionId,
    required bool approve,
  }) => _callVoid('reviewChallengeSubmission', <String, Object?>{
    'challengeId': challengeId,
    'submissionId': submissionId,
    'approve': approve,
  });

  @override
  Future<Result<String>> createProofReviewUrl({
    required String challengeId,
    required String submissionId,
  }) async {
    final Result<Map<String, dynamic>> response = await _call(
      'getChallengeProofReviewUrl',
      <String, Object?>{
        'challengeId': challengeId,
        'submissionId': submissionId,
      },
    );
    return response.when<Result<String>>(
      success: (Map<String, dynamic> data) =>
          Success<String>(data['url'] as String),
      failure: FailureResult<String>.new,
    );
  }

  @override
  Future<Result<String>> uploadProof({
    required String challengeId,
    required String localPath,
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const FailureResult<String>(
        Failure(message: 'Sign in again to upload challenge proof.'),
      );
    }
    try {
      final String proofId = _firestore.collection('challenge_proofs').doc().id;
      final String filename = localPath.split(RegExp(r'[/\\]')).last;
      final String path =
          'challenge_proofs/$uid/$challengeId/$proofId/${_safe(filename)}';
      final Reference reference = _storage.ref(path);
      final Uint8List bytes = await XFile(localPath).readAsBytes();
      await reference.putData(
        bytes,
        SettableMetadata(
          contentType: _contentType(filename),
          customMetadata: <String, String>{
            'ownerId': uid,
            'challengeId': challengeId,
            'proofId': proofId,
            'schemaVersion': '1',
            'kind': 'image',
          },
        ),
      );
      return Success<String>(path);
    } on FirebaseException catch (error) {
      return FailureResult<String>(ChallengeFailureMapper.fromStorage(error));
    } on Object catch (error) {
      return FailureResult<String>(ChallengeFailureMapper.unexpected(error));
    }
  }

  Future<Result<void>> _callVoid(String name, Map<String, Object?> data) async {
    final Result<Map<String, dynamic>> result = await _call(name, data);
    return result.when<Result<void>>(
      success: (_) => const Success<void>(null),
      failure: FailureResult<void>.new,
    );
  }

  Future<Result<Map<String, dynamic>>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final HttpsCallableResult<dynamic> response = await _functions
          .httpsCallable(name)
          .call<dynamic>(data);
      return Success<Map<String, dynamic>>(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<Map<String, dynamic>>(
        ChallengeFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<Map<String, dynamic>>(
        ChallengeFailureMapper.unexpected(error),
      );
    }
  }

  static String _contentType(String filename) {
    final String extension = filename.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  static String _safe(String value) => value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
}
