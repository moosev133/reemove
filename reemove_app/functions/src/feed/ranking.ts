export type RankingSignals = {
  likes: number;
  comments: number;
  saves: number;
  reposts: number;
  views: number;
  isReel?: boolean;
  isVerifiedAuthor?: boolean;
};

function bounded(value: number, maximum = 1_000_000): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(maximum, value));
}

export function contentRankingScore(signals: RankingSignals): number {
  const score =
    bounded(signals.likes) * 3 +
    bounded(signals.comments) * 4 +
    bounded(signals.saves) * 5 +
    bounded(signals.reposts) * 7 +
    bounded(signals.views) * 0.08 +
    (signals.isReel ? 8 : 0) +
    (signals.isVerifiedAuthor ? 4 : 0);
  return Math.round(score * 100) / 100;
}

export function initialContentRankingScore(
  kind: "post" | "reel",
  isVerifiedAuthor: boolean,
): number {
  return contentRankingScore({
    likes: 0,
    comments: 0,
    saves: 0,
    reposts: 0,
    views: 0,
    isReel: kind === "reel",
    isVerifiedAuthor,
  });
}
