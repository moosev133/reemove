import OpenAI from 'openai';
import { HttpsError } from 'firebase-functions/v2/https';

import { buildPrompt } from './prompts';
import { outputSchemas } from './schemas';
import type { AiGenerationOptions } from './types';

export interface GeneratedPayload {
  result: Record<string, unknown>;
  model: string;
  requestId: string;
  usage: Record<string, unknown>;
}

export async function generateStructuredResult(
  client: OpenAI,
  model: string,
  options: AiGenerationOptions,
): Promise<GeneratedPayload> {
  const definition = outputSchemas[options.module];
  if (!definition) {
    throw new HttpsError('internal', 'Missing AI output schema.');
  }

  const response = await client.responses.create({
    model,
    input: buildPrompt(options),
    text: {
      format: {
        type: 'json_schema',
        name: definition.name,
        strict: true,
        schema: definition.schema,
      },
    },
  } as never);

  if (!response.output_text) {
    throw new HttpsError('internal', 'The AI service returned an empty result.');
  }

  try {
    return {
      result: JSON.parse(response.output_text) as Record<string, unknown>,
      model,
      requestId: response._request_id ?? response.id,
      usage: response.usage ? { ...response.usage } : {},
    };
  } catch {
    throw new HttpsError('internal', 'The AI result could not be parsed.');
  }
}
