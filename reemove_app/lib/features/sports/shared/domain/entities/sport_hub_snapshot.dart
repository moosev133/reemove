import 'sport_community.dart';
import 'sport_leaderboard.dart';
import 'sport_place.dart';
import 'sport_trainer.dart';
import 'sports_event.dart';

class SportHubSnapshot {
  const SportHubSnapshot({
    required this.places,
    required this.communities,
    required this.events,
    required this.trainers,
    required this.leaderboards,
  });

  final List<SportPlace> places;
  final List<SportCommunity> communities;
  final List<SportsEvent> events;
  final List<SportTrainer> trainers;
  final List<SportLeaderboard> leaderboards;
}
