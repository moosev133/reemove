import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/authentication/domain/value_objects/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('normalizes email and username input', () {
      expect(
        AuthValidators.normalizeEmail(' Athlete@Example.COM '),
        'athlete@example.com',
      );
      expect(AuthValidators.normalizeUsername(' Move.Fast '), 'move.fast');
    });

    test('accepts valid usernames and rejects malformed separators', () {
      expect(AuthValidators.username('move_fast.26'), isNull);
      expect(AuthValidators.username('_movefast'), isNotNull);
      expect(AuthValidators.username('move..fast'), isNotNull);
      expect(AuthValidators.username('mo'), isNotNull);
      expect(AuthValidators.username('admin'), isNotNull);
    });

    test('enforces a production password baseline', () {
      expect(AuthValidators.strongPassword('StrongPass1!'), isNull);
      expect(AuthValidators.strongPassword('short1!'), isNotNull);
      expect(AuthValidators.strongPassword('onlyletters'), isNotNull);
      expect(AuthValidators.strongPassword('12345678'), isNotNull);
    });

    test('validates display names and email addresses', () {
      expect(AuthValidators.displayName('Mostafa Athlete'), isNull);
      expect(AuthValidators.displayName('M'), isNull);
      expect(AuthValidators.displayName(''), isNotNull);
      expect(AuthValidators.email('athlete@reemove.app'), isNull);
      expect(AuthValidators.email('not-an-email'), isNotNull);
    });
  });
}
