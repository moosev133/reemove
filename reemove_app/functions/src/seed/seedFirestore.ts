import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

import {seedDocuments} from "./seedData";

async function seedFirestore(): Promise<void> {
  const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;
  if (!emulatorHost) {
    throw new Error(
      "Refusing to seed without FIRESTORE_EMULATOR_HOST. This script is emulator-only.",
    );
  }

  const projectId = process.env.GCLOUD_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    "demo-reemove";

  if (!projectId.startsWith("demo-")) {
    throw new Error(`Refusing to seed non-demo Firebase project: ${projectId}`);
  }

  if (getApps().length === 0) {
    initializeApp({projectId});
  }

  const database = getFirestore();
  let batch = database.batch();
  let operationCount = 0;

  for (const document of seedDocuments) {
    batch.set(database.doc(document.path), document.data, {merge: true});
    operationCount += 1;

    if (operationCount % 400 === 0) {
      await batch.commit();
      batch = database.batch();
    }
  }

  if (operationCount % 400 !== 0) {
    await batch.commit();
  }

  process.stdout.write(`Seeded ${operationCount} ReeMove documents into ${projectId}.\n`);
}

seedFirestore().catch((error: unknown) => {
  process.stderr.write(`${String(error)}\n`);
  process.exitCode = 1;
});
