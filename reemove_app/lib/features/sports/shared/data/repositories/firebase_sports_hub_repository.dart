import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../../../core/database/firestore_parser.dart';
import '../../../../../core/result/result.dart';
import '../../domain/entities/sport_community.dart';
import '../../domain/entities/sport_leaderboard.dart';
import '../../domain/entities/sport_management_requests.dart';
import '../../domain/entities/sport_participation.dart';
import '../../domain/entities/sport_trainer.dart';
import '../../domain/repositories/sports_hub_repository.dart';
import '../dto/sport_community_dto.dart';
import '../dto/sport_leaderboard_dto.dart';
import '../dto/sport_trainer_dto.dart';
import '../mappers/sport_community_mapper.dart';
import '../mappers/sport_leaderboard_mapper.dart';
import '../mappers/sport_trainer_mapper.dart';
import '../services/sports_failure_mapper.dart';

class FirebaseSportsHubRepository implements SportsHubRepository {
  const FirebaseSportsHubRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<SportCommunityDto> get _communities => _firestore
      .collection('teams')
      .withConverter<SportCommunityDto>(
        fromFirestore: SportCommunityDto.fromFirestore,
        toFirestore: (SportCommunityDto value, SetOptions? options) =>
            value.toFirestore(options),
      );

  CollectionReference<SportTrainerDto> get _trainers => _firestore
      .collection('trainer_profiles')
      .withConverter<SportTrainerDto>(
        fromFirestore: SportTrainerDto.fromFirestore,
        toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
      );

  CollectionReference<TrainerServiceDto> get _services => _firestore
      .collection('trainer_services')
      .withConverter<TrainerServiceDto>(
        fromFirestore: TrainerServiceDto.fromFirestore,
        toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
      );

  CollectionReference<SportLeaderboardDto> get _leaderboards => _firestore
      .collection('leaderboards')
      .withConverter<SportLeaderboardDto>(
        fromFirestore: SportLeaderboardDto.fromFirestore,
        toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
      );

  @override
  Stream<Result<List<SportCommunity>>> watchCommunities(
    String sportId, {
    int limit = 30,
  }) async* {
    try {
      final Query<SportCommunityDto> query = _communities
          .where('sportId', isEqualTo: sportId)
          .where('visibility', isEqualTo: 'public')
          .where('moderationState', isEqualTo: 'active')
          .orderBy('memberCount', descending: true)
          .limit(limit.clamp(1, 50).toInt());
      await for (final QuerySnapshot<SportCommunityDto> snapshot
          in query.snapshots()) {
        yield Success<List<SportCommunity>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<SportCommunityDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<SportCommunity>>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<SportCommunity>>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<SportCommunity?>> watchCommunity(String communityId) async* {
    try {
      await for (final DocumentSnapshot<SportCommunityDto> snapshot
          in _communities.doc(communityId).snapshots()) {
        yield Success<SportCommunity?>(snapshot.data()?.toDomain());
      }
    } on FirebaseException catch (error) {
      yield FailureResult<SportCommunity?>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<SportCommunity?>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<SportCommunityMember>>> watchCommunityMembers(
    String communityId, {
    int limit = 50,
  }) async* {
    try {
      final Query<SportCommunityMemberDto> query = _firestore
          .collection('teams')
          .doc(communityId)
          .collection('members')
          .withConverter<SportCommunityMemberDto>(
            fromFirestore: SportCommunityMemberDto.fromFirestore,
            toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
          )
          .where('status', isEqualTo: 'active')
          .where('removedAt', isNull: true)
          .orderBy('joinedAt')
          .limit(limit.clamp(1, 100).toInt());
      await for (final QuerySnapshot<SportCommunityMemberDto> snapshot
          in query.snapshots()) {
        yield Success<List<SportCommunityMember>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<SportCommunityMemberDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<SportCommunityMember>>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<SportCommunityMember>>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<SportCommunityMember>>> watchCommunityJoinRequests(
    String communityId, {
    int limit = 50,
  }) async* {
    try {
      final Query<SportCommunityMemberDto> query = _firestore
          .collection('teams')
          .doc(communityId)
          .collection('members')
          .withConverter<SportCommunityMemberDto>(
            fromFirestore: SportCommunityMemberDto.fromFirestore,
            toFirestore: (_, _) => throw UnsupportedError('Server managed.'),
          )
          .where('status', isEqualTo: 'pending')
          .where('removedAt', isNull: true)
          .orderBy('joinedAt')
          .limit(limit.clamp(1, 100).toInt());
      await for (final QuerySnapshot<SportCommunityMemberDto> snapshot
          in query.snapshots()) {
        yield Success<List<SportCommunityMember>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<SportCommunityMemberDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<SportCommunityMember>>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<SportCommunityMember>>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<SportCommunityMembershipStatus>> watchCommunityMembership({
    required String communityId,
    required String userId,
  }) async* {
    try {
      final DocumentReference<FirestoreMap> reference = _firestore.doc(
        'teams/$communityId/members/$userId',
      );
      await for (final DocumentSnapshot<FirestoreMap> snapshot
          in reference.snapshots()) {
        if (!snapshot.exists || snapshot.data()?['removedAt'] != null) {
          yield const Success<SportCommunityMembershipStatus>(
            SportCommunityMembershipStatus.none,
          );
          continue;
        }
        final String role = snapshot.data()?['role'] as String? ?? 'member';
        yield Success<SportCommunityMembershipStatus>(switch (role) {
          'owner' => SportCommunityMembershipStatus.owner,
          'administrator' ||
          'admin' => SportCommunityMembershipStatus.administrator,
          'pending' => SportCommunityMembershipStatus.pending,
          _ => SportCommunityMembershipStatus.member,
        });
      }
    } on FirebaseException catch (error) {
      yield FailureResult<SportCommunityMembershipStatus>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<SportCommunityMembershipStatus>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<SportTrainer>>> watchTrainers(
    String sportId, {
    int limit = 30,
  }) async* {
    try {
      final Query<SportTrainerDto> query = _trainers
          .where('sportIds', arrayContains: sportId)
          .where('acceptingClients', isEqualTo: true)
          .where('moderationState', isEqualTo: 'active')
          .orderBy('rating', descending: true)
          .limit(limit.clamp(1, 50).toInt());
      await for (final QuerySnapshot<SportTrainerDto> snapshot
          in query.snapshots()) {
        yield Success<List<SportTrainer>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<SportTrainerDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<SportTrainer>>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<SportTrainer>>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<SportTrainer?>> watchTrainer(String trainerId) async* {
    try {
      await for (final DocumentSnapshot<SportTrainerDto> snapshot
          in _trainers.doc(trainerId).snapshots()) {
        yield Success<SportTrainer?>(snapshot.data()?.toDomain());
      }
    } on FirebaseException catch (error) {
      yield FailureResult<SportTrainer?>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<SportTrainer?>(SportsFailureMapper.unexpected(error));
    }
  }

  @override
  Stream<Result<List<TrainerService>>> watchTrainerServices({
    required String trainerId,
    String? sportId,
    int limit = 30,
  }) async* {
    try {
      Query<TrainerServiceDto> query = _services
          .where('trainerId', isEqualTo: trainerId)
          .where('isActive', isEqualTo: true);
      if (sportId != null) {
        query = query.where('sportId', isEqualTo: sportId);
      }
      query = query
          .orderBy('price.amountMinor')
          .limit(limit.clamp(1, 50).toInt());
      await for (final QuerySnapshot<TrainerServiceDto> snapshot
          in query.snapshots()) {
        yield Success<List<TrainerService>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<TrainerServiceDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<TrainerService>>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<TrainerService>>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<List<SportLeaderboard>>> watchLeaderboards(
    String sportId, {
    int limit = 10,
  }) async* {
    try {
      final Query<SportLeaderboardDto> query = _leaderboards
          .where('sportId', isEqualTo: sportId)
          .where('isPublished', isEqualTo: true)
          .orderBy('generatedAt', descending: true)
          .limit(limit.clamp(1, 20).toInt());
      await for (final QuerySnapshot<SportLeaderboardDto> snapshot
          in query.snapshots()) {
        yield Success<List<SportLeaderboard>>(
          snapshot.docs
              .map(
                (QueryDocumentSnapshot<SportLeaderboardDto> item) =>
                    item.data().toDomain(),
              )
              .toList(growable: false),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<List<SportLeaderboard>>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<List<SportLeaderboard>>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Stream<Result<SportsEventParticipation>> watchEventParticipation({
    required String eventId,
    required String userId,
  }) async* {
    try {
      final DocumentReference<FirestoreMap> reference = _firestore.doc(
        'events/$eventId/attendees/$userId',
      );
      await for (final DocumentSnapshot<FirestoreMap> snapshot
          in reference.snapshots()) {
        final FirestoreMap? data = snapshot.data();
        final String status = data?['status'] as String? ?? 'none';
        final Object? timestamp = data?['updatedAt'];
        final DateTime updatedAt = timestamp is Timestamp
            ? timestamp.toDate().toUtc()
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        yield Success<SportsEventParticipation>(
          SportsEventParticipation(
            eventId: eventId,
            status: SportsEventAttendanceStatus.values.byName(status),
            updatedAt: updatedAt,
          ),
        );
      }
    } on FirebaseException catch (error) {
      yield FailureResult<SportsEventParticipation>(
        SportsFailureMapper.fromFirestore(error),
      );
    } on Object catch (error) {
      yield FailureResult<SportsEventParticipation>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<String>> createCommunity(
    CreateSportCommunityRequest request,
  ) async {
    try {
      final Map<String, dynamic> response =
          await _call('createSportCommunity', <String, Object?>{
            'sportId': request.sportId,
            'name': request.name,
            'description': request.description,
            'type': request.type.name,
            'joinPolicy': request.joinPolicy.name,
            'capacity': request.capacity,
            'tags': request.tags,
            'city': request.city,
            'countryCode': request.countryCode,
            if (request.pricingText != null) 'pricingText': request.pricingText,
          });
      return Success<String>(_requiredString(response, 'communityId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(SportsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<String>(SportsFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<SportCommunityMembershipStatus>> joinCommunity(
    String communityId,
  ) async {
    try {
      final Map<String, dynamic> response = await _call(
        'joinSportCommunity',
        <String, Object?>{'communityId': communityId},
      );
      return Success<SportCommunityMembershipStatus>(
        SportCommunityMembershipStatus.values.byName(
          _requiredString(response, 'status'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<SportCommunityMembershipStatus>(
        SportsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<SportCommunityMembershipStatus>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> leaveCommunity(String communityId) => _voidCall(
    'leaveSportCommunity',
    <String, Object?>{'communityId': communityId},
  );

  @override
  Future<Result<void>> respondToCommunityJoinRequest({
    required String communityId,
    required String userId,
    required bool approve,
  }) => _voidCall('respondSportCommunityRequest', <String, Object?>{
    'communityId': communityId,
    'userId': userId,
    'approve': approve,
  });

  @override
  Future<Result<String>> createEvent(CreateSportsEventRequest request) async {
    try {
      final Map<String, dynamic> response = await _call(
        'createSportsEvent',
        <String, Object?>{
          'sportId': request.sportId,
          'type': request.type.name,
          'title': request.title,
          'description': request.description,
          'startAt': request.startAt.toUtc().toIso8601String(),
          'endAt': request.endAt.toUtc().toIso8601String(),
          'timezone': request.timezone,
          'latitude': request.location.latitude,
          'longitude': request.location.longitude,
          'geohash': request.location.geohash,
          'locality': request.location.locality,
          'administrativeArea': request.location.administrativeArea,
          'countryCode': request.location.countryCode,
          if (request.placeId != null) 'placeId': request.placeId,
          'capacity': request.capacity,
          'minimumLevel': request.minimumLevel,
          'maximumLevel': request.maximumLevel,
          if (request.price != null)
            'price': <String, Object?>{
              'amountMinor': request.price!.amountMinor,
              'currency': request.price!.currency,
            },
        },
      );
      return Success<String>(_requiredString(response, 'eventId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(SportsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<String>(SportsFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<SportsEventAttendanceStatus>> attendEvent(
    String eventId,
  ) async {
    try {
      final Map<String, dynamic> response = await _call(
        'attendSportsEvent',
        <String, Object?>{'eventId': eventId},
      );
      return Success<SportsEventAttendanceStatus>(
        SportsEventAttendanceStatus.values.byName(
          _requiredString(response, 'status'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<SportsEventAttendanceStatus>(
        SportsFailureMapper.fromFunctions(error),
      );
    } on Object catch (error) {
      return FailureResult<SportsEventAttendanceStatus>(
        SportsFailureMapper.unexpected(error),
      );
    }
  }

  @override
  Future<Result<void>> leaveEvent(String eventId) =>
      _voidCall('leaveSportsEvent', <String, Object?>{'eventId': eventId});

  @override
  Future<Result<String>> upsertTrainerService(
    UpsertTrainerServiceRequest request,
  ) async {
    try {
      final Map<String, dynamic> response = await _call(
        'upsertTrainerService',
        <String, Object?>{
          if (request.serviceId != null) 'serviceId': request.serviceId,
          'sportId': request.sportId,
          'title': request.title,
          'description': request.description,
          'type': request.type.name,
          'deliveryMode': request.deliveryMode.name,
          'durationMinutes': request.durationMinutes,
          'price': <String, Object?>{
            'amountMinor': request.price.amountMinor,
            'currency': request.price.currency,
          },
        },
      );
      return Success<String>(_requiredString(response, 'serviceId'));
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<String>(SportsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<String>(SportsFailureMapper.unexpected(error));
    }
  }

  Future<Result<void>> _voidCall(String name, Map<String, Object?> data) async {
    try {
      await _call(name, data);
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(SportsFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<void>(SportsFailureMapper.unexpected(error));
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final HttpsCallableResult<dynamic> response = await _functions
        .httpsCallable(name)
        .call<dynamic>(data);
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is Map) {
      return (response.data as Map).cast<String, dynamic>();
    }
    throw const FormatException('The sports service returned invalid data.');
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw FormatException('The sports service omitted $key.');
  }
}
