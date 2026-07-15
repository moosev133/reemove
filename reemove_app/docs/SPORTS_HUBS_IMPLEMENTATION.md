# Sports hubs implementation — Phase 9

## Scope

Phase 9 completes the first three production sport modules: **football, gym, and running**. Each module uses one shared Clean Architecture slice rather than separate hard-coded feature trees. This keeps sport-specific labels and capabilities configurable while preserving one repository, security, routing, and UI contract for future sports.

## Shared module contract

`SportModuleRegistry` defines the launch modules and their capabilities:

- Football: pitches/facilities, teams and groups, matches/training, challenges, rankings, trainers, and relevant pricing.
- Gym: gyms/studios, workout groups, classes/sessions, challenges, training-volume rankings, trainers, and services/pricing.
- Running: routes/tracks, clubs, group runs/races, challenges, distance/pace rankings, and coaches.

Unknown sport IDs resolve to a safe generic module with the common catalog features. Adding basketball, tennis, swimming, cycling, MMA, or another sport therefore requires catalog/configuration additions rather than changes to navigation or repository architecture.

## Client architecture

The feature is split into:

- Domain entities for communities, community members, trainers, services, leaderboards, participation, and typed management requests.
- Firebase-independent repository contracts for catalogs and hub interactions.
- Firestore DTOs/converters/mappers isolated in the data layer.
- A Firebase repository for live reads and callable mutations.
- Riverpod providers for lists, details, membership, attendance, and action state.
- Responsive screens and reusable cards for every catalog type.

No presentation widget calls Firebase directly.

## Implemented user flows

### Hub overview

Each sport hub presents live previews of places, communities, upcoming events, active challenges, trainers, and leaderboards. Quick actions open the full catalog or creation flow. Empty, loading, error, and refresh states are explicit.

### Places and routes

Users can browse sport-filtered public places, view location, facility details, sports supported, rating, amenities, contact/pricing information, and use the stable detail route. Running routes are represented through the shared place contract until Phase 10 adds map/list synchronization and route geometry.

### Communities

Users can browse teams, clubs, training groups, and social groups; inspect capacity, join policy, location, pricing, tags, and member roster; join open groups; request approval; or leave. Owners and administrators can approve/reject pending requests, and owners cannot leave without a future ownership transfer flow.

### Events

Users can browse upcoming matches, training sessions, classes, meetups, competitions, and community events; inspect level range, location, capacity, price, and schedule; join, waitlist, or leave. Event organizers are enrolled atomically during creation, and the earliest waitlisted athlete is promoted when an attending user cancels.

### Trainers and pricing

Active trainer profiles expose specialties, experience, location, rating, accepting-client status, and sport-specific services. Verified trainer/business accounts can create or update bounded service offers with type, delivery mode, duration, and ISO currency pricing.

### Leaderboards

A scheduled Function aggregates verified activity documents into weekly football match-points, gym training-volume, and running-distance rankings. Only server-owned published snapshots are readable. An administrator-only callable supports controlled rebuilds.

## Trusted backend operations

The following callable Functions own relationship-sensitive writes:

- `createSportCommunity`
- `joinSportCommunity`
- `leaveSportCommunity`
- `respondSportCommunityRequest`
- `createSportsEvent`
- `attendSportsEvent`
- `leaveSportsEvent`
- `upsertTrainerService`
- `rebuildSportLeaderboardsNow` (administrator only)

`refreshSportLeaderboards` runs every six hours. Functions validate input, active sport configuration, profile status, trainer verification, capacity, time ranges, levels, pricing, App Check context, rate limits, counters, and audit events.

## Security model

- Public active places, events, teams, trainer catalogs, services, and published leaderboards require authentication, except the existing public sports catalog.
- Community rosters expose only active, non-removed members; pending requests stay private.
- Event attendance is readable only by the attendee or an administrator.
- Activities are readable only by their owner.
- Direct client writes to teams, memberships, event attendance/counters, trainer profiles/services, leaderboards, and activities are denied.
- Composite indexes match every shipped query.

## Phase boundary

Phase 9 intentionally does not implement Google Maps, geohash radius searching, route polylines, map clustering, or nearby people. Those are Phase 10 responsibilities. Phase 9 supplies the typed place/event/community data and stable routes Phase 10 will visualize.
