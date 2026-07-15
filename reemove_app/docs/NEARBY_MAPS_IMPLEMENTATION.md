# Nearby maps implementation

## Architecture

```text
NearbyDiscoveryScreen
  -> NearbyDiscoveryController (Riverpod)
  -> NearbyRepository
  -> Firebase callable searchNearby
  -> server-owned nearby_entities geohash index
```

`PlatformNearbyLocationService` is the only platform-location adapter. Domain entities use plain `GeoLocation`; Firebase `GeoPoint`, callable payloads, and Google Maps `LatLng` remain in data/presentation boundaries.

## Search flow

1. The user explicitly grants location permission when opening Nearby.
2. The device coordinate is used as the search center and may be stored privately through `updateDiscoveryLocation`.
3. The Function validates latitude/longitude, radius (1–100 km), entity types, sports, and result limit.
4. Firebase geohash bounds produce candidate queries against `nearby_entities`.
5. The server removes duplicates, expired events, blocked owners, incompatible age segments, and sport/type mismatches.
6. Exact distance filtering removes geohash false positives.
7. Results are sorted by distance and returned with privacy-safe labels.

## Index synchronization

- `places/{id}` -> precise public place marker.
- `events/{id}` -> precise public published event marker.
- `sports_routes/{id}` -> precise route-start marker plus bounded path preview.
- `users/{uid}` plus private preference/profile triggers -> coarse person marker only when public, active, onboarded, and opted into nearby people.

Profile, preference, and private-age changes all resynchronize the person index, preventing stale privacy settings.

## Client experience

Compact screens switch between map and list. Wide screens show both simultaneously. Selecting either a card or marker updates the shared selection state; the map animates to the selection and the list highlights it. Google Maps' native cluster manager reduces marker density. Routes render a polyline in discovery and a full path on the detail screen.

## Privacy and abuse controls

- Exact user coordinates stay under `users/{uid}/private/preferences`.
- Public profile coordinates and person-index coordinates are deliberately coarse.
- People display approximate integer-kilometre distance wording.
- Minors and adults are not returned to each other's nearby-person searches.
- Both outgoing blocks and `blocked_by` records are filtered.
- Event and route owners are checked against blocks.
- Search is authenticated, App Check-protected, rate-limited, bounded, and audited for location updates.
- `nearby_entities` is denied to every client in Firestore Rules.
