enum MediaKind { image, video }

enum MediaProcessingState { pending, ready, failed }

class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.storagePath,
    required this.kind,
    required this.processingState,
    this.downloadUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.durationMs,
    this.blurHash,
    this.contentType,
    this.sizeBytes,
  });

  final String id;
  final String storagePath;
  final MediaKind kind;
  final MediaProcessingState processingState;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? blurHash;
  final String? contentType;
  final int? sizeBytes;
}
