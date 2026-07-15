class Failure {
  const Failure({
    required this.message,
    this.code,
    this.debugMessage,
    this.cause,
  });

  final String message;
  final String? code;
  final String? debugMessage;
  final Object? cause;

  @override
  String toString() => 'Failure(code: $code, message: $message)';
}
