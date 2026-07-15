import {getStorage} from "firebase-admin/storage";
import {FieldValue, GeoPoint, getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {currentSchemaVersion} from "../core/schema";
import {encodeGeohash, roundCoordinate} from "./geohash";
import {
  ageBandFor,
  calculateAge,
  defaultMaximumAge,
  defaultMinimumAge,
  onboardingVersion,
  validateAge,
} from "./onboardingPolicy";
import {parseOnboardingDraft, type OnboardingDraftData} from "./requestData";

async function validateAvatar(uid: string, draft: OnboardingDraftData): Promise<void> {
  const path = draft.avatarStoragePath;
  if (!path) return;
  if (!draft.avatarUrl || !path.startsWith(`users/${uid}/avatar/`)) {
    throw new HttpsError("invalid-argument", "Avatar ownership could not be verified.");
  }

  const [metadata] = await getStorage().bucket().file(path).getMetadata();
  const size = Number(metadata.size ?? 0);
  const ownerId = metadata.metadata?.ownerId;
  const schemaVersion = metadata.metadata?.schemaVersion;
  if (ownerId !== uid || schemaVersion !== "1" ||
      !metadata.contentType?.startsWith("image/") ||
      size <= 0 || size >= 10 * 1024 * 1024) {
    throw new HttpsError("invalid-argument", "Avatar ownership could not be verified.");
  }

  const encodedPath = encodeURIComponent(path);
  if (!draft.avatarUrl.includes(`/o/${encodedPath}`)) {
    throw new HttpsError("invalid-argument", "Avatar URL does not match the uploaded file.");
  }
}

export const completeOnboarding = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to complete onboarding.");
  }

  await consumeRateLimit(uid, {
    key: "complete_onboarding",
    maxAttempts: 20,
    windowSeconds: 60 * 60,
  });

  const draft = parseOnboardingDraft(request.data);
  if (!draft.dateOfBirth) {
    throw new HttpsError("invalid-argument", "Birthday is required.");
  }
  if (draft.favoriteSportIds.length < 1) {
    throw new HttpsError("invalid-argument", "Choose at least one sport.");
  }
  if (draft.goals.length < 1) {
    throw new HttpsError("invalid-argument", "Choose at least one goal.");
  }
  if (draft.favoriteSportIds.some((id) => draft.sportLevels[id] === undefined)) {
    throw new HttpsError("invalid-argument", "Choose a level for every sport.");
  }
  if (draft.locationPermission === "granted" && !draft.location) {
    throw new HttpsError("invalid-argument", "Location data is missing.");
  }
  if (!draft.discovery.showNearbyPeople && draft.discovery.radiusKm < 1) {
    throw new HttpsError("invalid-argument", "Discovery settings are invalid.");
  }

  const database = getFirestore();
  const userRef = database.collection("users").doc(uid);
  const privateProfileRef = userRef.collection("private").doc("profile");
  const preferencesRef = userRef.collection("private").doc("preferences");
  const consentsRef = userRef.collection("private").doc("consents");
  const onboardingRef = userRef.collection("private").doc("onboarding");
  const appConfigRef = database.collection("app_config").doc("mobile");

  const [userSnapshot, consentsSnapshot, appConfigSnapshot, ...sportsSnapshots] =
    await Promise.all([
      userRef.get(),
      consentsRef.get(),
      appConfigRef.get(),
      ...draft.favoriteSportIds.map((id) => database.collection("sports").doc(id).get()),
    ]);

  if (!userSnapshot.exists) {
    throw new HttpsError("failed-precondition", "Finish account setup first.");
  }
  if (userSnapshot.get("moderationState") !== "active") {
    throw new HttpsError("permission-denied", "This account is not active.");
  }
  if (!consentsSnapshot.exists) {
    throw new HttpsError("failed-precondition", "Legal consent is missing.");
  }

  const minimumAge = appConfigSnapshot.exists ?
    Number(appConfigSnapshot.get("minimumAge") ?? defaultMinimumAge) :
    defaultMinimumAge;
  const maximumAge = appConfigSnapshot.exists ?
    Number(appConfigSnapshot.get("maximumAge") ?? defaultMaximumAge) :
    defaultMaximumAge;
  const ageError = validateAge(draft.dateOfBirth, minimumAge, maximumAge);
  if (ageError) throw new HttpsError("failed-precondition", ageError);

  const termsVersion = appConfigSnapshot.exists ?
    String(appConfigSnapshot.get("termsVersion") ?? "1.0") : "1.0";
  const privacyVersion = appConfigSnapshot.exists ?
    String(appConfigSnapshot.get("privacyVersion") ?? "1.0") : "1.0";
  if (consentsSnapshot.get("termsVersion") !== termsVersion ||
      consentsSnapshot.get("privacyVersion") !== privacyVersion) {
    throw new HttpsError(
      "failed-precondition",
      "Review and accept the latest Terms and Privacy Policy.",
    );
  }

  for (const snapshot of sportsSnapshots) {
    if (!snapshot.exists || snapshot.get("isEnabled") !== true) {
      throw new HttpsError("invalid-argument", "A selected sport is unavailable.");
    }
  }

  await validateAvatar(uid, draft);

  const now = Timestamp.now();
  const age = calculateAge(draft.dateOfBirth, now.toDate());
  const acceptedLocation = draft.locationPermission === "granted" ? draft.location : null;
  const publicLocation = acceptedLocation ? {
    location: new GeoPoint(
      roundCoordinate(acceptedLocation.latitude),
      roundCoordinate(acceptedLocation.longitude),
    ),
    geohash: encodeGeohash(
      roundCoordinate(acceptedLocation.latitude),
      roundCoordinate(acceptedLocation.longitude),
      6,
    ),
    ...(acceptedLocation.locality ? {locality: acceptedLocation.locality} : {}),
    ...(acceptedLocation.administrativeArea ? {
      administrativeArea: acceptedLocation.administrativeArea,
    } : {}),
    ...(acceptedLocation.countryCode ? {countryCode: acceptedLocation.countryCode} : {}),
  } : {
    location: FieldValue.delete(),
    geohash: FieldValue.delete(),
    locality: FieldValue.delete(),
    administrativeArea: FieldValue.delete(),
    countryCode: FieldValue.delete(),
  };

  const exactLocation = acceptedLocation ? {
    location: new GeoPoint(acceptedLocation.latitude, acceptedLocation.longitude),
    geohash: encodeGeohash(acceptedLocation.latitude, acceptedLocation.longitude, 9),
    ...(acceptedLocation.locality ? {locality: acceptedLocation.locality} : {}),
    ...(acceptedLocation.administrativeArea ? {
      administrativeArea: acceptedLocation.administrativeArea,
    } : {}),
    ...(acceptedLocation.countryCode ? {countryCode: acceptedLocation.countryCode} : {}),
  } : null;
  const notificationPermissionGranted =
    draft.notifications.permissionStatus === "authorized" ||
    draft.notifications.permissionStatus === "provisional";
  const trustedNotifications = {
    ...draft.notifications,
    masterEnabled: notificationPermissionGranted && draft.notifications.masterEnabled,
  };

  await database.runTransaction(async (transaction) => {
    const latestUser = await transaction.get(userRef);
    if (!latestUser.exists) {
      throw new HttpsError("failed-precondition", "Account profile is unavailable.");
    }
    if (latestUser.get("onboardingCompleted") === true) return;

    transaction.update(userRef, {
      ...(draft.avatarUrl ? {avatarUrl: draft.avatarUrl} : {}),
      favoriteSportIds: draft.favoriteSportIds,
      sportLevels: draft.sportLevels,
      goals: draft.goals,
      ...publicLocation,
      discoveryRadiusKm: draft.discovery.radiusKm,
      visibility: draft.discovery.visibility,
      followApprovalPolicy: draft.discovery.visibility === "public" ?
        "automatic" :
        "approvalRequired",
      onboardingCompleted: true,
      onboardingVersion,
      updatedAt: now,
    });

    transaction.set(privateProfileRef, {
      uid,
      dateOfBirth: draft.dateOfBirth,
      ageBand: ageBandFor(age),
      isMinor: age < 18,
      onboardingVersion,
      onboardingCompletedAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});

    transaction.set(preferencesRef, {
      uid,
      discovery: draft.discovery,
      accessibility: draft.accessibility,
      notifications: trustedNotifications,
      locationPermission: draft.locationPermission,
      exactLocation,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});

    transaction.set(onboardingRef, {
      uid,
      ...draft,
      status: "completed",
      completedAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
  });

  await writeAuditEvent({
    actorId: uid,
    action: "onboarding.completed",
    targetType: "user",
    targetId: uid,
    metadata: {
      version: onboardingVersion,
      sportsCount: draft.favoriteSportIds.length,
      hasLocation: draft.location !== null,
      notificationsEnabled: trustedNotifications.masterEnabled,
    },
  });

  return {completed: true, onboardingVersion};
});
