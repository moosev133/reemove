import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';

import type { AiModule } from './types';

const db = getFirestore();

export async function saveAiOutput(params: {
  uid: string;
  module: AiModule;
  inputSummary: Record<string, unknown>;
  result: Record<string, unknown>;
  model: string;
  requestId: string;
  usage: Record<string, unknown>;
}): Promise<{ outputId: string; createdAt: string }> {
  const ref = db.collection(`users/${params.uid}/ai_outputs`).doc();
  const now = new Date();
  await ref.set({
    type: params.module,
    inputSummary: params.inputSummary,
    result: params.result,
    model: params.model,
    requestId: params.requestId,
    usage: params.usage,
    moderation: { input: 'passed', output: 'passed' },
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(new Date(now.getTime() + 180 * 24 * 60 * 60 * 1000)),
  });
  return { outputId: ref.id, createdAt: now.toISOString() };
}

export async function saveCoachExchange(params: {
  uid: string;
  conversationId?: string;
  userText: string;
  assistantText: string;
  outputId: string;
}): Promise<string> {
  const conversationRef = params.conversationId
    ? db.doc(`users/${params.uid}/ai_conversations/${params.conversationId}`)
    : db.collection(`users/${params.uid}/ai_conversations`).doc();
  const batch = db.batch();
  batch.set(conversationRef, {
    module: 'coach',
    title: params.userText.slice(0, 60),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  const userMessage = conversationRef.collection('messages').doc();
  const assistantMessage = conversationRef.collection('messages').doc();
  batch.set(userMessage, {
    role: 'user',
    text: params.userText,
    createdAt: FieldValue.serverTimestamp(),
    outputId: null,
  });
  batch.set(assistantMessage, {
    role: 'assistant',
    text: params.assistantText,
    createdAt: FieldValue.serverTimestamp(),
    outputId: params.outputId,
  });
  await batch.commit();
  return conversationRef.id;
}

export async function writeAuditLog(params: {
  uid: string;
  module: AiModule;
  requestId?: string;
  status: 'success' | 'rejected' | 'failed';
  reasonCode?: string;
  model?: string;
}): Promise<void> {
  await db.collection('ai_audit_logs').add({
    ...params,
    createdAt: FieldValue.serverTimestamp(),
  });
}
