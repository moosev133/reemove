import '../../../../core/result/result.dart';
import '../entities/story.dart';

abstract interface class StoryRepository {
  Future<Result<List<StoryGroup>>> loadStoryRail({
    required String viewerId,
    int limit = 40,
  });

  Future<Result<void>> markViewed(String storyId);
  Future<Result<void>> deleteStory(String storyId);
}
