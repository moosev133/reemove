import { getFirestore, FieldValue, type Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

const db = getFirestore();

function utcDayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function consumeDailyQuota(
  uid: string,
  module: string,
  limit: number,
): Promise<void> {
  const ref = db.doc(`ai_usage/${uid}/days/${utcDayKey()}`);
  await db.runTransaction(async (transaction: Transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() ?? {};
    const count = typeof data.count === 'number' ? data.count : 0;
    if (count >= limit) {
      throw new HttpsError(
        'resource-exhausted',
        'Your daily AI limit has been reached. Please try again tomorrow.',
        { reasonCode: 'daily_limit' },
      );
    }
    const moduleCounts = data.moduleCounts && typeof data.moduleCounts === 'object'
      ? data.moduleCounts as Record<string, number>
      : {};
    transaction.set(ref, {
      count: count + 1,
      moduleCounts: {
        ...moduleCounts,
        [module]: (moduleCounts[module] ?? 0) + 1,
      },
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });
}
