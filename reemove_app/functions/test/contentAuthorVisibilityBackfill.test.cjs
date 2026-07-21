const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  planContentAuthorVisibilityUpdate,
  resolveAuthorAccountVisibility,
} = require("../lib/feed/contentAuthorVisibilityBackfill.js");

function doc(id, data) {
  return {
    id,
    exists: true,
    get(field) {
      return data[field];
    },
  };
}

describe("content author visibility backfill", () => {
  it("derives author visibility from account privacy", () => {
    assert.equal(
      resolveAuthorAccountVisibility(doc("u1", {visibility: "followers"})),
      "followers",
    );
    assert.equal(
      resolveAuthorAccountVisibility(doc("u2", {
        accountPrivacy: "private",
        visibility: "public",
      })),
      "public",
    );
  });

  it("plans updates only when authorAccountVisibility is missing", () => {
    const plan = planContentAuthorVisibilityUpdate(
      "posts",
      doc("post-1", {authorId: "author-1", schemaVersion: 1}),
      doc("author-1", {visibility: "followers"}),
    );
    assert.ok(plan);
    assert.equal(plan.updates.authorAccountVisibility, "followers");

    const skipped = planContentAuthorVisibilityUpdate(
      "posts",
      doc("post-2", {
        authorId: "author-1",
        authorAccountVisibility: "public",
      }),
      doc("author-1", {visibility: "public"}),
    );
    assert.equal(skipped, null);
  });
});
