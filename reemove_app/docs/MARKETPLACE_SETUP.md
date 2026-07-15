# Marketplace setup and release guide

## 1. Deploy coordinated backend resources

Deploy Functions, Firestore Rules, Storage Rules, and indexes as one release:

```bash
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions run build
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

Do not enable marketplace entry points until the required composite indexes report `READY`.

## 2. Seed non-production environments

```bash
npm run emulators:start
npm run seed:running-emulators
```

The seed includes marketplace categories, football/gym/running listings, seller snapshots, public pickup locations, listing statistics, and one demo favorite.

## 3. Configure policies

Before production, approve and publish:

- prohibited and regulated item policy;
- report reason taxonomy and moderation response targets;
- listing retention and evidence retention periods;
- ILS-only launch currency policy and a reviewed plan before any additional currency is enabled;
- seller and buyer safety guidance;
- age eligibility and local legal review;
- privacy disclosure for coarse pickup location;
- marketplace terms clarifying that ReeMove does not process payment or guarantee a transaction.

Keep the prohibited-term policy in source conservative. Policy expansion should be reviewed, tested, versioned, and deployed server-side.

## 4. Storage and lifecycle

Verify:

- owner-only draft uploads;
- authenticated reads only for allowed listing content;
- maximum image count, size, and supported MIME types;
- removed-object cleanup after accepted edits;
- account-deletion cleanup for marketplace media;
- lifecycle Scheduler permissions and monitoring;
- expired, reserved, sold, removed, and rejected retention behavior.

## 5. Search capacity and migration gate

Load test representative production filters and sort orders. The bundled Firestore candidate adapter is allowed only while:

- active inventory remains at or below 10,000 listings per environment; and
- p95 search latency remains at or below 500 ms.

Crossing either threshold requires a managed search/index adapter, backfill, dual-read validation, and rollback plan before additional rollout. Do not add client-side collection scans as a workaround.

## 6. Moderation operations

Provision administrator claims through the controlled server process. Test:

- report idempotency;
- report queue creation;
- approve/reject/remove review actions;
- seller/listing block behavior;
- audit records;
- policy false-positive escalation;
- removed-media and retained-evidence handling;
- incident rollback and feature kill switch.

The administrator callable must be invoked only from the internal operations console or approved tooling.

## 7. Staging test matrix

Test on at least two real devices/accounts:

- create, interrupted upload, retry, edit, publish, pause, reactivate, reserve, sell, expire, relist, and remove;
- eight-photo limit, unsupported type, oversize image, forged metadata, and deleted object;
- keyword/category/sport/condition/price/currency/delivery/distance/sort filters;
- exact-distance correctness around radius boundaries;
- favorites and owner-library privacy;
- public seller display, hidden locality, private profile, both block directions, and message-audience denial;
- deterministic listing chat and listing-context banner;
- duplicate reports and administrator review;
- account deletion and media cleanup;
- accessibility, RTL, large text, offline/retry behavior, and dark/light themes.

## 8. Required release commands

```bash
python3 scripts/validate_repository.py
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions run build
npm --prefix functions run test:unit
npm --prefix firebase_tests ci
npm run test:rules
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build appbundle
flutter build ipa
```

Production rollout remains blocked until every command and the staging test matrix pass.
