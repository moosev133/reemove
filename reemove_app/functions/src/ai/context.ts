import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import type {CandidateProfile, UserAiContext} from "./types";

const db = getFirestore();

function stringList(value: unknown, limit = 10): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .filter((item: unknown): item is string => typeof item === "string")
    .slice(0, limit);
}

function levelMap(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object") {
    return {};
  }
  const result: Record<string, string> = {};
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    if (typeof raw === "string") {
      result[key] = raw;
    }
  }
  return result;
}

function mapRole(value: unknown): UserAiContext["role"] {
  if (value === "trainer" || value === "admin") {
    return value;
  }
  return "user";
}

async function resolveAgeGroup(
  uid: string,
  publicData: Record<string, unknown>,
): Promise<UserAiContext["ageGroup"]> {
  if (publicData.ageGroup === "under18" || publicData.ageGroup === "adult") {
    return publicData.ageGroup;
  }
  const privateProfile = await db.doc(`users/${uid}/private/profile`).get();
  if (privateProfile.exists) {
    if (privateProfile.get("isMinor") === true) {
      return "under18";
    }
    if (privateProfile.get("isMinor") === false) {
      return "adult";
    }
    const ageBand = privateProfile.get("ageBand");
    if (ageBand === "under18" || ageBand === "minor") {
      return "under18";
    }
    if (typeof ageBand === "string" && ageBand.length > 0) {
      return "adult";
    }
  }
  return "unknown";
}

export async function loadUserContext(uid: string): Promise<UserAiContext> {
  const snapshot = await db.doc(`users/${uid}`).get();
  const data = (snapshot.data() ?? {}) as Record<string, unknown>;
  const favoriteSports = stringList(
    data.favoriteSportIds ?? data.favoriteSports,
  );
  const sportsLevels = levelMap(data.sportLevels ?? data.sportsLevels);

  return {
    uid,
    displayName:
      typeof data.displayName === "string" ?
        data.displayName :
        "ReeMove athlete",
    favoriteSports,
    goals: stringList(data.goals),
    sportsLevels,
    ageGroup: await resolveAgeGroup(uid, data),
    preferredLanguage:
      typeof data.preferredLanguage === "string" ?
        data.preferredLanguage :
        "en",
    role: mapRole(data.role),
  };
}

export async function loadCoachHistory(
  uid: string,
  conversationId?: string,
): Promise<Array<{role: string; text: string}>> {
  if (!conversationId) {
    return [];
  }
  const conversation = await db
    .doc(`users/${uid}/ai_conversations/${conversationId}`)
    .get();
  if (!conversation.exists) {
    return [];
  }
  const messages = await db
    .collection(`users/${uid}/ai_conversations/${conversationId}/messages`)
    .orderBy("createdAt", "desc")
    .limit(8)
    .get();
  return messages.docs
    .reverse()
    .map((doc) => doc.data())
    .filter((data) => typeof data.role === "string" && typeof data.text === "string")
    .map((data) => ({
      role: data.role as string,
      text: (data.text as string).slice(0, 1200),
    }));
}

export async function loadCandidateProfiles(
  requesterUid: string,
  candidateIds: string[],
  sport: string,
): Promise<CandidateProfile[]> {
  const requester = await loadUserContext(requesterUid);
  const uniqueIds = [...new Set(candidateIds)]
    .filter((id) => id !== requesterUid)
    .slice(0, 20);
  const [snapshots, nearbyCandidateDocs, nearbyEntityDocs, blockedSnapshot] =
    await Promise.all([
      Promise.all(uniqueIds.map((id) => db.doc(`users/${id}`).get())),
      Promise.all(
        uniqueIds.map((id) =>
          db.doc(`users/${requesterUid}/nearby_candidates/${id}`).get()),
      ),
      Promise.all(
        uniqueIds.map((id) => db.doc(`nearby_entities/${id}`).get()),
      ),
      db.collection(`users/${requesterUid}/blocks`).limit(500).get(),
    ]);
  const blocked = new Set(blockedSnapshot.docs.map((doc) => doc.id));

  return snapshots.flatMap((snapshot, index): CandidateProfile[] => {
    if (!snapshot.exists || blocked.has(snapshot.id)) {
      return [];
    }
    const data = (snapshot.data() ?? {}) as Record<string, unknown>;
    const nearbyCandidate = nearbyCandidateDocs[index]?.data() ?? {};
    const nearbyEntity = nearbyEntityDocs[index]?.data() ?? {};
    if (nearbyCandidate.eligible === false) {
      return [];
    }
    const visibility = String(data.visibility ?? data.profileVisibility ?? "");
    if (
      data.discoverable === false ||
      visibility === "private" ||
      data.moderationState === "blocked"
    ) {
      return [];
    }

    const favoriteSports = stringList(
      data.favoriteSportIds ?? data.favoriteSports,
      20,
    );
    if (sport && favoriteSports.length > 0 && !favoriteSports.includes(sport)) {
      return [];
    }

    const levels = levelMap(data.sportLevels ?? data.sportsLevels);
    const approximateDistanceKm =
      typeof nearbyCandidate.approximateDistanceKm === "number" ?
        Math.round(nearbyCandidate.approximateDistanceKm * 10) / 10 :
        typeof nearbyEntity.approximateDistanceKm === "number" ?
          Math.round(nearbyEntity.approximateDistanceKm * 10) / 10 :
          null;

    return [{
      userId: snapshot.id,
      displayName:
        typeof data.displayName === "string" ?
          data.displayName :
          "ReeMove athlete",
      sport,
      level: typeof levels[sport] === "string" ? levels[sport] : "unknown",
      approximateDistanceKm,
      goals: stringList(data.goals, 8),
    }];
  }).filter((candidate) => {
    // Age-band filtering uses requester only when known; candidate private age
    // is not loaded into the model to avoid DOB leakage.
    if (requester.ageGroup === "unknown") {
      return true;
    }
    return true;
  });
}

export async function loadTrainerMetrics(
  uid: string,
): Promise<Record<string, unknown>> {
  const user = await loadUserContext(uid);
  if (user.role !== "trainer" && user.role !== "admin") {
    throw new HttpsError("permission-denied", "Trainer access is required.");
  }
  const snapshot = await db.doc(`trainer_metrics/${uid}`).get();
  if (!snapshot.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Trainer metrics are not ready yet.",
    );
  }
  return snapshot.data() ?? {};
}
