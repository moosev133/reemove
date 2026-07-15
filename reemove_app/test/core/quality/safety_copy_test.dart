import 'package:flutter_test/flutter_test.dart';

bool containsUnsafeFitnessCopy(String text) {
  final normalized = text.toLowerCase();
  const unsafe = <String>[
    'train through pain',
    'ignore pain',
    'guaranteed diagnosis',
    'extreme calorie restriction',
    'dangerous stunt',
  ];
  return unsafe.any(normalized.contains);
}

void main() {
  test('known unsafe fitness copy is detected', () {
    expect(containsUnsafeFitnessCopy('Ignore pain and continue.'), isTrue);
    expect(containsUnsafeFitnessCopy('Stop if you feel pain.'), isFalse);
  });

  test('safe guidance does not trigger the copy guard', () {
    const guidance =
        'Use controlled technique, progress gradually, and stop if you feel pain.';
    expect(containsUnsafeFitnessCopy(guidance), isFalse);
  });
}
