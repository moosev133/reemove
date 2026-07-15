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
      expect(
        AppRoutes.sportsRoute('coastal loop'),
        '/discover/nearby/routes/coastal%20loop',
      );
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
