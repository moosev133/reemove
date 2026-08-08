# Groups and Teams — Implementation Status

Evidence-based status for the sports **Groups and Teams** module on branch
`feature/groups-chat-media`. Derived from code, rules, and automated tests — not
from the legacy 16-phase roadmap (which predates this module).

**Last updated:** 2026-08-06  
**Verified staging QA:**
- **C2** member-chat (inbox → history → send/receive) passed after the reaction-query `.limit()` fix.
- **C3** schedules fully verified manually: training create, B RSVP Going + count, capacity block on A, session notification, owner cancel, RSVP unavailable after cancel.
- **Req #3 invitations** manually verified 2026-08-05: B followed A; A invited B; B accepted and joined.
- **Req #5 group-specific notifications** manually verified 2026-08-05: per-group mute + category toggles; backend suppression; Activity Accept/Decline for invitations.
- **Req #9 moderation** — **manually verified PASS** on staging (2026-08-06): owner/admin can delete another member message; non-managers cannot.

## Phase naming (repo evidence)

| Label | Meaning in this repo | Evidence |
|-------|----------------------|----------|
| **C1** | Foundation: privacy/join, roles, invites/requests, basic sessions, channel contracts | `scripts/staging-qa-groups-c1*.cjs`, merge `b33951f` |
| **C2** | Channels, messaging, media modes, view-once, **manager message delete (server)** | `staging-qa-groups-c2.cjs`, `deleteMessage` + `sportsManagerCanModerate` |
| **C3** | Typed schedules (training/match/event), RSVP, session notifications | **Verified on staging** (manual QA 2026-08-04) |

## Requirement checklist

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Public, private, and invitation-only group creation | **Complete** | `groupsPolicy.ts`; `create_edit_group_screen.dart`; C1 staging scripts |
| 2 | Owner, admin, and member roles | **Complete** | Role callables; `group_members_screen.dart`; permission matrix |
| 3 | Join requests and invitations | **Complete (staging-verified)** | Invite UI (`group_invite_screen.dart`, Manage row + overflow + Members FAB); `inviteToGroup` / `listGroupPendingInvitations`; Discover `@` username search; manual QA 2026-08-05 (follow → invite → accept → join) |
| 4 | Owner/admin member management | **Complete** | Remove/promote/demote/transfer; C1 QA |
| 5 | Group-specific notifications | **Complete (staging-verified)** | Per-group settings from group details; mute + member chat / announcements / sessions / invitations; backend inbox suppression; Activity Accept/Decline for join/invite; manual QA 2026-08-05 |
| 6 | Training, match, and event schedules | **Complete (C3, staging-verified)** | Typed sessions, RSVP, notifications, `staging-qa-groups-c3.cjs` |
| 7 | Group member chat | **Complete** | C2 channels + messaging; manual two-account QA |
| 8 | Owner/admin-only announcements channel | **Complete** | Publish gate; C2 policy/tests |
| 9 | Group media, replies, deletion, and moderation | **Complete (staging-verified 2026-08-06)** | Backend `deleteMessage` tombstone + attachment cleanup; Flutter manager delete menu verified with two accounts on staging |
| 10 | View-once and keep-in-chat pictures | **Complete** | Modes + claim URL + Storage deny |
| 11 | Group privacy and Firestore/Storage security rules | **Complete** | Groups block; channel media rules; rules suites |

## Automated totals (2026-08-05)

| Suite | Result |
|-------|--------|
| Functions unit | **141/141** |
| Integration (emulator) | **66/66** |
| Firebase rules (`npm run test:rules`) | **64/64** |
| Flutter resolver + moderation widget tests | see latest local run |
| Staging script `staging-qa-groups-moderation.cjs` | Requires ADC |
| Staging client | **http://127.0.0.1:7357** — rebuild after fix |

### Known runtime issue (req #9)
Resolved and verified manually on staging (2026-08-06).

## Moderation delete vertical slice

| Layer | Evidence |
|-------|----------|
| Backend | `deleteMessage` — sender window OR conversation admin OR `sportsManagerCanModerate`; soft tombstone; attachment cleanup under `groups/{id}/channels/…` |
| Flutter | `SportsGroupChannelContext.canModerate`; message menu shows manager **Delete message** for owner/admin on peer messages (staging-verified 2026-08-06) |
| Tests | `conversation_message_action_policy_test.dart`; integration `C2: sports managers delete peer messages`; rules tombstone write deny |
| Staging script | `scripts/staging-qa-groups-moderation.cjs` |

### Manual QA (two accounts, staging client)

1. Hard-refresh **http://127.0.0.1:7357** (Cmd+Shift+R).
2. **Account A** (owner/admin) sends a message in group **Member chat**.
3. **Account A** long-presses its own message → **Delete message** (subtitle: Remove for everyone) → confirm → snackbar **Message removed**; bubble shows **Message deleted**.
4. **Account B** long-presses A's message → must **not** see manager delete (Reply + Report only).
5. **Account B** sends a message in group **Member chat**.
6. **Account A** long-presses B's message → shows **Delete message** (subtitle: Remove for everyone (manager)); confirm; both accounts see tombstone.
7. **Announcements**: A posts; A can delete own; B cannot delete A's announcement.
8. Optional reply to a deleted message → reply preview shows **Message deleted**.

### Automated staging QA

```bash
cd reemove_app
NODE_PATH=functions/node_modules node scripts/staging-qa-groups-moderation.cjs
```

Requires ADC for `reemove-staging`. Default emails: A `meliodasin14@gmail.com`, B `abualamostaf@gmail.com`.

## Module status

**Complete** — Groups and Teams requirements are functionally complete for closed beta, including req #9 moderation verified on staging.

## Remaining unfinished (next milestone candidates)

1. No remaining req #9 moderation blocker.

## Intentionally deferred

- Production launch prep (after req #9 fix)
