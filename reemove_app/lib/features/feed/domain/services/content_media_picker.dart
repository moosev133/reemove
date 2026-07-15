import '../../../../core/result/result.dart';
import '../entities/content_draft.dart';

abstract interface class ContentMediaPicker {
  Future<Result<List<DraftMediaSelection>>> pickImages({int limit = 10});
  Future<Result<DraftMediaSelection?>> pickVideo();
  Future<Result<List<DraftMediaSelection>>> recoverLostSelections();
}
