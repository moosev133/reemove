# Marketplace implementation

## Product surface

Marketplace is available from Discover, each sport hub, Create, and the owner Profile. The primary flows are:

- catalog search and filtering;
- listing detail and seller profile;
- favorites and owner listing library;
- create, edit, publish, reserve, sell, pause, reactivate, relist, and remove;
- trusted listing conversation;
- report and moderation review.

## Layering

```text
presentation
  Marketplace screens, cards, filters, composer, listing-chat banner
application
  Riverpod catalog, detail, seller, favorites, owner-library, media, and action state
domain
  listing, seller, filters, requests, repository, and media contracts
data
  Firestore/callable/Storage DTOs, mappers, repositories, and platform picker
backend
  trusted Cloud Functions, scheduled expiry, policy modules, Rules, indexes, seed data
```

Widgets never write marketplace Firestore documents directly.

## Trusted listing lifecycle

1. `createMarketplaceListing` creates an owner draft with a generated or retry-stable listing ID.
2. The client uploads owner-scoped photos using path- and metadata-bound Storage objects.
3. `updateMarketplaceListing` verifies every referenced object, validates the draft, rounds any public pickup location, and removes only media no longer referenced after the update succeeds.
4. `publishMarketplaceListing` re-verifies ownership, media, policy, price, location, and moderation state before activating the listing.
5. `changeMarketplaceListingStatus` owns reserve, sell, pause, reactivate, relist, and removal transitions.
6. `expireMarketplaceListings` moves elapsed active/reserved listings to expired state.
7. `reviewMarketplaceListing` applies administrator moderation decisions and writes audit state.

Counters, timestamps, moderation fields, status transitions, seller snapshots, location precision, and search fields are server-owned. Phase 12 launches with ILS only; the money value object remains ISO-currency-ready, but additional currencies require currency-aware filters, sorting, and policy review before enablement.

## Discovery and search

`searchMarketplace` accepts bounded filters for:

- keyword;
- category and sport;
- condition;
- minimum/maximum price and currency;
- delivery option;
- seller exclusion;
- distance radius;
- newest, oldest, price, or distance sort;
- cursor/page limit.

The Function validates every filter, retrieves a bounded indexed candidate set, applies block/moderation/status/expiry checks, exact distance filtering, and a deterministic sort/cursor policy before returning sanitized DTOs.

### Scaling boundary

The Firestore candidate window is suitable for the current seed/staging catalog and keeps the first production release operationally simple. It is not presented as an unbounded full-text search engine. Before either of these release thresholds is exceeded, move the server adapter to a managed search/index provider:

- more than 10,000 concurrently active listings in an environment; or
- p95 catalog search latency above 500 ms during representative load tests.

The domain request/response and Flutter repository contracts remain unchanged during that migration.

## Privacy and safety

- Exact private location is never copied into marketplace documents.
- Public pickup coordinates are rounded server-side before storage and display.
- Seller locality appears only when the seller has allowed it.
- Both directions of a block hide listings and seller access.
- Seller visibility is independent from message permission; starting chat rechecks the seller's actual message-audience policy.
- Favorites and owner listing history are private.
- Reports and moderation queues are server-owned.
- Prohibited/regulated-item language is denied by policy validation.
- Listings include safe transaction guidance and do not implement payments or escrow.
- Clients cannot manufacture favorites, views, reports, counters, moderation state, or publication state.

## Listing conversations

`startMarketplaceConversation` verifies listing availability, buyer/seller identity, reciprocal blocks, and the seller's messaging policy. It creates or reuses a deterministic direct conversation and stores listing context in a server-owned thread record. The existing messaging feature renders the listing banner and continues to enforce membership, attachment, report, and notification policies.

## Media

Listing photos use:

```text
marketplace/{ownerUid}/{listingId}/{assetId}
```

Storage Rules bind `ownerId`, `listingId`, `assetId`, `kind=image`, schema version, MIME type, and size to the path. An edit keeps successful uploads across retries. Removed images are deleted only after the server accepts the edited listing, preventing destructive client-side races.

## Moderation and operations

The backend writes normalized reports, moderation-queue records, rate-limit records, and audit events. Administrator review is a callable operation intended for the internal moderation console/operations workflow; the consumer app deliberately has no administrator moderation UI.

## Testing focus

- listing and filter normalization;
- prohibited-item wording;
- price/currency/delivery bounds;
- media count, MIME, and size limits;
- coordinates, radius, cursor, and pagination limits;
- draft/active/reserved/expired visibility;
- reciprocal blocks;
- private favorites;
- server-owned reports and counters;
- Storage path/metadata ownership;
- retry-safe draft and listing lifecycle behavior.
