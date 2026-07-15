import 'dart:typed_data';

enum ProfileImageKind { avatar, cover }

class ProfileImageSource {
  const ProfileImageSource({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

class ProfileImageAsset {
  const ProfileImageAsset({
    required this.downloadUrl,
    required this.storagePath,
  });

  final String downloadUrl;
  final String storagePath;
}
