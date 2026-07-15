import 'dart:developer' as developer;

import '../config/app_environment.dart';

class AppLogger {
  const AppLogger({required AppEnvironment environment})
    : _environment = environment;

  final AppEnvironment _environment;

  void info(String message, {String name = 'ReeMove'}) {
    developer.log(
      message,
      name: '$name.${_environment.flavor.name}',
      level: 800,
    );
  }

  void warning(
    String message, {
    String name = 'ReeMove',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: '$name.${_environment.flavor.name}',
      level: 900,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void error(
    String message, {
    String name = 'ReeMove',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: '$name.${_environment.flavor.name}',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
