import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/profile/domain/user_avatar_source.dart';

void main() {
  group('resolveUserAvatarImageUrl', () {
    test('prefers ReeMove profile avatar over auth provider photo', () {
      expect(
        resolveUserAvatarImageUrl(
          profileAvatarUrl: 'https://cdn.reemove.app/avatars/me.jpg',
          authPhotoUrl: 'https://lh3.googleusercontent.com/a/photo',
        ),
        'https://cdn.reemove.app/avatars/me.jpg',
      );
    });

    test(
      'falls back to auth provider photo when profile avatar is missing',
      () {
        expect(
          resolveUserAvatarImageUrl(
            profileAvatarUrl: null,
            authPhotoUrl: 'https://lh3.googleusercontent.com/a/photo',
          ),
          'https://lh3.googleusercontent.com/a/photo',
        );
      },
    );

    test('falls back to auth photo when profile avatar is blank', () {
      expect(
        resolveUserAvatarImageUrl(
          profileAvatarUrl: '   ',
          authPhotoUrl: 'https://lh3.googleusercontent.com/a/photo',
        ),
        'https://lh3.googleusercontent.com/a/photo',
      );
    });

    test('returns null when both urls are invalid or missing', () {
      expect(
        resolveUserAvatarImageUrl(
          profileAvatarUrl: 'not-a-url',
          authPhotoUrl: 'ftp://example.com/photo.jpg',
        ),
        isNull,
      );
      expect(
        resolveUserAvatarImageUrl(profileAvatarUrl: null, authPhotoUrl: null),
        isNull,
      );
    });

    test('rejects deleted or malformed urls without a host', () {
      expect(
        resolveUserAvatarImageUrl(
          profileAvatarUrl: 'https://',
          authPhotoUrl: 'file:///local/avatar.jpg',
        ),
        isNull,
      );
    });

    test('trims whitespace from valid urls', () {
      expect(
        resolveUserAvatarImageUrl(
          profileAvatarUrl: '  https://cdn.reemove.app/avatars/me.jpg  ',
          authPhotoUrl: null,
        ),
        'https://cdn.reemove.app/avatars/me.jpg',
      );
    });
  });
}
