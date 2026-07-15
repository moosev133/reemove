import '../../../../core/result/result.dart';
import '../entities/profile_content_page.dart';

abstract interface class ProfileContentRepository {
  Future<Result<ProfileContentPage>> load({
    required String profileId,
    required String viewerId,
    required ProfileContentFilter filter,
    int limit = 18,
    ProfileContentCursor? cursor,
  });
}
