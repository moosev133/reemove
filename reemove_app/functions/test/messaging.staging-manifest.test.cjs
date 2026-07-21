const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const {describe, it} = require("node:test");

describe("staging messaging deployment manifest", () => {
  it("exports messaging callables from the functions source entrypoint", () => {
    const source = readFileSync(
      require("node:path").join(__dirname, "../src/index.ts"),
      "utf8",
    );
    assert.match(source, /createDirectConversation/);
    assert.match(source, /sendMessage/);
    assert.match(source, /from "\.\/messaging\/conversations"/);
    assert.match(source, /from "\.\/messaging\/messages"/);
  });
});
