// File generated for ReeMove production (reemove-production) via Firebase app SDK
// configs. Do not point staging or development builds at this file.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Production [FirebaseOptions] for `reemove-production`.
///
/// Used only when [AppFlavor.production] is selected at compile time.
class ProductionFirebaseOptions {
  const ProductionFirebaseOptions._();

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
          'ProductionFirebaseOptions are not configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'ProductionFirebaseOptions are not configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'ProductionFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAUDtCm3sC2qP0HgnWMQorFlhKUcR2_o3Y',
    appId: '1:1063937415105:web:b524c00175433b7a024140',
    messagingSenderId: '1063937415105',
    projectId: 'reemove-production',
    authDomain: 'reemove-production.firebaseapp.com',
    databaseURL: 'https://reemove-production-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'reemove-production.firebasestorage.app',
    measurementId: 'G-48R88DZHZT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBkU6UMHGPbLjzKbxgszhaDop2YvHTZAq0',
    appId: '1:1063937415105:android:4070ea54830f2943024140',
    messagingSenderId: '1063937415105',
    projectId: 'reemove-production',
    databaseURL: 'https://reemove-production-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'reemove-production.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAM-AcIc3hunXcK-2RcdT74Xj-PZTG0Vqo',
    appId: '1:1063937415105:ios:89d7a13be01a74dd024140',
    messagingSenderId: '1063937415105',
    projectId: 'reemove-production',
    databaseURL: 'https://reemove-production-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'reemove-production.firebasestorage.app',
    iosBundleId: 'com.reemove.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAM-AcIc3hunXcK-2RcdT74Xj-PZTG0Vqo',
    appId: '1:1063937415105:ios:89d7a13be01a74dd024140',
    messagingSenderId: '1063937415105',
    projectId: 'reemove-production',
    databaseURL: 'https://reemove-production-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'reemove-production.firebasestorage.app',
    iosBundleId: 'com.reemove.app',
  );
}
