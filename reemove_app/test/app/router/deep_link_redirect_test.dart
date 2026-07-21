import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/app/router/app_routes.dart';

void main() {
  group('AppRoutes deep-link preservation', () {
    test('profile alias resolves to canonical public profile path', () {
      expect(AppRoutes.profileAlias('athlete'), '/u/athlete');
      expect(AppRoutes.publicProfile('athlete'), '/profile/user/athlete');
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
  });
}
