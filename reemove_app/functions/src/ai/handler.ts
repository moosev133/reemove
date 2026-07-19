import OpenAI from 'openai';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import type { z} from 'zod';
import { type ZodType } from 'zod';

import { AI_DAILY_LIMIT, OPENAI_API_KEY, OPENAI_MODEL } from './config';
import { loadUserContext } from './context';
import { assertModerationSafe } from './moderation';
import { generateStructuredResult } from './openai_service';
import { consumeDailyQuota } from './rate_limit';
import { assertReeMoveSafety } from './safety';
import { saveAiOutput, saveCoachExchange, writeAuditLog } from './storage';
import type { AiModule } from './types';

export async function handleAiRequest<TSchema extends ZodType>(params: {
  request: CallableRequest<unknown>;
  module: AiModule;
  schema: TSchema;
  trustedContextLoader?: (uid: string, input: z.infer<TSchema>) => Promise<unknown>;
  postValidate?: (result: Record<string, unknown>, trustedContext: unknown) => void;
}): Promise<Record<string, unknown>> {
  const uid = params.request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const parsed = params.schema.safeParse(params.request.data);
  if (!parsed.success) {
    throw new HttpsError('invalid-argument', 'Invalid AI request.', {
      issues: parsed.error.issues.map((issue) => ({ path: issue.path, code: issue.code })),
    });
  }

  const client = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
  const inputText = JSON.stringify(parsed.data);
  let requestId: string | undefined;

  try {
    await consumeDailyQuota(uid, params.module, AI_DAILY_LIMIT.value());
    await assertModerationSafe(client, inputText, 'input');
    const userContext = await loadUserContext(uid);
    const trustedContext = params.trustedContextLoader
      ? await params.trustedContextLoader(uid, parsed.data)
      : undefined;

    const generated = await generateStructuredResult(client, OPENAI_MODEL.value(), {
      module: params.module,
      uid,
      input: parsed.data,
      userContext,
      trustedContext,
    });
    requestId = generated.requestId;

    assertReeMoveSafety(params.module, generated.result);
    params.postValidate?.(generated.result, trustedContext);
    await assertModerationSafe(client, JSON.stringify(generated.result), 'output');

    const saved = await saveAiOutput({
      uid,
      module: params.module,
      inputSummary: summarizeInput(parsed.data),
      result: generated.result,
      model: generated.model,
      requestId: generated.requestId,
      usage: generated.usage,
    });

    let conversationId: string | undefined;
    if (params.module === 'coach') {
      const coachInput = parsed.data as { message: string; conversationId?: string };
      conversationId = await saveCoachExchange({
        uid,
        conversationId: coachInput.conversationId,
        userText: coachInput.message,
        assistantText: String(generated.result.answer ?? ''),
        outputId: saved.outputId,
      });
    }

    await writeAuditLog({
      uid,
      module: params.module,
      requestId: generated.requestId,
      status: 'success',
      model: generated.model,
    });

    return {
      ...saved,
      ...(conversationId ? { conversationId } : {}),
      result: generated.result,
    };
  } catch (error: unknown) {
    const reasonCode = error instanceof HttpsError
      ? String((error.details as { reasonCode?: unknown } | undefined)?.reasonCode ?? error.code)
      : 'unexpected_error';
    await writeAuditLog({
      uid,
      module: params.module,
      requestId,
      status: error instanceof HttpsError ? 'rejected' : 'failed',
      reasonCode,
      model: OPENAI_MODEL.value(),
    }).catch(() => undefined);

    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', 'The AI request could not be completed.');
  }
}

function summarizeInput<T>(input: T): Record<string, unknown> {
  if (!input || typeof input !== 'object') return {};
  const source = input as Record<string, unknown>;
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(source)) {
    if (key.toLowerCase().includes('message') || key.toLowerCase().includes('source')) {
      result[key] = typeof value === 'string' ? `${value.slice(0, 80)}${value.length > 80 ? '…' : ''}` : null;
    } else if (key !== 'candidateIds') {
      result[key] = value;
    } else {
      result.candidateCount = Array.isArray(value) ? value.length : 0;
    }
  }
  return result;
}
