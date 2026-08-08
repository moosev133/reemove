import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Step-2 staging failure mode:
/// inbox preview readable, but opening the conversation failed because
/// reaction hydration used a documentId whereIn without a query limit, which
/// Firestore rules deny (`request.query.limit <= 100`).
void main() {
  test(
    'viewer reaction hydration includes a limit so message history can load',
    () {
      final String source = File(
        'lib/features/messages/data/repositories/'
        'firebase_messaging_repository.dart',
      ).readAsStringSync();

      expect(
        source.contains(
          '.where(FieldPath.documentId, whereIn: keys)',
        ),
        isTrue,
      );
      expect(
        source.contains('.limit(keys.length.clamp(1, 100).toInt())'),
        isTrue,
        reason:
            'message_reactions whereIn must set limit or rules deny the '
            'query and the conversation screen shows Messages unavailable',
      );
      expect(
        source.contains('Reaction hydration is best-effort'),
        isTrue,
        reason: 'reaction failures must not block message history',
      );
    },
  );
}

