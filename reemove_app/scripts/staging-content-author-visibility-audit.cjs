#!/usr/bin/env node
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore, FieldPath} = require("firebase-admin/firestore");
const {
  resolveAuthorAccountVisibility,
} = require("../functions/lib/feed/contentAuthorVisibilityBackfill.js");

const PROJECT_ID = "reemove-staging";
const BATCH = 200;
const MAX_SCAN = 5000;

function init() {
  if (getApps().length === 0) {
    initializeApp({projectId: PROJECT_ID});
  }
  return getFirestore();
}

async function auditCollection(db, collection) {
  const stats = {
    collection,
    scanned: 0,
    missingAuthorAccountVisibility: 0,
    riskyMissingWithNonPublicAuthor: 0,
    samples: [],
  };
  let cursor;
  while (stats.scanned < MAX_SCAN) {
    let query = db.collection(collection)
      .orderBy(FieldPath.documentId())
      .limit(BATCH);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const authorIds = [...new Set(snapshot.docs.map((doc) =>
      String(doc.get("authorId") ?? ""),
    ).filter(Boolean))];
    const authorDocs = authorIds.length > 0 ?
      await db.getAll(...authorIds.map((id) => db.collection("users").doc(id))) :
      [];
    const authors = new Map(authorDocs.map((doc) => [doc.id, doc]));

    for (const document of snapshot.docs) {
      stats.scanned += 1;
      const field = document.get("authorAccountVisibility");
      if (field === "public" || field === "followers" || field === "private") {
        continue;
      }
      stats.missingAuthorAccountVisibility += 1;
      const authorId = String(document.get("authorId") ?? "");
      const author = authors.get(authorId);
      const authorVisibility = author?.exists ?
        resolveAuthorAccountVisibility(author) :
        "public";
      if (authorVisibility !== "public") {
        stats.riskyMissingWithNonPublicAuthor += 1;
        if (stats.samples.length < 10) {
          stats.samples.push({
            id: document.id,
            authorId,
            authorVisibility,
            contentVisibility: document.get("visibility") ?? null,
          });
        }
      }
    }

    cursor = snapshot.docs.at(-1).id;
    if (snapshot.size < BATCH) break;
  }
  return stats;
}

async function main() {
  const db = init();
  const posts = await auditCollection(db, "posts");
  const stories = await auditCollection(db, "stories");
  console.log(JSON.stringify({projectId: PROJECT_ID, posts, stories}, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
