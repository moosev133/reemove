# Profile implementation

## Architecture

The profile feature follows the same dependency direction as the rest of ReeMove:

```text
profile presentation -> profile application -> profile domain <- profile data
                                                    ^
                                                    |
                                          callable Cloud Functions
```

Flutter widgets consume Riverpod providers and domain repositories. Firebase Auth, Firestore, Storage, and callable-function types remain in the data layer. Relationship counters and privileged identity changes are never computed from client state.

## Public profile model

`UserProfile` includes:

- Stable UID and unique username.
- Display name, biography, avatar, cover, and HTTPS website.
- Role: athlete, trainer, business, or admin/team.
- Verification status and verification type.
- Primary sport, favorite sports, sport levels, and goals.
- Optional professional headline, organization, category/position, experience, specialties, and client availability.
- Coarse public location and discovery radius.
- Visibility and follow-approval policy.
- Server-owned follower, following, post, and reel counts.
- Moderation, onboarding, audit, and schema state.

Exact birthday, exact location, email, consent history, and private preferences are not part of the public model.


## Sanitized public delivery

Direct `users/{uid}` reads are owner/admin only. Public profile screens call `getPublicProfile`, which applies account visibility, both block directions, follower status, and private display switches before returning a DTO. Hidden goals, sport levels, and location fields are removed server-side, and operational discovery radius is never returned to another user. Connection and blocked-account lists use the same sanitizer.

## Relationship state machine

`ProfileRelationship` represents the viewer/profile relationship:

- `self`
- `notFollowing`
- `requestPending`
- `following`
- `blockedByViewer`
- `blockedByProfile`

It also carries authorization decisions such as whether the viewer may see the profile, connection lists, or message the profile. The UI renders actions from this authoritative response instead of inferring state from counters.

### Public profiles

A successful follow request creates both:

```text
users/{viewerUid}/following/{profileUid}
users/{profileUid}/followers/{viewerUid}
```

and changes both counters in the same transaction.

### Approval-required profiles

The first action creates:

```text
follow_requests/{viewerUid}--{profileUid}
```

Only the target may accept or decline it, and only the requester may cancel it. Acceptance creates both graph edges and updates counters transactionally.

### Blocking

A block writes reciprocal private indexes, removes pending requests and existing relationship edges in both directions, and decrements counters safely. Unblocking removes only the reciprocal block records; it does not restore earlier follows.

## Profile editing

`EditProfileScreen` supports identity, biography, media, sport, goal, visibility, and professional fields. `ProfileActionController` sends a typed `ProfileEditRequest` to `updateProfile`.

The backend:

1. Revalidates lengths, enums, URLs, lists, and primary-sport membership.
2. Verifies avatar and cover Storage objects belong to the authenticated user.
3. Enforces username normalization, reservation uniqueness, and cooldown.
4. Updates public profile and private settings consistently.
5. Emits an audit event.
6. Triggers author-snapshot synchronization for recent posts and stories.

## Privacy settings

Private profile settings include:

- Automatic or approval-required follows.
- Message, mention, and tag audiences.
- Activity-status visibility.
- Sports, goals, location, and follower-list visibility.
- Hidden like counts.
- Username discovery.
- Personalized suggestions.

The server applies defaults to missing historical fields and rejects unsupported values. Public profile visibility remains a separate public field with `public`, `followers`, and `private` states.

## Profile content

`loadProfileContent` provides bounded cursor pages for:

- Posts.
- Reels.
- Saved posts, owner only.
- Reposted posts, owner only.

Every returned post passes the same content access policy as Feed and direct post links. Removed, processing, expired, blocked, and unauthorized content is omitted. Viewer reaction state is returned alongside each item.

## Verification

Users may submit one profile verification request containing:

- Requested category: athlete, trainer, or business.
- Legal name and review summary.
- Up to six private evidence objects.

Only administrators may review a request. Approval updates the public profile, role, verification type, and Firebase Auth custom claims. Rejection retains a reason for the owner and allows a corrected resubmission. Evidence is never public.

## Failure behavior

- Private or blocked profiles produce safe unavailable states.
- Stale pages may be refreshed without losing the active profile tab.
- All mutations surface typed user-safe failures.
- Optimistic relationship UI is reconciled with the server response.
- Pagination uses bounded limits and deterministic cursors.
- Owner-only tabs do not appear on public profiles.
