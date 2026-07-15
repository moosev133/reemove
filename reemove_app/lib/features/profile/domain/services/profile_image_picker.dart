import '../../../../core/result/result.dart';
import '../entities/profile_image.dart';

abstract interface class ProfileImagePicker {
  Future<Result<ProfileImageSource?>> pick(ProfileImageKind kind);
  Future<Result<ProfileImageSource?>> recoverLostSelection();
}
