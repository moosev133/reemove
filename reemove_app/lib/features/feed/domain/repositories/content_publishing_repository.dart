import '../../../../core/domain/value_objects/media_asset.dart';
import '../../../../core/result/result.dart';
import '../entities/content_draft.dart';
import '../entities/feed_post.dart';
import '../entities/story.dart';
import '../entities/upload_status.dart';

abstract interface class ContentPublishingRepository {
  Stream<MediaUploadStatus> uploadMedia({
    required String ownerId,
    required String draftId,
    required DraftMediaSelection selection,
  });

  Future<Result<void>> deleteUploadedMedia(MediaAsset asset);

  Future<Result<FeedPost>> publishPost({
    required ContentDraft draft,
    required List<MediaAsset> media,
  });

  Future<Result<Story>> publishStory({
    required ContentDraft draft,
    required MediaAsset media,
  });
}
