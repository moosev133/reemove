# Rollback plan — ReeMove

## Principles

1. Prefer **redeploy last known-good tag** over emergency live edits.  
2. Keep **client store rollouts** and **Firebase backend** rollbacks independent when possible.  
3. Never paste secrets into chat or commits during an incident.

## Client (Play / App Store)

| Symptom | Action |
|---------|--------|
| Crashes / bad build | Halt staged rollout; hold at last good percentage |
| Critical security | Halt to 0%; yank if policy allows; force-update via Remote Config `force_update` + min builds |
| Feature blast radius | Disable flags in Remote Config (`marketplace_enabled`, `ai_modules_enabled`, etc.) — **note:** UI must enforce flags (tracked debt) |

## Firebase backend

| Symptom | Action |
|---------|--------|
| Bad Functions | Redeploy Functions from previous release tag |
| Bad rules locking users out | Redeploy previous `firestore.rules` / `storage.rules` from that tag |
| Bad indexes | Avoid deleting indexes under pressure; restore from tagged `firestore.indexes.json` if a change caused query failures |
| OpenAI incident | Rotate secret; temporarily disable AI callables / set RC `ai_modules_enabled=false` once UI gates exist |

## Maintenance mode

Set Remote Config:

- `maintenance_mode=true`
- Meaningful `maintenance_title` / `maintenance_message`
- Ensure `status_url` points at a public status page

App shows `MaintenanceModeScreen` when Firebase + RC are reachable.

## Communication

1. Status page update  
2. Internal incident channel  
3. Postmortem within 48h  

## Cursor limits

Cursor will not run production rollback deploys without **explicit deployment approval** naming the target tag and environment.

See also: `docs/ROLLBACK_INCIDENT_RESPONSE.md`, `docs/BACKUP_RESTORE_DISASTER_RECOVERY.md`.
