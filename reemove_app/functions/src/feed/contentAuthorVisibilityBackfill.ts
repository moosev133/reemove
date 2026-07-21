import {
  FieldPath,
  Timestamp,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";

import {collections, currentSchemaVersion} from "../core/schema";
import {
  legacyVisibilityForAccountPrivacy,
  resolveAccountPrivacy,
} from "../profile/profilePrivacyModel";

export const CONTENT_BACKFILL_MAX_BATCH = 500;
export const CONTENT_BACKFILL_DEFAULT_BATCH = 100;

export type ContentCollection = "posts" | "stories";

export interface ContentBackfillPlanItem {
  collection: ContentCollection;
  documentId: string;
  authorId: string;
  updates: Record<string, unknown>;
}

export interface ContentBackfillBatchResult {
  collection: ContentCollection;
  scanned: number;
  changed: number;
  skipped: number;
  errors: number;
  errorIds: string[];
  nextCursor: string | null;
  completed: boolean;
  mode: "dryRun" | "reportOnly" | "apply";
  samples: ContentBackfillPlanItem[];
}

function isMissing(value: unknown): boolean {
  return value === undefined || value === null || value === "";
}

export function resolveAuthorAccountVisibility(
  author: DocumentSnapshot,
): "public" | "followers" | "private" {
  const visibility = author.get("visibility");
  if (visibility === "public" || visibility === "followers" ||
      visibility === "private") {
    return visibility;
  }
  return legacyVisibilityForAccountPrivacy(resolveAccountPrivacy(author));
}

export function planContentAuthorVisibilityUpdate(
  collection: ContentCollection,
  document: DocumentSnapshot,
  author: DocumentSnapshot,
): ContentBackfillPlanItem | null {
  if (!document.exists || !author.exists) return null;
  if (!isMissing(document.get("authorAccountVisibility"))) return null;
  const authorId = String(document.get("authorId") ?? "");
  if (!authorId) return null;
  return {
    collection,
    documentId: document.id,
    authorId,
    updates: {
      authorAccountVisibility: resolveAuthorAccountVisibility(author),
      updatedAt: Timestamp.now(),
      schemaVersion: document.get("schemaVersion") ?? currentSchemaVersion,
    },
  };
}

export async function runBackfillContentAuthorVisibility(
  database: Firestore,
  options: {
    collection: ContentCollection;
    limit?: number;
    cursor?: string;
    apply?: boolean;
    reportOnly?: boolean;
    maxSamples?: number;
  },
): Promise<ContentBackfillBatchResult> {
  const limitValue = typeof options.limit === "number" ?
    Math.trunc(options.limit) : CONTENT_BACKFILL_DEFAULT_BATCH;
  const limit = Math.min(CONTENT_BACKFILL_MAX_BATCH, Math.max(1, limitValue));
  const apply = options.apply === true;
  const reportOnly = options.reportOnly === true || !apply;
  const mode = apply ? "apply" : reportOnly ? "reportOnly" : "dryRun";
  const maxSamples = Math.min(20, Math.max(0, options.maxSamples ?? 5));
  const collection = options.collection;

  let query = database.collection(collection)
    .orderBy(FieldPath.documentId())
    .limit(limit);
  if (options.cursor) {
    query = query.startAfter(options.cursor);
  }

  const snapshot = await query.get();
  const authorIds = [...new Set(snapshot.docs.map((item) =>
    String(item.get("authorId") ?? ""),
  ).filter((id) => id.length > 0))];
  const authorSnapshots = authorIds.length > 0 ?
    await database.getAll(
      ...authorIds.map((id) => database.collection(collections.users).doc(id)),
    ) :
    [];
  const authors = new Map(authorSnapshots.map((item) => [item.id, item]));

  const plans: ContentBackfillPlanItem[] = [];
  let skipped = 0;
  let errors = 0;
  const errorIds: string[] = [];

  for (const document of snapshot.docs) {
    try {
      const authorId = String(document.get("authorId") ?? "");
      const author = authors.get(authorId);
      if (!author) {
        errors += 1;
        errorIds.push(document.id);
        continue;
      }
      const plan = planContentAuthorVisibilityUpdate(collection, document, author);
      if (plan === null) {
        skipped += 1;
        continue;
      }
      plans.push(plan);
    } catch {
      errors += 1;
      errorIds.push(document.id);
    }
  }

  if (apply && plans.length > 0) {
    const batch = database.batch();
    for (const plan of plans) {
      batch.update(
        database.collection(plan.collection).doc(plan.documentId),
        plan.updates,
      );
    }
    await batch.commit();
  }

  const lastDocument = snapshot.docs.at(-1);
  return {
    collection,
    scanned: snapshot.size,
    changed: plans.length,
    skipped,
    errors,
    errorIds,
    nextCursor: snapshot.size === limit && lastDocument ?
      lastDocument.id : null,
    completed: snapshot.size < limit,
    mode,
    samples: plans.slice(0, maxSamples),
  };
}

export interface ContentVisibilityAuditSummary {
  posts: {
    total: number;
    missingAuthorAccountVisibility: number;
    riskyMissingWithPrivateAuthor: number;
  };
  stories: {
    total: number;
    missingAuthorAccountVisibility: number;
    riskyMissingWithPrivateAuthor: number;
  };
}

export async function auditContentAuthorVisibility(
  database: Firestore,
  options: {maxDocumentsPerCollection?: number} = {},
): Promise<ContentVisibilityAuditSummary> {
  const maxDocuments = Math.min(
    5000,
    Math.max(1, options.maxDocumentsPerCollection ?? 2000),
  );
  const summary: ContentVisibilityAuditSummary = {
    posts: {
      total: 0,
      missingAuthorAccountVisibility: 0,
      riskyMissingWithPrivateAuthor: 0,
    },
    stories: {
      total: 0,
      missingAuthorAccountVisibility: 0,
      riskyMissingWithPrivateAuthor: 0,
    },
  };

  for (const collection of ["posts", "stories"] as const) {
    let cursor: string | undefined;
    while (summary[collection].total < maxDocuments) {
      const remaining = maxDocuments - summary[collection].total;
      const batch = await runBackfillContentAuthorVisibility(database, {
        collection,
        limit: Math.min(CONTENT_BACKFILL_DEFAULT_BATCH, remaining),
        cursor,
        reportOnly: true,
      });
      summary[collection].total += batch.scanned;
      summary[collection].missingAuthorAccountVisibility += batch.changed;
      for (const sample of batch.samples) {
        const author = await database.collection(collections.users)
          .doc(sample.authorId).get();
        const visibility = resolveAuthorAccountVisibility(author);
        if (visibility !== "public") {
          summary[collection].riskyMissingWithPrivateAuthor += 1;
        }
      }
      if (batch.completed || !batch.nextCursor) break;
      cursor = batch.nextCursor;
    }
  }

  return summary;
}
