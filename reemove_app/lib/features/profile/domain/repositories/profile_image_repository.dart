import '../../../../core/result/result.dart';
import '../entities/profile_image.dart';

abstract interface class ProfileImageRepository {
  Future<Result<ProfileImageAsset>> upload({
    required String uid,
    required ProfileImageKind kind,
    required ProfileImageSource source,
    String? previousStoragePath,
  });
}
