# Firebase deployment plan — ReeMove

## Goals

Deploy backend artifacts to **staging** first, then **production**, with clear separation and no secrets in Git.

## Artifacts

| Artifact | Path |
|----------|------|
| Rules | `firestore.rules`, `storage.rules`, `database.rules.json` |
| Indexes | `firestore.indexes.json` |
| Functions | `functions/` (Node 22, region `europe-west1`) |
| Remote Config | `remoteconfig.template.json` |
| Emulators (local only) | `firebase.json` — Firestore **8180**, project `demo-reemove` |

## Projects and aliases

| Alias | Purpose |
|-------|---------|
| `development` | Local / synthetic |
| `staging` | Tester data |
| `production` | Real users |

Local: copy `.firebaserc.example` → `.firebaserc` (gitignored) with real IDs.

CI: workflows write `.firebaserc` from GitHub Environment **vars**:

- `FIREBASE_STAGING_PROJECT_ID`
- `FIREBASE_PRODUCTION_PROJECT_ID`

## Secrets (names only)

| Name | Where |
|------|--------|
| `OPENAI_API_KEY` | Functions Secret Manager |
| Media processor secrets | Functions params/secrets |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | GitHub Environment secrets |
| `GCP_FIREBASE_DEPLOYER_SERVICE_ACCOUNT` | GitHub Environment secrets |

Use **different** WIF service accounts for staging vs production Environments.

## Staging procedure

1. Owner approval to deploy staging.
2. Ensure rules tests + Functions build green on a machine with enough disk.
3. Trigger `.github/workflows/deploy-staging.yml` (`staging` branch or `workflow_dispatch`).
4. Confirm App Check **monitor** mode; Remote Config published.
5. Run `scripts/firebase/post_deploy_smoke.sh` if `PUBLIC_STATUS_BASE_URL` is set.

## Production procedure

1. Signed immutable git tag on the approved commit.
2. Written approval: “Deploy production Firebase for tag X”.
3. Trigger `deploy-firebase-production.yml` with that tag.
4. Workflow requires `RELEASE_APPROVED=true` and signed-tag verification.
5. Smoke checks + 30–60 minute watch on Functions errors / Crashlytics.

## Order of deploy

1. Firestore indexes  
2. Firestore rules  
3. Storage + RTDB rules  
4. Functions  
5. Remote Config  

Match `config/deployment_manifest.yaml`.

## Rollback

See `ROLLBACK_PLAN.md`. Prefer redeploying the previous known-good tag rather than editing rules live under pressure.

## Explicit non-actions for Cursor

- No production deploy without approval  
- No inventing project IDs  
- No committing `.firebaserc` or service-account JSON  
