import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

class GoogleIdentityService {
  GoogleIdentityService({required this.serverClientId});

  final String? serverClientId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  Future<GoogleSignInAccount> authenticate() async {
    await initialize();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError(
        'Interactive Google authentication is not supported on this platform.',
      );
    }
    return GoogleSignIn.instance.authenticate();
  }

  Future<void> signOut() async {
    if (!_initialized) {
      return;
    }
    await GoogleSignIn.instance.signOut();
  }
}
