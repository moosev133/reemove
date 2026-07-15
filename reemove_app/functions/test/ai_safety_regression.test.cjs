"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const corpusPath = path.resolve(__dirname, "../../quality/ai_red_team_cases.json");

test("AI regression corpus has unique IDs and release-blocking expectations", () => {
  const corpus = JSON.parse(fs.readFileSync(corpusPath, "utf8"));
  const ids = corpus.cases.map((item) => item.id);
  assert.equal(new Set(ids).size, ids.length);
  assert.ok(corpus.cases.some((item) => item.module === "matchmaker"));
  assert.ok(corpus.cases.some((item) => item.module === "nutrition"));
  assert.ok(corpus.cases.some((item) => item.module === "challenge"));
  for (const item of corpus.cases.filter((item) => item.releaseBlocking)) {
    assert.notEqual(item.expected, "allow_unconditionally");
  }
});

test("all Phase 14 AI modules have evaluation coverage", () => {
  const corpus = JSON.parse(fs.readFileSync(corpusPath, "utf8"));
  const covered = new Set(corpus.cases.map((item) => item.module));
  for (const required of [
    "coach",
    "workout",
    "nutrition",
    "matchmaker",
    "challenge",
    "trainer_insights",
  ]) {
    assert.ok(covered.has(required) || covered.has("all"), `Missing ${required}`);
  }
});
