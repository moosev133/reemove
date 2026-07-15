# Challenges implementation

## Architecture

Phase 11 follows the existing presentation → application → domain ← data boundary. Domain models contain no Firebase types. `FirebaseChallengeRepository` owns Firestore, Storage, Auth, and callable Functions integration. Riverpod providers expose catalog, detail, participation, submissions, leaderboard, badges, rewards, history, and mutation state.

## Catalog and routes

Active/public/moderated challenges are available from Discover, every sport hub, and the Create menu. Routes include the catalog, detail, create, progress submission, organizer review, rewards/history, and the protected `/ch/:challengeId` alias.

Catalog queries are bounded, sport-filterable, ordered by feature state and end time, and cursor-paginated. Direct detail access still requires visibility/creator/administrator authorization.

## Trusted participation

Clients cannot write challenge documents or subcollections directly. Callable Functions own:

- challenge creation;
- join and leave;
- reminder opt-in/out;
- progress submission;
- organizer approval/rejection;
- reward claim;
- proof-review URL creation.

Transactions protect participant progress, daily accounting, used-activity markers, submissions, leaderboards, participant/completion counters, badges, and reward claims. Client retries are designed not to double-credit progress or rewards.

## Verified activity flow

For automatic or combined verification, the app queries only the signed-in user’s verified activities for the correct sport and challenge occurrence window. The UI displays a readable date and relevant metric instead of an internal ID.

The server does not trust this filtered list. It rechecks:

1. activity existence and ownership;
2. verified status;
3. sport match;
4. occurrence within challenge start/end;
5. metric sufficiency for the submitted amount;
6. absence of a prior `used_activities` marker.

## Proof and organizer review

Proof is uploaded to an owner-scoped path with exact metadata. Storage Rules deny public/organizer direct reads. An authorized creator, administrator, or eligible community manager can request a five-minute signed URL. URL issuance is rate-limited and audited.

Pending or flagged submissions show trusted athlete identity, progress, note, risk score, and risk reasons. Approval applies verified progress transactionally; rejection preserves the audit trail without crediting progress.

## Safety and anti-cheat

The policy layer allowlists metrics and units and applies conservative target/daily caps. It rejects unsafe challenge language and invalid schedules, enforces minimum-age eligibility, and stores rest/effort guidance. The anti-cheat scorer considers abrupt progress jumps, activity/proof inconsistencies, duplicates, and daily limits. High-risk submissions require human review rather than being auto-awarded.

## Automation

Scheduled Functions:

- generate curated weekly challenges;
- refresh active leaderboards;
- finalize expired challenges;
- send reminders to opted-in participants.

An administrator-only callable supports controlled generation in non-production and incident recovery. External model-generated copy remains disabled until Phase 14.

## Data ownership

Public: active challenge catalog, public detail, and leaderboard projection.

Owner-private: participation, history, earned badges, reward claims, activity choices, and own submissions.

Manager-private: pending/flagged submissions and short-lived proof review.

Server-only: writes, used-activity markers, ranking/counter calculation, reward issuance, and scheduled automation.
