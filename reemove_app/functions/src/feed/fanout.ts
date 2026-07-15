import {
  getFirestore,
  Timestamp,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

import {primaryRegion} from "../core/functionOptions";
import {collections, currentSchemaVersion} from "../core/schema";

const batchSize = 400;

export const fanoutPublishedPost = onDocumentWritten(
  {
    document: `${collections.posts}/{postId}`,
    region: primaryRegion,
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const data = after.data();
    if (!data) return;
    if (data.status !== "published" || data.moderationState !== "active" ||
        !["public", "followers"].includes(String(data.visibility)) ||
        data.fanoutCompletedAt) return;

    const authorId = String(data.authorId ?? "");
    if (!authorId) return;
    const database = getFirestore();
    let cursor: QueryDocumentSnapshot | undefined;
    let delivered = 0;

    while (true) {
      let query = database.collection(collections.users)
        .doc(authorId).collection("followers")
        .orderBy("__name__")
        .limit(batchSize);
      if (cursor) query = query.startAfter(cursor);
      const followers = await query.get();
      if (followers.empty) break;

      const batch = database.batch();
      for (const follower of followers.docs) {
        const recipientId = follower.id;
        const entryRef = database.collection(collections.feedEntries)
          .doc(`${recipientId}--${after.id}`);
        batch.set(entryRef, {
          recipientId,
          postId: after.id,
          authorId,
          source: "following",
          rankingScore: Number(data.rankingScore ?? 0),
          publishedAt: data.publishedAt ?? Timestamp.now(),
          createdAt: Timestamp.now(),
          schemaVersion: currentSchemaVersion,
        }, {merge: true});
      }
      await batch.commit();
      delivered += followers.size;
      cursor = followers.docs.at(-1);
      if (followers.size < batchSize) break;
    }

    await after.ref.update({
      fanoutCompletedAt: Timestamp.now(),
      fanoutRecipientCount: delivered,
      updatedAt: Timestamp.now(),
    });
  },
);
