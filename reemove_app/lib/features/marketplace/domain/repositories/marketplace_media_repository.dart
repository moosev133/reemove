import '../../../feed/domain/entities/upload_status.dart';

abstract interface class MarketplaceMediaRepository {
  Stream<MediaUploadStatus> uploadImage({
    required String listingId,
    required String localPath,
    required String assetId,
  });
}
