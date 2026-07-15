import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/domain/value_objects/media_asset.dart';
import '../../../feed/domain/entities/upload_status.dart';
import '../../domain/repositories/marketplace_media_repository.dart';
import '../services/marketplace_failure_mapper.dart';

class FirebaseMarketplaceMediaRepository implements MarketplaceMediaRepository {
  const FirebaseMarketplaceMediaRepository({
    required FirebaseStorage storage,
    required FirebaseAuth auth,
  }) : _storage = storage,
       _auth = auth;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  @override
  Stream<MediaUploadStatus> uploadImage({
    required String listingId,
    required String localPath,
    required String assetId,
  }) async* {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield MediaUploadStatus(
        assetId: assetId,
        progress: 0,
        state: MediaProcessingState.failed,
        message: 'Sign in again before uploading.',
      );
      return;
    }
    final String extension = _extension(localPath);
    final String contentType = _contentType(extension);
    final String path = 'marketplace/$uid/$listingId/$assetId.$extension';
    try {
      final Uint8List bytes = await XFile(localPath).readAsBytes();
      final UploadTask task = _storage
          .ref(path)
          .putData(
            bytes,
            SettableMetadata(
              contentType: contentType,
              cacheControl: 'public,max-age=86400',
              customMetadata: <String, String>{
                'ownerId': uid,
                'listingId': listingId,
                'assetId': assetId,
                'kind': 'image',
                'schemaVersion': '1',
              },
            ),
          );
      await for (final TaskSnapshot snapshot in task.snapshotEvents) {
        final double progress = snapshot.totalBytes <= 0
            ? 0
            : snapshot.bytesTransferred / snapshot.totalBytes;
        yield MediaUploadStatus(
          assetId: assetId,
          progress: progress.clamp(0, 1).toDouble(),
          state: MediaProcessingState.pending,
        );
      }
      final String url = await task.snapshot.ref.getDownloadURL();
      final int size = bytes.length;
      yield MediaUploadStatus(
        assetId: assetId,
        progress: 1,
        state: MediaProcessingState.ready,
        asset: MediaAsset(
          id: assetId,
          storagePath: path,
          kind: MediaKind.image,
          processingState: MediaProcessingState.ready,
          downloadUrl: url,
          contentType: contentType,
          sizeBytes: size,
        ),
      );
    } on FirebaseException catch (error) {
      yield MediaUploadStatus(
        assetId: assetId,
        progress: 0,
        state: MediaProcessingState.failed,
        message: MarketplaceFailureMapper.fromStorage(error).message,
      );
    } on Object {
      yield MediaUploadStatus(
        assetId: assetId,
        progress: 0,
        state: MediaProcessingState.failed,
        message: 'The image could not be uploaded.',
      );
    }
  }

  static String _extension(String path) {
    final String value = path.split('.').last.toLowerCase();
    return <String>{'png', 'webp', 'heic', 'heif'}.contains(value)
        ? value
        : 'jpg';
  }

  static String _contentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    _ => 'image/jpeg',
  };
}
