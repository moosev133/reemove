import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quality gate configuration remains valid', () {
    final file = File('quality/quality_gates.json');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Run this test from the repository root.',
    );

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final coverage = json['coverage'] as Map<String, dynamic>;
    final performance = json['performanceBudgetsMs'] as Map<String, dynamic>;

    expect(coverage['globalLinePercent'], inInclusiveRange(75, 100));
    expect(coverage['criticalLinePercent'], inInclusiveRange(85, 100));
    expect(json['criticalJourneysPassPercent'], 100);
    expect(json['aiSafetyReleaseBlockingPassPercent'], 100);
    expect(performance['coldStartP95'], lessThanOrEqualTo(5000));
    expect(performance['aiCallableP95'], lessThanOrEqualTo(30000));
  });
}
