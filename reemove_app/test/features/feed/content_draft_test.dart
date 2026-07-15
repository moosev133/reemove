import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/domain/value_objects/content_policy.dart';
import 'package:reemove/features/feed/domain/entities/content_draft.dart';

void main() {
  group('ContentDraft', () {
    test('creates privacy-safe defaults for a new post', () {
      final ContentDraft draft = ContentDraft.empty(
        kind: DraftKind.post,
        id: 'draft-1',
      );

      expect(draft.kind, DraftKind.post);
      expect(draft.media, isEmpty);
      expect(draft.visibility, Visibility.public);
      expect(draft.allowComments, isTrue);
    });

    test('copyWith updates editable fields without changing identity', () {
      final ContentDraft original = ContentDraft.empty(
        kind: DraftKind.reel,
        id: 'draft-2',
      );
      final ContentDraft updated = original.copyWith(
        caption: 'Tempo day',
        sportId: 'running',
        visibility: Visibility.followers,
      );

      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      expect(updated.caption, 'Tempo day');
      expect(updated.sportId, 'running');
      expect(updated.visibility, Visibility.followers);
      expect(updated.updatedAt.isBefore(original.updatedAt), isFalse);
    });
  });
}
