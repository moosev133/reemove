import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {writeAuditEvent} from "../core/audit";
import {callableOptions} from "../core/functionOptions";
import {consumeRateLimit} from "../core/rateLimit";
import {currentSchemaVersion} from "../core/schema";
import {parseOnboardingDraft} from "./requestData";

export const saveOnboardingProgress = onCall(callableOptions, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to save onboarding progress.");
  }

  await consumeRateLimit(uid, {
    key: "save_onboarding_progress",
    maxAttempts: 120,
    windowSeconds: 60 * 60,
  });

  const draft = parseOnboardingDraft(request.data);
  const database = getFirestore();
  const userRef = database.collection("users").doc(uid);
  const onboardingRef = userRef.collection("private").doc("onboarding");
  const userSnapshot = await userRef.get();

  if (!userSnapshot.exists) {
    throw new HttpsError("failed-precondition", "Finish account setup first.");
  }
  if (userSnapshot.get("onboardingCompleted") === true) {
    throw new HttpsError("failed-precondition", "Onboarding is already complete.");
  }

  const now = Timestamp.now();
  const existing = await onboardingRef.get();
  await onboardingRef.set({
    uid,
    ...draft,
    status: "in_progress",
    createdAt: existing.exists ? existing.get("createdAt") ?? now : now,
    updatedAt: now,
    schemaVersion: currentSchemaVersion,
  }, {merge: true});

  await writeAuditEvent({
    actorId: uid,
    action: "onboarding.progress_saved",
    targetType: "user",
    targetId: uid,
    metadata: {step: draft.currentStep, version: draft.version},
  });

  return {
    saved: true,
    currentStep: draft.currentStep,
    updatedAt: now.toDate().toISOString(),
  };
});
