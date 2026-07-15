import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/app/router/app_routes.dart';

void main() {
  group('AppRoutes', () {
    test('builds encoded nested destinations', () {
      expect(AppRoutes.homePost('post 1'), '/home/post/post%201');
      expect(AppRoutes.publicProfile('Move.Fast'), '/profile/user/move.fast');
      expect(AppRoutes.sportHub('trail running'), '/sports/trail%20running');
      expect(
        AppRoutes.sportCommunities('football'),
        '/sports/football/communities',
      );
      expect(
        AppRoutes.sportEvent('running', 'coastal 10k'),
        '/sports/running/events/coastal%2010k',
      );
      expect(AppRoutes.sportLeaderboards('gym'), '/sports/gym/leaderboards');
      expect(AppRoutes.nearby, '/discover/nearby');
      expect(
        AppRoutes.nearbyForSport('running'),
        '/discover/nearby?sport=running',
      );
      expect(AppRoutes.nearbyForType('person'), '/discover/nearby?type=person');
      expect(AppRoutes.profileAlias('Move.Fast'), '/u/move.fast');
      expect(AppRoutes.challengeAlias('weekly 5k'), '/ch/weekly%205k');
      expect(
        AppRoutes.sportsRoute('coastal loop'),
        '/discover/nearby/routes/coastal%20loop',
      );
      expect(AppRoutes.challenges, '/discover/challenges');
      expect(
        AppRoutes.challengesForSport('trail running'),
        '/discover/challenges?sport=trail+running',
      );
      expect(
        AppRoutes.challenge('weekly 5k'),
        '/discover/challenges/weekly%205k',
      );
      expect(
        AppRoutes.submitChallengeProgress('weekly 5k'),
        '/discover/challenges/weekly%205k/submit',
      );
      expect(
        AppRoutes.reviewChallengeSubmissions('weekly 5k'),
        '/discover/challenges/weekly%205k/review',
      );
      expect(AppRoutes.createChallenge, '/create/challenge');
      expect(AppRoutes.isProtectedAlias('/ch/weekly-5k'), isTrue);
      expect(AppRoutes.marketplace, '/discover/marketplace');
      expect(
        AppRoutes.marketplaceForSport('gym'),
        '/discover/marketplace?sport=gym',
      );
      expect(
        AppRoutes.marketplaceListing('bench set'),
        '/discover/marketplace/bench%20set',
      );
      expect(
        AppRoutes.marketplaceSeller('demo athlete'),
        '/discover/marketplace/seller/demo%20athlete',
      );
      expect(AppRoutes.createMarketplaceListing, '/create/listing');
      expect(
        AppRoutes.editMarketplaceListing('listing 1'),
        '/create/listing/listing%201/edit',
      );
      expect(AppRoutes.myMarketplaceListings, '/profile/marketplace');
      expect(AppRoutes.isProtectedAlias('/m/listing-1'), isTrue);
      expect(AppRoutes.notificationSettings, '/home/activity/settings');
      expect(AppRoutes.aiHub, '/discover/ai');
      expect(AppRoutes.aiCoach, '/discover/ai/coach');
      expect(AppRoutes.aiMatchmaker, '/discover/ai/matchmaker');
    });

    test('recognizes shell routes and protected aliases', () {
      expect(AppRoutes.isShellLocation('/home/post/1'), isTrue);
      expect(AppRoutes.isShellLocation('/profile/user/athlete'), isTrue);
      expect(AppRoutes.isProtectedAlias('/u/athlete'), isTrue);
      expect(AppRoutes.isAuthenticatedLocation('/c/chat-1'), isTrue);
      expect(AppRoutes.isAuthenticatedLocation('/auth/sign-in'), isFalse);
    });

    test('preserves a return target through auth routes', () {
      final String location = AppRoutes.withReturnTo(
        AppRoutes.signIn,
        '/sports/running',
      );
      final Uri uri = Uri.parse(location);

      expect(uri.path, AppRoutes.signIn);
      expect(uri.queryParameters['returnTo'], '/sports/running');
      expect(
        AppRoutes.inheritReturnTo(uri, AppRoutes.signUp),
        '/auth/sign-up?returnTo=%2Fsports%2Frunning',
      );
    });
  });
}
