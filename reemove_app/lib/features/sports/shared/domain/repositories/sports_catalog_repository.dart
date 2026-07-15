import '../../../../../core/result/result.dart';
import '../entities/sport_definition.dart';
import '../entities/sport_place.dart';
import '../entities/sports_event.dart';

abstract interface class SportsCatalogRepository {
  Stream<Result<List<SportDefinition>>> watchEnabledSports();
  Future<Result<SportDefinition?>> getSport(String sportId);
  Stream<Result<SportPlace?>> watchPlace(String placeId);
  Stream<Result<List<SportPlace>>> watchPlacesForSport(
    String sportId, {
    int limit = 30,
  });
  Stream<Result<SportsEvent?>> watchEvent(String eventId);
  Stream<Result<List<SportsEvent>>> watchUpcomingEvents(
    String sportId, {
    int limit = 30,
  });
}
