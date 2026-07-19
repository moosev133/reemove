import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/firebase_options_staging.dart';

void main() {
  test('staging Firebase options target reemove-staging only', () {
    expect(StagingFirebaseOptions.android.projectId, 'reemove-staging');
    expect(StagingFirebaseOptions.ios.projectId, 'reemove-staging');
    expect(StagingFirebaseOptions.macos.projectId, 'reemove-staging');
    expect(StagingFirebaseOptions.web.projectId, 'reemove-staging');
    expect(StagingFirebaseOptions.ios.iosBundleId, 'com.reemove.app');
    expect(StagingFirebaseOptions.macos.iosBundleId, 'com.reemove.app');
    expect(StagingFirebaseOptions.android.appId, contains(':android:'));
    expect(StagingFirebaseOptions.web.appId, contains(':web:'));
    expect(
      StagingFirebaseOptions.android.databaseURL,
      'https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app',
    );
    expect(
      StagingFirebaseOptions.web.databaseURL,
      'https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app',
    );
    expect(
      StagingFirebaseOptions.android.storageBucket,
      'reemove-staging.firebasestorage.app',
    );
    expect(
      StagingFirebaseOptions.web.storageBucket,
      'reemove-staging.firebasestorage.app',
    );
  });
}
