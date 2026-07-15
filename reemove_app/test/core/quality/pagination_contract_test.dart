import 'package:flutter_test/flutter_test.dart';

List<Map<String, Object?>> mergePage(
  List<Map<String, Object?>> current,
  List<Map<String, Object?>> incoming,
) {
  final byId = <String, Map<String, Object?>>{};
  for (final item in [...current, ...incoming]) {
    final id = item['id'];
    if (id is String && id.isNotEmpty) {
      byId[id] = item;
    }
  }
  final result = byId.values.toList();
  result.sort(
    (a, b) =>
        (b['createdAt'] as int? ?? 0).compareTo(a['createdAt'] as int? ?? 0),
  );
  return result;
}

void main() {
  test(
    'cursor-page merge removes duplicates and preserves newest-first order',
    () {
      final result = mergePage(
        const [
          {'id': 'a', 'createdAt': 30},
          {'id': 'b', 'createdAt': 20},
        ],
        const [
          {'id': 'b', 'createdAt': 20},
          {'id': 'c', 'createdAt': 10},
        ],
      );
      expect(result.map((e) => e['id']), ['a', 'b', 'c']);
    },
  );
}
