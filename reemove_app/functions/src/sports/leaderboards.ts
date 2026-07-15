import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {writeAuditEvent} from "../core/audit";
import {callableOptions, primaryRegion} from "../core/functionOptions";
import {collections, currentSchemaVersion} from "../core/schema";
import {requireUid} from "../messaging/conversationAccess";

const sports = [
  {id: "football", metric: "matchPoints", unit: "points", title: "Weekly football form"},
  {id: "gym", metric: "volumeKg", unit: "kg", title: "Weekly training volume"},
  {id: "running", metric: "distanceKm", unit: "km", title: "Weekly distance"},
] as const;

type UserScore = {
  userId: string;
  value: number;
};

export async function rebuildSportLeaderboards(): Promise<number> {
  const database = getFirestore();
  const now = Timestamp.now();
  const startsAt = Timestamp.fromMillis(
    now.toMillis() - 7 * 24 * 60 * 60 * 1000,
  );
  let written = 0;
  for (const sport of sports) {
    const activity = await database.collection(collections.activities)
      .where("sportId", "==", sport.id)
      .where("status", "==", "verified")
      .where("occurredAt", ">=", startsAt)
      .limit(5000)
      .get();
    const totals = new Map<string, number>();
    for (const document of activity.docs) {
      const userId = document.get("userId");
      const metrics = document.get("metrics");
      if (typeof userId !== "string" ||
          typeof metrics !== "object" || metrics === null) continue;
      const value = (metrics as Record<string, unknown>)[sport.metric];
      if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) {
        continue;
      }
      totals.set(userId, (totals.get(userId) ?? 0) + value);
    }
    const ranking: UserScore[] = [...totals.entries()]
      .map(([userId, value]) => ({userId, value}))
      .sort((first, second) => second.value - first.value)
      .slice(0, 50);
    const profileDocuments = await Promise.all(
      ranking.map((item) => database.collection(collections.users).doc(item.userId).get()),
    );
    const entries = ranking.map((item, index) => {
      const profile = profileDocuments[index];
      return {
        userId: item.userId,
        displayName: String(profile.get("displayName") ?? "Athlete"),
        username: String(profile.get("username") ?? ""),
        ...(profile.get("avatarUrl") ? {
          avatarUrl: String(profile.get("avatarUrl")),
        } : {}),
        rank: index + 1,
        value: item.value,
        formattedValue: `${item.value.toFixed(sport.id === "running" ? 1 : 0)} ${sport.unit}`,
        trend: 0,
      };
    });
    const documentId = `${sport.id}_weekly_${startsAt.toMillis()}`;
    await database.collection(collections.leaderboards).doc(documentId).set({
      sportId: sport.id,
      title: sport.title,
      metric: sport.metric,
      unit: sport.unit,
      period: "weekly",
      topEntries: entries,
      isPublished: true,
      generatedAt: now,
      startsAt,
      endsAt: now,
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    });
    written += 1;
  }
  return written;
}

export const refreshSportLeaderboards = onSchedule({
  region: primaryRegion,
  schedule: "every 6 hours",
  timeZone: "UTC",
  retryCount: 2,
}, async () => {
  await rebuildSportLeaderboards();
});

export const rebuildSportLeaderboardsNow = onCall(
  callableOptions,
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    if (request.auth?.token.admin !== true) {
      throw new HttpsError("permission-denied", "Administrator access is required.");
    }
    const written = await rebuildSportLeaderboards();
    await writeAuditEvent({
      actorId: uid,
      action: "sports.leaderboards_rebuilt",
      targetType: "leaderboards",
      targetId: "weekly",
      metadata: {written},
    });
    return {written};
  },
);
