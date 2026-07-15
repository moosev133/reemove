const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  extractHashtags,
  extractMentions,
  normalizeUserText,
  parseCommentText,
  parsePublishRequest,
} = require("../lib/feed/contentPolicy.js");

function image(id = "image-1") {
  return {
    id,
    storagePath: `content/user/draft/${id}/photo.jpg`,
    kind: "image",
    processingState: "ready",
  };
}

function video(id = "video-1") {
  return {
    id,
    storagePath: `content/user/draft/${id}/clip.mp4`,
    kind: "video",
    processingState: "pending",
  };
}

describe("content publishing policy", () => {
  it("normalizes a valid image post", () => {
    const parsed = parsePublishRequest({
      draftId: "draft",
      kind: "post",
      caption: "  Morning run #Running @move.fast  ",
      media: [image()],
      visibility: "public",
      allowComments: true,
    });
    assert.equal(parsed.caption, "Morning run #Running @move.fast");
    assert.equal(parsed.media.length, 1);
    assert.equal(parsed.visibility, "public");
  });

  it("accepts one video reel and rejects invalid media combinations", () => {
    assert.equal(parsePublishRequest({
      draftId: "draft",
      kind: "reel",
      caption: "Sprint work",
      media: [video()],
      visibility: "public",
    }).kind, "reel");

    assert.throws(() => parsePublishRequest({
      draftId: "draft",
      kind: "reel",
      caption: "Not a reel",
      media: [image()],
      visibility: "public",
    }), (error) => error.code === "invalid-argument");

    assert.throws(() => parsePublishRequest({
      draftId: "draft",
      kind: "post",
      caption: "Mixed media",
      media: [video(), image()],
      visibility: "public",
    }), (error) => error.code === "invalid-argument");
  });

  it("enforces story media and caption limits", () => {
    assert.throws(() => parsePublishRequest({
      draftId: "draft",
      kind: "story",
      caption: "x".repeat(281),
      media: [image()],
      visibility: "followers",
    }), (error) => error.code === "invalid-argument");
    assert.throws(() => parsePublishRequest({
      draftId: "draft",
      kind: "story",
      caption: "Two frames",
      media: [image("a"), image("b")],
      visibility: "followers",
    }), (error) => error.code === "invalid-argument");
  });
});

describe("content text policy", () => {
  it("extracts unique normalized hashtags and mentions", () => {
    assert.deepEqual(
      extractHashtags("#Running today #running with #Gym_Life"),
      ["running", "gym_life"],
    );
    assert.deepEqual(
      extractMentions("@Move.Fast hi @move.fast and @runner_26"),
      ["move.fast", "runner_26"],
    );
  });

  it("removes unsafe control characters and validates comments", () => {
    assert.equal(normalizeUserText("  move\u0000 now\r\n  "), "move now");
    assert.equal(parseCommentText(" Great session! "), "Great session!");
    assert.throws(
      () => parseCommentText("x".repeat(2201)),
      (error) => error.code === "invalid-argument",
    );
  });
});

describe("feed ranking policy", () => {
  const {contentRankingScore, initialContentRankingScore} = require("../lib/feed/ranking.js");

  it("weights meaningful engagement and preserves deterministic scores", () => {
    assert.equal(initialContentRankingScore("post", false), 0);
    assert.equal(initialContentRankingScore("reel", true), 12);
    assert.equal(contentRankingScore({
      likes: 10,
      comments: 2,
      saves: 3,
      reposts: 1,
      views: 100,
      isReel: false,
      isVerifiedAuthor: false,
    }), 68);
  });

  it("clamps invalid and negative counters", () => {
    assert.equal(contentRankingScore({
      likes: -5,
      comments: Number.NaN,
      saves: 0,
      reposts: 0,
      views: -1,
    }), 0);
  });
});
