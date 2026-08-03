import 'package:firebase_storage/firebase_storage.dart';

import '../domain/entities/content_draft.dart';

/// Storage path + metadata builders for draft media uploads.
abstract final class ContentUploadStorage {
  static String draftAssetPath({
    required String ownerId,
    required String draftId,
    required String assetId,
    required String filename,
  }) {
    return 'content/$ownerId/$draftId/$assetId/${safeFilename(filename)}';
  }

  static SettableMetadata draftAssetMetadata({
    required String ownerId,
    required String draftId,
    required String assetId,
    required DraftMediaSelection selection,
  }) {
    return SettableMetadata(
      contentType: selection.contentType,
      customMetadata: <String, String>{
        'ownerId': ownerId,
        'draftId': draftId,
        'assetId': assetId,
        'kind': selection.kind.name,
        'schemaVersion': '1',
      },
    );
  }

  static String safeFilename(String value) {
    final String normalized = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return normalized.isEmpty ? 'upload' : normalized;
  }
}
