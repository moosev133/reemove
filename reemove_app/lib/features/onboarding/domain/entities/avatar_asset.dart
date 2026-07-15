import 'dart:typed_data';

class AvatarUploadSource {
  const AvatarUploadSource({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

class AvatarAsset {
  const AvatarAsset({required this.downloadUrl, required this.storagePath});

  final String downloadUrl;
  final String storagePath;
}
