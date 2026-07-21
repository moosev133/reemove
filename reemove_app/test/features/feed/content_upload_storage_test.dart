import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/feed/data/content_upload_storage.dart';
import 'package:reemove/features/feed/domain/entities/content_draft.dart';

void main() {
  group('ContentUploadStorage', () {
    test('builds draft storage path with a sanitized filename', () {
      expect(
        ContentUploadStorage.draftAssetPath(
          ownerId: 'uid-1',
          draftId: 'draft-1',
          assetId: 'asset-1',
          filename: 'My Photo!.jpg',
        ),
        'content/uid-1/draft-1/asset-1/My_Photo_.jpg',
      );
    });

    test('safeFilename falls back when the name is empty after sanitizing', () {
      expect(ContentUploadStorage.safeFilename(''), 'upload');
      expect(ContentUploadStorage.safeFilename('!!!'), '___');
    });

    test('draftAssetMetadata matches storage rules contract', () {
      final SettableMetadata metadata = ContentUploadStorage.draftAssetMetadata(
        ownerId: 'uid-1',
        draftId: 'draft-1',
        assetId: 'asset-1',
        selection: const DraftMediaSelection(
          localPath: 'ignored',
          name: 'photo.jpg',
          kind: DraftMediaKind.image,
          contentType: 'image/jpeg',
          sizeBytes: 1024,
        ),
      );

      expect(metadata.contentType, 'image/jpeg');
      expect(metadata.customMetadata?['ownerId'], 'uid-1');
      expect(metadata.customMetadata?['draftId'], 'draft-1');
      expect(metadata.customMetadata?['assetId'], 'asset-1');
      expect(metadata.customMetadata?['kind'], 'image');
      expect(metadata.customMetadata?['schemaVersion'], '1');
    });
  });
}
