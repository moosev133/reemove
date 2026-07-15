import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_user.dart';

extension FirebaseUserMapper on User {
  AuthUser toDomain() {
    return AuthUser(
      uid: uid,
      email: email,
      emailVerified: emailVerified,
      isAnonymous: isAnonymous,
      displayName: displayName,
      photoUrl: photoURL,
      providers: providerData
          .map(
            (UserInfo info) => AuthProviderType.fromProviderId(info.providerId),
          )
          .toSet(),
      createdAt: metadata.creationTime,
      lastSignInAt: metadata.lastSignInTime,
    );
  }
}
