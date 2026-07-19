import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/firebase_options_production.dart';

void main() {
  test('production Firebase options target reemove-production only', () {
    expect(ProductionFirebaseOptions.android.projectId, 'reemove-production');
    expect(ProductionFirebaseOptions.ios.projectId, 'reemove-production');
    expect(ProductionFirebaseOptions.macos.projectId, 'reemove-production');
    expect(ProductionFirebaseOptions.web.projectId, 'reemove-production');
    expect(ProductionFirebaseOptions.ios.iosBundleId, 'com.reemove.app');
    expect(ProductionFirebaseOptions.macos.iosBundleId, 'com.reemove.app');
    expect(ProductionFirebaseOptions.android.appId, contains(':android:'));
    expect(ProductionFirebaseOptions.web.appId, contains(':web:'));
    expect(
      ProductionFirebaseOptions.android.databaseURL,
      'https://reemove-production-default-rtdb.europe-west1.firebasedatabase.app',
    );
    expect(
      ProductionFirebaseOptions.web.databaseURL,
      'https://reemove-production-default-rtdb.europe-west1.firebasedatabase.app',
    );
    expect(
      ProductionFirebaseOptions.android.storageBucket,
      'reemove-production.firebasestorage.app',
    );
    expect(
      ProductionFirebaseOptions.web.storageBucket,
      'reemove-production.firebasestorage.app',
    );
  });
}
