const assert = require("node:assert/strict");
const {readFileSync} = require("node:fs");
const {describe, it} = require("node:test");

describe("staging publish deployment manifest", () => {
  it("exports publishPost from the functions source entrypoint", () => {
    const source = readFileSync(
      require("node:path").join(__dirname, "../src/index.ts"),
      "utf8",
    );
    assert.match(source, /publishPost/);
    assert.match(source, /from "\.\/feed\/publishContent"/);
  });
});
