import '../../../../core/result/result.dart';
import '../entities/avatar_asset.dart';

abstract interface class AvatarRepository {
  Future<Result<AvatarAsset>> upload({
    required String uid,
    required AvatarUploadSource source,
    String? previousStoragePath,
  });
}
