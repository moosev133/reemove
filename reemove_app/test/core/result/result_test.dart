import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/errors/failure.dart';
import 'package:reemove/core/result/result.dart';

void main() {
  test('Success dispatches the success callback', () {
    const Result<int> result = Success<int>(42);
    final String value = result.when(
      success: (int data) => 'value:$data',
      failure: (Failure failure) => 'failure:${failure.message}',
    );
    expect(value, 'value:42');
  });

  test('FailureResult dispatches the failure callback', () {
    const Result<int> result = FailureResult<int>(
      Failure(message: 'Unavailable', code: 'unavailable'),
    );
    final String value = result.when(
      success: (int data) => 'value:$data',
      failure: (Failure failure) => failure.code ?? 'unknown',
    );
    expect(value, 'unavailable');
  });
}
