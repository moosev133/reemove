import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/database/firestore_failure_mapper.dart';
import '../../../../../core/errors/failure.dart';
import '../../../../../core/result/result.dart';
import '../../domain/entities/sport_definition.dart';
import '../../domain/entities/sport_place.dart';
import '../../domain/entities/sports_event.dart';
import '../../domain/repositories/sports_catalog_repository.dart';
import '../dto/sport_definition_dto.dart';
import '../dto/sport_place_dto.dart';
import '../dto/sports_event_dto.dart';
import '../mappers/sport_definition_mapper.dart';
import '../mappers/sport_place_mapper.dart';
import '../mappers/sports_event_mapper.dart';

class FirebaseSportsCatalogRepository implements SportsCatalogRepository {
  const FirebaseSportsCatalogRepository({
    required CollectionReference<SportDefinitionDto> sports,
    required CollectionReference<SportPlaceDto> places,
    required CollectionReference<SportsEventDto> events,
  }) : _sports = sports,
       _places = places,
       _events = events;

  final CollectionReference<SportDefinitionDto> _sports;
  final CollectionReference<SportPlaceDto> _places;
  final CollectionReference<SportsEventDto> _events;

  @override
  Stream<Result<List<SportDefinition>>> watchEnabledSports() async* {
    try {
      final Query<SportDefinitionDto> query = _sports
          .where('isEnabled', isEqualTo: true)
          .orderBy('sortOrder');
      await for (final QuerySnapshot<SportDefinitionDto> snapshot
          in query.snapshots()) {
        yield Success<List<SportDefinition>>(
          snapshot.docs
              .map((doc) => doc.data().toDomain())
              .toList(growable: false),
        );
      }
    } catch (error) {
      yield FailureResult<List<SportDefinition>>(_mapError(error));
    }
  }

  @override
  Future<Result<SportDefinition?>> getSport(String sportId) async {
    try {
      final DocumentSnapshot<SportDefinitionDto> snapshot = await _sports
          .doc(sportId)
          .get();
      return Success<SportDefinition?>(snapshot.data()?.toDomain());
    } catch (error) {
      return FailureResult<SportDefinition?>(_mapError(error));
    }
  }

  @override
  Stream<Result<SportPlace?>> watchPlace(String placeId) async* {
    try {
      await for (final DocumentSnapshot<SportPlaceDto> snapshot
          in _places.doc(placeId).snapshots()) {
        yield Success<SportPlace?>(snapshot.data()?.toDomain());
      }
    } catch (error) {
      yield FailureResult<SportPlace?>(_mapError(error));
    }
  }

  @override
  Stream<Result<List<SportPlace>>> watchPlacesForSport(
    String sportId, {
    int limit = 30,
  }) async* {
    try {
      final Query<SportPlaceDto> query = _places
          .where('sportIds', arrayContains: sportId)
          .where('moderationState', isEqualTo: 'active')
          .where('visibility', isEqualTo: 'public')
          .orderBy('rating', descending: true)
          .limit(limit);
      await for (final QuerySnapshot<SportPlaceDto> snapshot
          in query.snapshots()) {
        yield Success<List<SportPlace>>(
          snapshot.docs
              .map((doc) => doc.data().toDomain())
              .toList(growable: false),
        );
      }
    } catch (error) {
      yield FailureResult<List<SportPlace>>(_mapError(error));
    }
  }

  @override
  Stream<Result<SportsEvent?>> watchEvent(String eventId) async* {
    try {
      await for (final DocumentSnapshot<SportsEventDto> snapshot
          in _events.doc(eventId).snapshots()) {
        yield Success<SportsEvent?>(snapshot.data()?.toDomain());
      }
    } catch (error) {
      yield FailureResult<SportsEvent?>(_mapError(error));
    }
  }

  @override
  Stream<Result<List<SportsEvent>>> watchUpcomingEvents(
    String sportId, {
    int limit = 30,
  }) async* {
    try {
      final Query<SportsEventDto> query = _events
          .where('sportId', isEqualTo: sportId)
          .where('status', isEqualTo: 'published')
          .where('moderationState', isEqualTo: 'active')
          .where('startAt', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('startAt')
          .limit(limit);
      await for (final QuerySnapshot<SportsEventDto> snapshot
          in query.snapshots()) {
        yield Success<List<SportsEvent>>(
          snapshot.docs
              .map((doc) => doc.data().toDomain())
              .toList(growable: false),
        );
      }
    } catch (error) {
      yield FailureResult<List<SportsEvent>>(_mapError(error));
    }
  }

  static Failure _mapError(Object error) {
    if (error is FirebaseException) {
      return FirestoreFailureMapper.fromFirebaseException(error);
    }
    if (error is FormatException) {
      return FirestoreFailureMapper.fromFormatException(error);
    }
    return FirestoreFailureMapper.unexpected(error);
  }
}
