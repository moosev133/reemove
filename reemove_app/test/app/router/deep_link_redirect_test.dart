import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/app/router/app_redirect.dart';
import 'package:reemove/app/router/app_routes.dart';
import 'package:reemove/app/router/web_initial_location.dart';
import 'package:reemove/features/authentication/domain/entities/auth_routing_state.dart';

void main() {
  group('AppRoutes deep-link helpers', () {
    test('profile alias resolves to canonical public profile path', () {
      expect(AppRoutes.profileAlias('athlete'), '/u/athlete');
      expect(AppRoutes.publicProfile('athlete'), '/profile/user/athlete');
      expect(AppRoutes.shareableProfile('Athlete'), '/u/athlete');
    });

    test('protected alias paths are treated as authenticated destinations', () {
      expect(AppRoutes.isProtectedAlias('/u/athlete'), isTrue);
      expect(
        AppRoutes.isAuthenticatedLocation('/profile/user/athlete'),
        isTrue,
      );
    });

    test('withReturnTo preserves deep links through startup', () {
      expect(
        AppRoutes.withReturnTo(AppRoutes.startup, '/profile/user/athlete'),
        '/?returnTo=%2Fprofile%2Fuser%2Fathlete',
      );
    });

    test('normalizeDeepLinkLocation resolves profile aliases', () {
      expect(
        AppRoutes.normalizeDeepLinkLocation('/u/athlete'),
        '/profile/user/athlete',
      );
      expect(
        AppRoutes.normalizeDeepLinkLocation('/profile/user/athlete'),
        '/profile/user/athlete',
      );
    });
  });

  group('requestedRouterLocation', () {
    test('reads browser path when router is still matched to startup', () {
      expect(
        requestedRouterLocation('/u/mustafaabualhija', '/'),
        '/u/mustafaabualhija',
      );
      expect(
        requestedRouterLocation('/profile/user/demo', '/'),
        '/profile/user/demo',
      );
    });
  });

  group('resolveAuthRedirect', () {
    const AsyncValue<AuthRoutingState> loading =
        AsyncValue<AuthRoutingState>.loading();
    const AsyncValue<AuthRoutingState> ready =
        AsyncValue<AuthRoutingState>.data(
          AuthRoutingState(destination: AuthDestination.ready),
        );
    const AsyncValue<AuthRoutingState> signedOut =
        AsyncValue<AuthRoutingState>.data(
          AuthRoutingState(destination: AuthDestination.signedOut),
        );

    test('falls back to bootstrap captured location when uri is startup', () {
      WebInitialLocation.debugSetCaptured('/u/mustafaabualhija');
      addTearDown(WebInitialLocation.clearAfterUse);
      expect(
        resolveAuthRedirect(
          routing: ready,
          matchedPath: '/',
          uriString: '/',
          returnTo: null,
        ),
        '/profile/user/mustafaabualhija',
      );
    });

    test('signed-in cold load to /u/:username opens profile route', () {
      expect(
        resolveAuthRedirect(
          routing: ready,
          matchedPath: '/',
          uriString: '/u/mustafaabualhija',
          returnTo: null,
        ),
        '/profile/user/mustafaabualhija',
      );
    });

    test('signed-in cold load to canonical profile path stays put', () {
      expect(
        resolveAuthRedirect(
          routing: ready,
          matchedPath: '/profile/user/:username',
          uriString: '/profile/user/mustafaabualhija',
          returnTo: null,
        ),
        isNull,
      );
    });

    test('auth-loading preserves profile destination from browser URL', () {
      expect(
        resolveAuthRedirect(
          routing: loading,
          matchedPath: '/',
          uriString: '/u/mustafaabualhija',
          returnTo: null,
        ),
        '/?returnTo=%2Fprofile%2Fuser%2Fmustafaabualhija',
      );
    });

    test('auth-loading keeps startup when returnTo is already present', () {
      expect(
        resolveAuthRedirect(
          routing: loading,
          matchedPath: '/',
          uriString: '/?returnTo=%2Fprofile%2Fuser%2Fmustafaabualhija',
          returnTo: '/profile/user/mustafaabualhija',
        ),
        isNull,
      );
    });

    test('signed-out deep link redirects to auth with returnTo', () {
      expect(
        resolveAuthRedirect(
          routing: signedOut,
          matchedPath: '/u/:username',
          uriString: '/u/mustafaabualhija',
          returnTo: null,
        ),
        '/auth?returnTo=%2Fprofile%2Fuser%2Fmustafaabualhija',
      );
    });

    test('signed-out auth screen does not loop', () {
      expect(
        resolveAuthRedirect(
          routing: signedOut,
          matchedPath: AppRoutes.authWelcome,
          uriString: AppRoutes.authWelcome,
          returnTo: null,
        ),
        isNull,
      );
    });

    test('ready startup with returnTo resumes profile destination', () {
      expect(
        resolveAuthRedirect(
          routing: ready,
          matchedPath: '/',
          uriString: '/?returnTo=%2Fprofile%2Fuser%2Fmustafaabualhija',
          returnTo: '/profile/user/mustafaabualhija',
        ),
        '/profile/user/mustafaabualhija',
      );
    });

    test('direct refresh on profile does not redirect home', () {
      expect(
        resolveAuthRedirect(
          routing: ready,
          matchedPath: '/profile/user/:username',
          uriString: '/profile/user/mustafaabualhija',
          returnTo: null,
        ),
        isNull,
      );
    });

    test('unknown startup path falls back to home when signed in', () {
      expect(
        resolveAuthRedirect(
          routing: ready,
          matchedPath: '/',
          uriString: '/',
          returnTo: null,
        ),
        AppRoutes.home,
      );
    });

    test('invalid returnTo values are ignored safely', () {
      expect(safeReturnToValue('https://evil.example/u/demo'), isNull);
      expect(
        resolveAuthRedirect(
          routing: ready,
          matchedPath: '/',
          uriString: '/?returnTo=https%3A%2F%2Fevil.example',
          returnTo: 'https://evil.example',
        ),
        AppRoutes.home,
      );
    });

    test('profile deep-link redirect chain does not loop', () {
      final String? first = resolveAuthRedirect(
        routing: loading,
        matchedPath: '/',
        uriString: '/u/mustafaabualhija',
        returnTo: null,
      );
      expect(first, '/?returnTo=%2Fprofile%2Fuser%2Fmustafaabualhija');

      final String? second = resolveAuthRedirect(
        routing: ready,
        matchedPath: '/',
        uriString: first!,
        returnTo: '/profile/user/mustafaabualhija',
      );
      expect(second, '/profile/user/mustafaabualhija');

      final String? third = resolveAuthRedirect(
        routing: ready,
        matchedPath: '/profile/user/:username',
        uriString: '/profile/user/mustafaabualhija',
        returnTo: null,
      );
      expect(third, isNull);
    });
  });
}
