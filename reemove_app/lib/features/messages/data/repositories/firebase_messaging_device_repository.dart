import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/messaging_device_repository.dart';
import '../services/messaging_failure_mapper.dart';

class FirebaseMessagingDeviceRepository implements MessagingDeviceRepository {
  const FirebaseMessagingDeviceRepository({
    required FirebaseMessaging messaging,
    required FirebaseFunctions functions,
  }) : _messaging = messaging,
       _functions = functions;

  final FirebaseMessaging _messaging;
  final FirebaseFunctions _functions;

  @override
  Future<Result<void>> registerCurrentDevice() async {
    try {
      final String? token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return const Success<void>(null);
      }
      await _functions.httpsCallable('registerMessagingDevice').call<dynamic>(
        <String, Object?>{'token': token, 'platform': _platform},
      );
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(MessagingFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<void>(MessagingFailureMapper.unexpected(error));
    }
  }

  @override
  Future<Result<void>> unregisterCurrentDevice() async {
    try {
      final String? token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return const Success<void>(null);
      }
      await _functions.httpsCallable('unregisterMessagingDevice').call<dynamic>(
        <String, Object?>{'token': token},
      );
      return const Success<void>(null);
    } on FirebaseFunctionsException catch (error) {
      return FailureResult<void>(MessagingFailureMapper.fromFunctions(error));
    } on Object catch (error) {
      return FailureResult<void>(MessagingFailureMapper.unexpected(error));
    }
  }

  String get _platform {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      TargetPlatform.windows => 'windows',
      TargetPlatform.fuchsia => 'other',
    };
  }
}
