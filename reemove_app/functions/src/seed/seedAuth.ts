import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

const demoUsers = [
  {
    uid: "demo-athlete",
    email: "athlete@demo.reemove.app",
    password: "ReeMoveDemo123!",
    displayName: "ReeMove Athlete",
    emailVerified: true,
  },
  {
    uid: "demo-newcomer",
    email: "newcomer@demo.reemove.app",
    password: "ReeMoveDemo123!",
    displayName: "ReeMove Newcomer",
    emailVerified: true,
  },
  {
    uid: "demo-runner",
    email: "runner@demo.reemove.app",
    password: "ReeMoveDemo123!",
    displayName: "Maya Runner",
    emailVerified: true,
  },
] as const;

async function seedAuth(): Promise<void> {
  const emulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!emulatorHost) {
    throw new Error(
      "Refusing to seed without FIREBASE_AUTH_EMULATOR_HOST. This script is emulator-only.",
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

  const auth = getAuth();
  for (const demoUser of demoUsers) {
    try {
      await auth.getUser(demoUser.uid);
      await auth.updateUser(demoUser.uid, {
        email: demoUser.email,
        password: demoUser.password,
        displayName: demoUser.displayName,
        emailVerified: demoUser.emailVerified,
        disabled: false,
      });
      process.stdout.write(`Updated emulator user ${demoUser.email}.\n`);
    } catch (error: unknown) {
      const code = typeof error === "object" && error !== null && "code" in error ?
        String((error as {code?: unknown}).code) : "";
      if (code !== "auth/user-not-found") throw error;

      await auth.createUser(demoUser);
      process.stdout.write(`Created emulator user ${demoUser.email}.\n`);
    }
  }
}

seedAuth().catch((error: unknown) => {
  process.stderr.write(`${String(error)}\n`);
  process.exitCode = 1;
});
