# Social feed implementation

## Architecture

The feed module follows the same project boundary used by earlier phases:

```text
presentation -> application -> domain <- data
```

Domain entities contain no Firebase, Storage, image-picker, connectivity, or video-player types. Riverpod composes repositories and platform services.

## Domain contracts

- `FeedPost`, `FeedAuthor`, `FeedViewerState`
- `FeedPage`, `FeedCursor`, `FeedMode`
- `PostComment`, `CommentPage`, `ReactionMutationResult`
- `Story`, `StoryGroup`
- `ContentDraft`, `DraftMediaSelection`
- `MediaUploadStatus`
- `ContentReportRequest`
- `FeedRepository`
- `PostInteractionRepository`
- `StoryRepository`
- `ContentPublishingRepository`
- `ContentDraftRepository`
- `ContentMediaPicker`

## Feed queries

### For You

Published, active, public posts are ordered by:

1. `rankingScore DESC`
2. `publishedAt DESC`
3. document ID

The client uses an opaque typed cursor carrying those exact values. Queries are bounded to Security Rules limits. The repository overscans to compensate for locally hidden authors.

### Following

`fanoutPublishedPost` writes deterministic `feed_entries` for followers when a post becomes published. The client queries only entries where `recipientId` equals the authenticated UID, then resolves accessible posts. Repeated trigger execution is idempotent because entry IDs are deterministic and `fanoutCompletedAt` closes the operation.

### Blocking

A block creates:

- `users/{blocker}/blocks/{blocked}`
- `users/{blocked}/blocked_by/{blocker}`

Only the owner of each private index can list it. Feed, reels, and stories combine both sets before rendering. Direct post and story reads still call the Security Rules block predicate in both directions. Existing follow edges are removed atomically with the block.

## Ranking contract

The server computes a deterministic engagement score from bounded counters. Comments, saves, reposts, and likes have stronger weights than views. Reels and verified authors receive small discovery priors. Invalid or negative counters are clamped. Ranking is not an ML model; its function boundary is intentionally replaceable by a future remote ranking service without changing presentation or domain code.

## Interaction ownership

Client writes never mutate post counters or reaction records directly. Callable Functions own:

- post reactions
- comments and comment likes
- unique views
- story views/deletion
- reports
- blocks

Optimistic UI updates are rolled back or reconciled from the callable response.

Reaction document IDs are deterministic (`{uid}--{targetId}`), allowing authorized reads even before the document exists. Saves remain private. Reposts additionally create server-owned `reposts` records.

## Publishing flow

1. User selects media and edits a local draft.
2. Draft changes persist through `ContentDraftRepository`.
3. Media uploads to `content/{uid}/{draftId}/{assetId}/{filename}` with trusted metadata.
4. Callable publishing re-reads Storage metadata and validates ownership, media type, size, draft ID, asset ID, profile status, audience, sport, and text policy.
5. Images are published immediately.
6. Videos create/merge `media_assets` and `media_jobs`; the post remains `processing`.
7. A scheduled dispatcher sends queued work to the configured processor.
8. The processor writes under `processed/{uid}/{assetId}/...` and calls the authenticated completion endpoint.
9. The callback verifies output ownership, replaces the linked media, and publishes the post when all media is ready.

The external processor is an infrastructure adapter, not part of the Flutter application. See `MEDIA_PROCESSING_SETUP.md`.

## Offline behavior

Firestore reads use `Source.serverAndCache` and can fall back to the SDK cache on supported platforms. Local composer drafts survive app restarts independently of Firestore. Pending mutations are not represented as successful until the callable Function confirms them.

## UI surfaces

- Home feed with For You/Following switching
- Story rail and story viewer
- Feed post card and carousel
- Inline video player
- Comments bottom sheet
- Post report/block sheet
- Post/reel/story composer
- Immersive reels screen
- Deep-linked post detail
- Loading, empty, failure, offline, upload, and processing states

## Known release gates

Before production release, run real-device tests for memory pressure, background/foreground video behavior, interrupted uploads, low bandwidth, image decoding, long feeds, screen readers, text scaling, RTL, and all audience/block combinations.
