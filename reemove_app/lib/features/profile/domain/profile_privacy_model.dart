import '../../../../core/domain/value_objects/content_policy.dart';

/// Canonical ReeMove privacy model (mirrors `profilePrivacyModel.ts`).
///
/// **Account privacy** — who may view an account profile:
/// - [AccountPrivacy.public]: strangers may view per content rules.
/// - [AccountPrivacy.private]: strangers see preview; approved followers see
///   follower-authorized content.
/// - [AccountPrivacy.ownerOnly]: only the owner (legacy `visibility: private`).
///
/// **Content visibility** — posts/stories ([Visibility]):
/// - public / followers / private (owner-only content).
///
/// **Legacy `users.visibility` storage**
/// - public → [AccountPrivacy.public]
/// - followers → [AccountPrivacy.private]
/// - private → [AccountPrivacy.ownerOnly]
enum AccountPrivacy { public, private, ownerOnly }

class ProfilePrivacyModel {
  const ProfilePrivacyModel._();

  static AccountPrivacy fromLegacyVisibility(String? legacy) {
    return switch (legacy) {
      'public' => AccountPrivacy.public,
      'followers' => AccountPrivacy.private,
      'private' => AccountPrivacy.ownerOnly,
      _ => AccountPrivacy.public,
    };
  }

  static AccountPrivacy resolve({
    String? accountPrivacy,
    required String legacyVisibility,
  }) {
    return switch (accountPrivacy) {
      'public' => AccountPrivacy.public,
      'private' => AccountPrivacy.private,
      'ownerOnly' => AccountPrivacy.ownerOnly,
      _ => fromLegacyVisibility(legacyVisibility),
    };
  }

  static String legacyVisibilityFor(AccountPrivacy privacy) {
    return switch (privacy) {
      AccountPrivacy.public => 'public',
      AccountPrivacy.private => 'followers',
      AccountPrivacy.ownerOnly => 'private',
    };
  }

  static Visibility legacyVisibilityEnumFor(AccountPrivacy privacy) {
    return VisibilityStorageValue.fromStorage(legacyVisibilityFor(privacy));
  }

  static bool isPublicAccount({
    String? accountPrivacy,
    required Visibility visibility,
  }) {
    return resolve(
          accountPrivacy: accountPrivacy,
          legacyVisibility: visibility.storageValue,
        ) ==
        AccountPrivacy.public;
  }

  static AccountPrivacy fromSettingsToggle({required bool isPublic}) {
    return isPublic ? AccountPrivacy.public : AccountPrivacy.private;
  }

  static bool viewerCanViewFullAccount({
    required AccountPrivacy accountPrivacy,
    required bool isOwner,
    required bool isFollowing,
  }) {
    if (isOwner) {
      return true;
    }
    return switch (accountPrivacy) {
      AccountPrivacy.public => true,
      AccountPrivacy.private => isFollowing,
      AccountPrivacy.ownerOnly => false,
    };
  }

  static bool viewerCanViewContent({
    required Visibility contentVisibility,
    required bool isOwner,
    required bool isFollowing,
  }) {
    if (isOwner) {
      return true;
    }
    return switch (contentVisibility) {
      Visibility.public => true,
      Visibility.followers => isFollowing,
      Visibility.private => false,
    };
  }
}
