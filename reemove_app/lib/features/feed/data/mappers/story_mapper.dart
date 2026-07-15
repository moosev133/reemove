import '../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/story.dart';
import '../dto/story_dto.dart';
import 'feed_post_mapper.dart';

extension StoryDtoMapper on StoryDto {
  Story toDomain({required bool isViewed}) => Story(
    id: id,
    author: author.toDomain(),
    media: media.toDomain(),
    caption: caption,
    sportId: sportId,
    visibility: VisibilityStorageValue.fromStorage(visibility),
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    createdAt: createdAt,
    expiresAt: expiresAt,
    viewCount: viewCount,
    isViewed: isViewed,
  );
}
