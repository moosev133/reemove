import '../../domain/value_objects/media_asset.dart';
import '../firestore_parser.dart';

class MediaAssetDto {
  const MediaAssetDto({
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

  factory MediaAssetDto.fromMap(FirestoreMap data) => MediaAssetDto(
    id: FirestoreParser.string(data, 'id'),
    storagePath: FirestoreParser.string(data, 'storagePath'),
    kind: FirestoreParser.string(data, 'kind'),
    processingState: FirestoreParser.string(data, 'processingState'),
    downloadUrl: FirestoreParser.nullableString(data, 'downloadUrl'),
    thumbnailUrl: FirestoreParser.nullableString(data, 'thumbnailUrl'),
    width: FirestoreParser.nullableInteger(data, 'width'),
    height: FirestoreParser.nullableInteger(data, 'height'),
    durationMs: FirestoreParser.nullableInteger(data, 'durationMs'),
    blurHash: FirestoreParser.nullableString(data, 'blurHash'),
    contentType: FirestoreParser.nullableString(data, 'contentType'),
    sizeBytes: FirestoreParser.nullableInteger(data, 'sizeBytes'),
  );

  factory MediaAssetDto.fromDomain(MediaAsset value) => MediaAssetDto(
    id: value.id,
    storagePath: value.storagePath,
    kind: value.kind.name,
    processingState: value.processingState.name,
    downloadUrl: value.downloadUrl,
    thumbnailUrl: value.thumbnailUrl,
    width: value.width,
    height: value.height,
    durationMs: value.durationMs,
    blurHash: value.blurHash,
    contentType: value.contentType,
    sizeBytes: value.sizeBytes,
  );

  final String id;
  final String storagePath;
  final String kind;
  final String processingState;
  final String? downloadUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? blurHash;
  final String? contentType;
  final int? sizeBytes;

  MediaAsset toDomain() => MediaAsset(
    id: id,
    storagePath: storagePath,
    kind: MediaKind.values.byName(kind),
    processingState: MediaProcessingState.values.byName(processingState),
    downloadUrl: downloadUrl,
    thumbnailUrl: thumbnailUrl,
    width: width,
    height: height,
    durationMs: durationMs,
    blurHash: blurHash,
    contentType: contentType,
    sizeBytes: sizeBytes,
  );

  FirestoreMap toMap() => <String, Object?>{
    'id': id,
    'storagePath': storagePath,
    'kind': kind,
    'processingState': processingState,
    if (downloadUrl != null) 'downloadUrl': downloadUrl,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (durationMs != null) 'durationMs': durationMs,
    if (blurHash != null) 'blurHash': blurHash,
    if (contentType != null) 'contentType': contentType,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };
}
