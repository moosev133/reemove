import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/feed/presentation/widgets/relative_time.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 7, 13, 12);

  test('formats recent feed timestamps compactly', () {
    expect(
      relativeTime(now.subtract(const Duration(seconds: 20)), now: now),
      'now',
    );
    expect(
      relativeTime(now.subtract(const Duration(minutes: 8)), now: now),
      '8m',
    );
    expect(
      relativeTime(now.subtract(const Duration(hours: 3)), now: now),
      '3h',
    );
    expect(relativeTime(now.subtract(const Duration(days: 2)), now: now), '2d');
    expect(
      relativeTime(now.subtract(const Duration(days: 21)), now: now),
      '3w',
    );
  });

  test('treats future timestamps as current', () {
    expect(relativeTime(now.add(const Duration(minutes: 2)), now: now), 'now');
  });
}
