import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getDownloadURL, getStorage} from "firebase-admin/storage";
import {defineSecret, defineString} from "firebase-functions/params";
import {logger} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onObjectFinalized} from "firebase-functions/v2/storage";

import {primaryRegion} from "../core/functionOptions";
import {collections, currentSchemaVersion} from "../core/schema";

const processorUrl = defineString("MEDIA_PROCESSOR_URL", {default: ""});
const processorCallbackUrl = defineString("MEDIA_PROCESSOR_CALLBACK_URL", {
  default: "",
});
const processorSecret = defineSecret("MEDIA_PROCESSOR_SECRET");

type StoredMedia = Record<string, unknown> & {
  id: string;
  storagePath: string;
  kind: "image" | "video";
  processingState: "pending" | "ready" | "failed";
  downloadUrl: string;
};

function contentPathParts(name: string): {
  ownerId: string;
  draftId: string;
  assetId: string;
} | null {
  const parts = name.split("/");
  if (parts.length < 5 || parts[0] !== "content") return null;
  return {ownerId: parts[1], draftId: parts[2], assetId: parts[3]};
}

export const onContentUpload = onObjectFinalized(
  {region: primaryRegion},
  async (event) => {
    const object = event.data;
    const name = object.name;
    const parts = name ? contentPathParts(name) : null;
    if (!name || !parts) return;
    const metadata = object.metadata ?? {};
    if (metadata.ownerId !== parts.ownerId ||
        metadata.draftId !== parts.draftId ||
        metadata.assetId !== parts.assetId) {
      logger.warn("Ignoring content upload with invalid ownership metadata.", {
        name,
      });
      return;
    }
    const contentType = object.contentType ?? "";
    const kind = contentType.startsWith("video/") ? "video" :
      contentType.startsWith("image/") ? "image" : null;
    if (!kind || metadata.kind !== kind) return;

    const file = getStorage().bucket(object.bucket).file(name);
    const downloadUrl = await getDownloadURL(file);
    const database = getFirestore();
    const assetRef = database.collection(collections.mediaAssets)
      .doc(parts.assetId);
    const jobRef = database.collection(collections.mediaJobs)
      .doc(parts.assetId);
    const now = Timestamp.now();
    const sizeBytes = Number(object.size ?? 0);
    const processingState = kind === "image" ? "ready" : "pending";
    const batch = database.batch();
    batch.set(assetRef, {
      id: parts.assetId,
      ownerId: parts.ownerId,
      draftId: parts.draftId,
      storagePath: name,
      kind,
      processingState,
      downloadUrl,
      contentType,
      sizeBytes,
      createdAt: now,
      updatedAt: now,
      schemaVersion: currentSchemaVersion,
    }, {merge: true});
    if (kind === "video") {
      batch.set(jobRef, {
        assetId: parts.assetId,
        ownerId: parts.ownerId,
        inputStoragePath: name,
        status: "queued",
        attempts: 0,
        createdAt: now,
        updatedAt: now,
        schemaVersion: currentSchemaVersion,
      }, {merge: true});
    }
    await batch.commit();
  },
);

export const processQueuedMedia = onSchedule(
  {
    region: primaryRegion,
    schedule: "every 1 minutes",
    secrets: [processorSecret],
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    const url = processorUrl.value().trim();
    const callbackUrl = processorCallbackUrl.value().trim();
    if (!url || !callbackUrl) {
      logger.info("Media processor dispatch is disabled until URLs are configured.");
      return;
    }
    const database = getFirestore();
    const jobs = await database.collection(collections.mediaJobs)
      .where("status", "==", "queued")
      .orderBy("createdAt")
      .limit(10)
      .get();
    for (const document of jobs.docs) {
      const claimed = await database.runTransaction(async (transaction) => {
        const current = await transaction.get(document.ref);
        if (current.get("status") !== "queued") return false;
        transaction.update(document.ref, {
          status: "dispatching",
          attempts: Number(current.get("attempts") ?? 0) + 1,
          updatedAt: Timestamp.now(),
        });
        return true;
      });
      if (!claimed) continue;
      try {
        const response = await fetch(url, {
          method: "POST",
          headers: {
            "authorization": `Bearer ${processorSecret.value()}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            assetId: document.get("assetId"),
            ownerId: document.get("ownerId"),
            inputStoragePath: document.get("inputStoragePath"),
            callbackUrl,
            outputPrefix: `processed/${document.get("ownerId")}/${document.id}/`,
          }),
        });
        if (!response.ok) {
          throw new Error(`Processor returned ${response.status}.`);
        }
        await document.ref.update({
          status: "processing",
          dispatchedAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          lastError: null,
        });
      } catch (error: unknown) {
        const attempts = Number(document.get("attempts") ?? 0) + 1;
        await document.ref.update({
          status: attempts >= 5 ? "failed" : "queued",
          attempts,
          lastError: error instanceof Error ? error.message : String(error),
          updatedAt: Timestamp.now(),
        });
      }
    }
  },
);

function bearerToken(value: string | undefined): string {
  if (!value?.startsWith("Bearer ")) return "";
  return value.slice("Bearer ".length).trim();
}

function requiredString(value: unknown, key: string): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 1024) {
    throw new Error(`${key} is invalid.`);
  }
  return value;
}

function optionalNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

export const completeMediaProcessing = onRequest(
  {
    region: primaryRegion,
    secrets: [processorSecret],
    timeoutSeconds: 120,
  },
  async (request, response) => {
    if (bearerToken(request.headers.authorization) !== processorSecret.value()) {
      response.status(401).json({error: "unauthorized"});
      return;
    }
    try {
      const assetId = requiredString(request.body?.assetId, "assetId");
      const outputStoragePath = requiredString(
        request.body?.outputStoragePath,
        "outputStoragePath",
      );
      const thumbnailStoragePath = typeof request.body?.thumbnailStoragePath ===
        "string" ? request.body.thumbnailStoragePath : undefined;
      const database = getFirestore();
      const jobRef = database.collection(collections.mediaJobs).doc(assetId);
      const assetRef = database.collection(collections.mediaAssets).doc(assetId);
      const [job, asset] = await Promise.all([jobRef.get(), assetRef.get()]);
      if (!job.exists || !asset.exists) throw new Error("Media job not found.");
      const ownerId = String(job.get("ownerId") ?? "");
      const expectedPrefix = `processed/${ownerId}/${assetId}/`;
      if (!outputStoragePath.startsWith(expectedPrefix) ||
          (thumbnailStoragePath && !thumbnailStoragePath.startsWith(expectedPrefix))) {
        throw new Error("Output ownership is invalid.");
      }
      const bucket = getStorage().bucket();
      const outputFile = bucket.file(outputStoragePath);
      const [outputMetadata, downloadUrl] = await Promise.all([
        outputFile.getMetadata(),
        getDownloadURL(outputFile),
      ]);
      let thumbnailUrl: string | undefined;
      if (thumbnailStoragePath) {
        thumbnailUrl = await getDownloadURL(bucket.file(thumbnailStoragePath));
      }
      const now = Timestamp.now();
      const trustedMedia: StoredMedia = {
        id: assetId,
        storagePath: outputStoragePath,
        kind: "video",
        processingState: "ready",
        downloadUrl,
        contentType: String(outputMetadata[0].contentType ?? "video/mp4"),
        sizeBytes: Number(outputMetadata[0].size ?? 0),
      };
      if (thumbnailUrl) trustedMedia.thumbnailUrl = thumbnailUrl;
      const width = optionalNumber(request.body?.width);
      const height = optionalNumber(request.body?.height);
      const durationMs = optionalNumber(request.body?.durationMs);
      if (width !== undefined) trustedMedia.width = width;
      if (height !== undefined) trustedMedia.height = height;
      if (durationMs !== undefined) trustedMedia.durationMs = durationMs;

      await assetRef.set({
        ...trustedMedia,
        updatedAt: now,
      }, {merge: true});
      await jobRef.update({
        status: "succeeded",
        outputStoragePath,
        ...(thumbnailStoragePath ? {thumbnailStoragePath} : {}),
        completedAt: now,
        updatedAt: now,
        lastError: null,
      });
      const contentPath = String(job.get("contentPath") ??
        asset.get("linkedContentPath") ?? "");
      if (contentPath) await updateLinkedContent(contentPath, trustedMedia);
      response.status(200).json({ok: true});
    } catch (error: unknown) {
      logger.error("Media completion callback failed.", {error});
      response.status(400).json({
        error: error instanceof Error ? error.message : String(error),
      });
    }
  },
);

async function updateLinkedContent(
  contentPath: string,
  trustedMedia: StoredMedia,
): Promise<void> {
  const database = getFirestore();
  const reference = database.doc(contentPath);
  await database.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) return;
    if (contentPath.startsWith(`${collections.posts}/`)) {
      const raw = snapshot.get("media");
      const media = Array.isArray(raw) ? raw.map((item: unknown) => {
        if (typeof item !== "object" || item === null) return item;
        const record = item as Record<string, unknown>;
        return record.id === trustedMedia.id ? trustedMedia : record;
      }) : [];
      const allReady = media.length > 0 && media.every((item: unknown) =>
        typeof item === "object" && item !== null &&
        (item as Record<string, unknown>).processingState === "ready",
      );
      transaction.update(reference, {
        media,
        ...(allReady ? {status: "published"} : {}),
        updatedAt: Timestamp.now(),
      });
      return;
    }
    if (contentPath.startsWith(`${collections.stories}/`)) {
      transaction.update(reference, {
        media: trustedMedia,
        updatedAt: Timestamp.now(),
      });
    }
  });
}

export const expireStories = onSchedule(
  {
    region: primaryRegion,
    schedule: "every 15 minutes",
    timeoutSeconds: 120,
  },
  async () => {
    const database = getFirestore();
    const expired = await database.collection(collections.stories)
      .where("moderationState", "==", "active")
      .where("expiresAt", "<=", Timestamp.now())
      .orderBy("expiresAt")
      .limit(400)
      .get();
    if (expired.empty) return;
    const batch = database.batch();
    const now = Timestamp.now();
    for (const document of expired.docs) {
      batch.update(document.ref, {
        moderationState: "removed",
        expiredAt: now,
        updatedAt: now,
      });
    }
    await batch.commit();
  },
);
