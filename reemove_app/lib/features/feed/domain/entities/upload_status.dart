import '../../../../core/domain/value_objects/media_asset.dart';

class MediaUploadStatus {
  const MediaUploadStatus({
    required this.assetId,
    required this.progress,
    required this.state,
    this.asset,
    this.message,
  });

  final String assetId;
  final double progress;
  final MediaProcessingState state;
  final MediaAsset? asset;
  final String? message;
}
