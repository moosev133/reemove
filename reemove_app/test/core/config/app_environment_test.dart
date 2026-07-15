import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/config/app_environment.dart';

void main() {
  group('AppFlavor.parse', () {
    test('parses supported aliases', () {
      expect(AppFlavor.parse('dev'), AppFlavor.development);
      expect(AppFlavor.parse('staging'), AppFlavor.staging);
      expect(AppFlavor.parse('prod'), AppFlavor.production);
    });

    test('rejects unknown values', () {
      expect(() => AppFlavor.parse('preview'), throwsArgumentError);
    });
  });
}
