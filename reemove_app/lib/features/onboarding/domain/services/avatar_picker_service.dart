import '../../../../core/result/result.dart';
import '../entities/avatar_asset.dart';

abstract interface class AvatarPickerService {
  Future<Result<AvatarUploadSource?>> pickFromGallery();
  Future<Result<AvatarUploadSource?>> pickFromCamera();
  Future<Result<AvatarUploadSource?>> recoverLostSelection();
}
