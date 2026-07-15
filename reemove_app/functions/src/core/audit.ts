import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";

import {collections, currentSchemaVersion} from "./schema";

export type AuditEvent = {
  actorId: string;
  action: string;
  targetType: string;
  targetId: string;
  metadata?: Record<string, unknown>;
};

export async function writeAuditEvent(event: AuditEvent): Promise<void> {
  try {
    const database = getFirestore();
    await database.collection(collections.auditLogs).add({
      actorId: event.actorId,
      action: event.action,
      targetType: event.targetType,
      targetId: event.targetId,
      metadata: event.metadata ?? {},
      createdAt: Timestamp.now(),
      schemaVersion: currentSchemaVersion,
      serverCreatedAt: FieldValue.serverTimestamp(),
    });
  } catch (error: unknown) {
    // Audit availability must not roll back an already completed identity or
    // account mutation. The error remains visible in Functions logging.
    logger.error("Failed to write authentication audit event.", {
      action: event.action,
      actorId: event.actorId,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
