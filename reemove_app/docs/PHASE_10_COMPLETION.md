# Phase 10 completion — Nearby maps

Phase 10 completes ReeMove's geospatial discovery layer for places, people, events, matches, classes, and routes.

## Delivered

- Google Maps Flutter integration with Android/iOS key-injection automation.
- Adaptive synchronized map/list discovery.
- Built-in marker clustering, search-radius overlay, current-location display, selected-marker camera focus, and route polylines.
- Filters for radius, entity type, and football/gym/running.
- Server-side Firebase geohash bounds queries with exact Haversine-distance filtering.
- Server-owned `nearby_entities` search index synchronized from places, events, routes, and eligible profiles.
- Coarse public people coordinates, approximate distance labels, reciprocal block filtering, and separate minor/adult discovery segments.
- Private exact-location storage and trusted coarse public-location updates.
- Verified route detail screen with path, distance, elevation, duration, difficulty, surface, and safety context.
- Discover entry, sport-hub quick actions, and sport-filtered nearby routes.
- Firestore Rules, seed fixtures, backend unit tests, Rules test coverage, documentation, and deployment gates.

## Security decisions

Clients never read or write `nearby_entities` directly. Search is performed through an App Check-protected callable Function with authentication, validation, rate limiting, block filtering, age-segment filtering, sport/type filters, and a hard result cap. Public people locations are rounded before indexing and are never returned as exact coordinates.

## Exit gate

Phase 10 is source-complete when Functions lint/build/tests, repository validation, Dart grammar parsing, native setup idempotency, and archive integrity pass. Flutter analysis/native builds and the executable Firebase emulator suite remain mandatory staging gates on a Flutter/Java-equipped machine.
