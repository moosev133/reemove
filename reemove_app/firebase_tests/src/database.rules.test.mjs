import fs from "node:fs";
import path from "node:path";
import {after, before, beforeEach, describe, it} from "node:test";
import {fileURLToPath} from "node:url";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {get, ref, set} from "firebase/database";

const dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(dirname, "../..");
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-reemove-database",
    database: {
      host: "127.0.0.1",
      port: 9000,
      rules: fs.readFileSync(path.join(projectRoot, "database.rules.json"), "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearDatabase();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await set(ref(context.database(), "messaging_acl/conversation-1/alice"), true);
    await set(ref(context.database(), "messaging_acl/conversation-1/bob"), true);
  });
});

after(async () => testEnv.cleanup());

describe("presence and typing rules", () => {
  it("allows members to publish their own valid ephemeral state", async () => {
    const db = testEnv.authenticatedContext("alice").database();
    await assertSucceeds(set(ref(db, "presence/conversation-1/alice"), {
      state: "online",
      lastChanged: Date.now(),
    }));
    await assertSucceeds(set(ref(db, "typing/conversation-1/alice"), {
      isTyping: true,
      updatedAt: Date.now(),
    }));
    await assertSucceeds(get(ref(db, "presence/conversation-1")));
  });

  it("denies outsiders, impersonation, and direct ACL mutation", async () => {
    const outsider = testEnv.authenticatedContext("outsider").database();
    const alice = testEnv.authenticatedContext("alice").database();
    await assertFails(get(ref(outsider, "typing/conversation-1")));
    await assertFails(set(ref(alice, "presence/conversation-1/bob"), {
      state: "online",
      lastChanged: Date.now(),
    }));
    await assertFails(set(ref(alice, "messaging_acl/conversation-1/alice"), false));
  });
});
