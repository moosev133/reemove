import {getAuth} from "firebase-admin/auth";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {collections, currentSchemaVersion} from "../core/schema";
import {parseProvisionAccountData} from "./requestData";
import {
  normalizeUsername,
  validateDisplayName,
  validateUsername,
} from "./usernamePolicy";

export const provisionAccount = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in before creating a profile.");
  }

  await consumeRateLimit(uid, {
    key: "provision_account",
    maxAttempts: 10,
    windowSeconds: 60 * 60,
  });

  const data = parseProvisionAccountData(request.data);
  if (!data.acceptedTerms || !data.acceptedPrivacy || !data.ageConfirmed) {
    throw new HttpsError(
      "failed-precondition",
      "Accept the legal agreements and confirm the minimum-age requirement.",
    );
  }

  const username = normalizeUsername(data.username);
  const usernameError = validateUsername(username);
  if (usernameError) {
    throw new HttpsError("invalid-argument", usernameError);
  }

  const displayName = data.displayName.trim().replace(/\s+/g, " ");
  const displayNameError = validateDisplayName(displayName);
  if (displayNameError) {
    throw new HttpsError("invalid-argument", displayNameError);
  }

  const authUser = await getAuth().getUser(uid);
  const database = getFirestore();
  const userRef = database.collection(collections.users).doc(uid);
  const usernameRef = database.collection(collections.usernames).doc(username);
  const privateProfileRef = userRef.collection("private").doc("profile");
  const consentsRef = userRef.collection("private").doc("consents");
  const configRef = database.collection(collections.appConfig).doc("mobile");

  const result = await database.runTransaction(async (transaction) => {
    const [existingUser, usernameReservation, appConfig] = await Promise.all([
      transaction.get(userRef),
      transaction.get(usernameRef),
      transaction.get(configRef),
    ]);

    if (existingUser.exists) {
      const existingUsername = existingUser.get("usernameNormalized");
      if (existingUsername !== username) {
        throw new HttpsError(
          "failed-precondition",
          "This account already has a ReeMove username.",
        );
      }
      return {uid, username, created: false};
    }

    if (usernameReservation.exists) {
      const owner = usernameReservation.get("uid");
      if (owner !== uid) {
        throw new HttpsError("already-exists", "That username is already taken.");
      }
    }

    const now = Timestamp.now();
    const termsVersion = appConfig.exists ? appConfig.get("termsVersion") ?? "1.0" : "1.0";
    const privacyVersion = appConfig.exists ? appConfig.get("privacyVersion") ?? "1.0" : "1.0";
    const providerIds = authUser.providerData.map((provider) => provider.providerId);

    transaction.set(usernameRef, {
      uid,
      usernameNormalized: username,
      reservedAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });

    transaction.set(userRef, {
      uid,
      username,
      usernameNormalized: username,
      displayName,
      bio: "",
      ...(authUser.photoURL ? {avatarUrl: authUser.photoURL} : {}),
      role: "athlete",
      isVerified: false,
      verificationType: "none",
      favoriteSportIds: [],
      sportLevels: {},
      goals: [],
      discoveryRadiusKm: 25,
      visibility: "public",
      followApprovalPolicy: "automatic",
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      reelsCount: 0,
      onboardingCompleted: false,
      moderationState: "active",
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });

    transaction.set(privateProfileRef, {
      uid,
      email: authUser.email ?? null,
      emailNormalized: authUser.email?.trim().toLowerCase() ?? null,
      providerIds,
      accountStatus: "active",
      lastSignInAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });

    transaction.set(consentsRef, {
      uid,
      termsVersion,
      privacyVersion,
      termsAcceptedAt: now,
      privacyAcceptedAt: now,
      minimumAgeConfirmedAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });

    return {uid, username, created: true};
  });

  if (result.created) {
    await writeAuditEvent({
      actorId: uid,
      action: "auth.account_provisioned",
      targetType: "user",
      targetId: uid,
      metadata: {
        providerIds: authUser.providerData.map((provider) => provider.providerId),
      },
    });
  }

  return result;
});
