// File generated for ReeMove staging (reemove-staging) via Firebase app SDK
// configs. Do not point production builds at this file.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Staging [FirebaseOptions] for `reemove-staging`.
///
/// Used only when [AppFlavor.staging] is selected at compile time.
class StagingFirebaseOptions {
  const StagingFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        // Same bundle ID as iOS (`com.reemove.app`); Firebase Apple app is shared.
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'StagingFirebaseOptions are not configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'StagingFirebaseOptions are not configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'StagingFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDcP0BEqraRUOSjhqq0pbiiB8h8255ZlBQ',
    appId: '1:377819651760:web:ea3c16bdca6f0f85ec2575',
    messagingSenderId: '377819651760',
    projectId: 'reemove-staging',
    authDomain: 'reemove-staging.firebaseapp.com',
    databaseURL: 'https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'reemove-staging.firebasestorage.app',
    measurementId: 'G-X21Z3H07Y5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBeb1hLsus4ermg9ANBkvQhyOfOhppfG_4',
    appId: '1:377819651760:android:f4bab5f775271080ec2575',
    messagingSenderId: '377819651760',
    projectId: 'reemove-staging',
    databaseURL: 'https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'reemove-staging.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAFuxvQth4uOMQSbLqfGvc-LlcIT5CX6bw',
    appId: '1:377819651760:ios:15822a1e16aeef7dec2575',
    messagingSenderId: '377819651760',
    projectId: 'reemove-staging',
    databaseURL: 'https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'reemove-staging.firebasestorage.app',
    androidClientId: '377819651760-dt0alsn446ch8ifa2oqa8jtsmhhlms1s.apps.googleusercontent.com',
    iosClientId: '377819651760-sv5p1vgk4313ier40n5m1773uliflf3s.apps.googleusercontent.com',
    iosBundleId: 'com.reemove.app',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAFuxvQth4uOMQSbLqfGvc-LlcIT5CX6bw',
    appId: '1:377819651760:ios:15822a1e16aeef7dec2575',
    messagingSenderId: '377819651760',
    projectId: 'reemove-staging',
    databaseURL: 'https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'reemove-staging.firebasestorage.app',
    androidClientId: '377819651760-dt0alsn446ch8ifa2oqa8jtsmhhlms1s.apps.googleusercontent.com',
    iosClientId: '377819651760-sv5p1vgk4313ier40n5m1773uliflf3s.apps.googleusercontent.com',
    iosBundleId: 'com.reemove.app',
  );
}
