import '../../../../core/result/result.dart';
import '../entities/content_draft.dart';

abstract interface class ContentDraftRepository {
  Future<Result<ContentDraft?>> load(DraftKind kind);
  Future<Result<void>> save(ContentDraft draft);
  Future<Result<void>> clear(DraftKind kind);
}
