import '../../../../core/result/result.dart';
import '../entities/profile_edit_request.dart';
import '../entities/profile_privacy_settings.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileSettingsRepository {
  Future<Result<ProfilePrivacySettings>> getPrivacySettings();
  Stream<Result<ProfilePrivacySettings>> watchPrivacySettings();
  Future<Result<UserProfile>> updateProfile(ProfileEditRequest request);
  Future<Result<void>> updatePrivacy(ProfilePrivacySettings settings);
}
