import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/domain/value_objects/content_policy.dart';
import 'package:reemove/features/profile/domain/profile_privacy_model.dart';

void main() {
  group('ProfilePrivacyModel', () {
    test('maps legacy visibility to account privacy', () {
      expect(
        ProfilePrivacyModel.fromLegacyVisibility('followers'),
        AccountPrivacy.private,
      );
      expect(
        ProfilePrivacyModel.fromLegacyVisibility('private'),
        AccountPrivacy.ownerOnly,
      );
    });

    test('private account toggle writes followers legacy visibility', () {
      expect(
        ProfilePrivacyModel.legacyVisibilityFor(AccountPrivacy.private),
        'followers',
      );
      expect(
        ProfilePrivacyModel.legacyVisibilityEnumFor(AccountPrivacy.private),
        Visibility.followers,
      );
    });

    test(
      'approved followers can view private accounts but strangers cannot',
      () {
        expect(
          ProfilePrivacyModel.viewerCanViewFullAccount(
            accountPrivacy: AccountPrivacy.private,
            isOwner: false,
            isFollowing: true,
          ),
          isTrue,
        );
        expect(
          ProfilePrivacyModel.viewerCanViewFullAccount(
            accountPrivacy: AccountPrivacy.private,
            isOwner: false,
            isFollowing: false,
          ),
          isFalse,
        );
      },
    );

    test('owner-only content is hidden from followers', () {
      expect(
        ProfilePrivacyModel.viewerCanViewContent(
          contentVisibility: Visibility.private,
          isOwner: false,
          isFollowing: true,
        ),
        isFalse,
      );
    });

    test(
      'public/private settings toggle detection treats followers as private',
      () {
        expect(
          ProfilePrivacyModel.isPublicAccount(visibility: Visibility.followers),
          isFalse,
        );
        expect(
          ProfilePrivacyModel.isPublicAccount(visibility: Visibility.public),
          isTrue,
        );
      },
    );
  });
}
