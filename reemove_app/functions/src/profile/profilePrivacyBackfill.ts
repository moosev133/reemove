import {
  FieldPath,
  Timestamp,
  type DocumentSnapshot,
  type Firestore,
} from "firebase-admin/firestore";

import {collections, currentSchemaVersion} from "../core/schema";
import {
  accountPrivacyFromLegacyVisibility,
  legacyVisibilityForAccountPrivacy,
  type AccountPrivacy,
} from "./profilePrivacyModel";

export const BACKFILL_MAX_BATCH = 500;
export const BACKFILL_DEFAULT_BATCH = 100;

export interface BackfillPrivacyPlanItem {
  uid: string;
  updates: Record<string, unknown>;
}

export interface BackfillPrivacyBatchResult {
  scanned: number;
  changed: number;
  skipped: number;
  errors: number;
  errorIds: string[];
  nextCursor: string | null;
  completed: boolean;
  mode: "dryRun" | "reportOnly" | "apply";
  samples: BackfillPrivacyPlanItem[];
}

function isMissing(value: unknown): boolean {
  return value === undefined || value === null || value === "";
}

export function planPrivacyBackfillUpdates(
  document: DocumentSnapshot,
): BackfillPrivacyPlanItem | null {
  const visibility = document.get("visibility");
  const accountPrivacy = document.get("accountPrivacy");
  const followApprovalPolicy = document.get("followApprovalPolicy");
  const visibilityRevision = document.get("visibilityRevision");
  const updates: Record<string, unknown> = {};

  let resolvedAccountPrivacy: AccountPrivacy;
  if (!isMissing(accountPrivacy)) {
    resolvedAccountPrivacy = String(accountPrivacy) as AccountPrivacy;
  } else if (!isMissing(visibility)) {
    resolvedAccountPrivacy = accountPrivacyFromLegacyVisibility(visibility);
    updates.accountPrivacy = resolvedAccountPrivacy;
  } else {
    resolvedAccountPrivacy = "public";
    updates.accountPrivacy = "public";
    updates.visibility = "public";
  }

  if (isMissing(visibility)) {
    updates.visibility = legacyVisibilityForAccountPrivacy(resolvedAccountPrivacy);
  }

  if (isMissing(followApprovalPolicy)) {
    updates.followApprovalPolicy = resolvedAccountPrivacy === "public" ?
      "automatic" : "approvalRequired";
  }

  if (visibilityRevision === undefined) {
    updates.visibilityRevision = 0;
  }

  if (Object.keys(updates).length === 0) {
    return null;
  }

  updates.updatedAt = Timestamp.now();
  updates.schemaVersion = currentSchemaVersion;
  return {uid: document.id, updates};
}

export async function runBackfillProfilePrivacyDefaults(
  database: Firestore,
  options: {
    limit?: number;
    cursor?: string;
    apply?: boolean;
    reportOnly?: boolean;
    maxSamples?: number;
  },
): Promise<BackfillPrivacyBatchResult> {
  const limitValue = typeof options.limit === "number" ?
    Math.trunc(options.limit) : BACKFILL_DEFAULT_BATCH;
  const limit = Math.min(BACKFILL_MAX_BATCH, Math.max(1, limitValue));
  const apply = options.apply === true;
  const reportOnly = options.reportOnly === true || !apply;
  const mode = apply ? "apply" : reportOnly ? "reportOnly" : "dryRun";
  const maxSamples = Math.min(20, Math.max(0, options.maxSamples ?? 5));

  let query = database.collection(collections.users)
    .orderBy(FieldPath.documentId())
    .limit(limit);
  if (options.cursor) {
    query = query.startAfter(options.cursor);
  }

  const snapshot = await query.get();
  const plans: BackfillPrivacyPlanItem[] = [];
  let skipped = 0;
  let errors = 0;
  const errorIds: string[] = [];

  for (const document of snapshot.docs) {
    try {
      const plan = planPrivacyBackfillUpdates(document);
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
        database.collection(collections.users).doc(plan.uid),
        plan.updates,
      );
    }
    await batch.commit();
  }

  const lastDocument = snapshot.docs.at(-1);
  return {
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
