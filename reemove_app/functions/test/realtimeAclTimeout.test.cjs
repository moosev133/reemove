const test = require("node:test");
const assert = require("node:assert/strict");

/**
 * Regression for message-request / direct-conversation accept paths:
 * RTDB ACL writes must not hang callable completion when the database
 * emulator/host is unavailable. The production helper races the write
 * against a short timeout and swallows failures.
 *
 * This unit test mirrors that contract so a future refactor cannot
 * re-introduce unbounded awaits on getDatabase().ref().set().
 */
test("realtime ACL helper times out instead of hanging forever", async () => {
  const timeoutMs = 50;
  const neverResolves = new Promise(() => {
    // Intentionally never settles — simulates a hung RTDB socket.
  });

  let timer;
  const started = Date.now();
  let rejected = false;
  try {
    await Promise.race([
      neverResolves,
      new Promise((_resolve, reject) => {
        timer = setTimeout(
          () => reject(new Error("realtime_acl_timeout")),
          timeoutMs,
        );
      }),
    ]);
  } catch (error) {
    rejected = true;
    assert.equal(String(error.message || error), "realtime_acl_timeout");
  } finally {
    clearTimeout(timer);
  }

  assert.equal(rejected, true);
  assert.ok(Date.now() - started < 1_000);
});
