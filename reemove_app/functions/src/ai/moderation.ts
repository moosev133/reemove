import type OpenAI from 'openai';
import { HttpsError } from 'firebase-functions/v2/https';

export async function assertModerationSafe(
  client: OpenAI,
  text: string,
  stage: 'input' | 'output',
): Promise<void> {
  const moderation = await client.moderations.create({
    model: 'omni-moderation-latest',
    input: text,
  });
  const result = moderation.results[0];
  if (result?.flagged) {
    throw new HttpsError(
      'invalid-argument',
      stage === 'input'
        ? 'This request cannot be processed safely.'
        : 'The generated result was blocked for safety.',
      { reasonCode: `moderation_${stage}` },
    );
  }
}
