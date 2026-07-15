# Messaging implementation

## Architecture

Messaging uses three Firebase data planes with one trusted mutation plane:

```text
Flutter UI
  -> Riverpod application controllers
  -> domain repository contracts
  -> Firebase repository implementations
       -> Firestore listeners for durable data
       -> Realtime Database listeners for ephemeral state
       -> Storage uploads for attachments
       -> callable Functions for all durable mutations

Firestore create trigger
  -> FCM multicast delivery
  -> invalid-token cleanup
  -> delivery audit
```

### Why Firestore and Realtime Database are both used

Firestore owns data that must be durable, pageable, auditable, and queryable: conversations, members, messages, reactions, inbox summaries, reports, and tokens. Realtime Database owns high-frequency state that can disappear safely: presence and typing. Cloud Functions synchronize active membership into a private Realtime Database ACL so ephemeral reads and writes never depend on client assertions.

## Domain boundary

Firebase types remain in `features/messages/data`. The domain layer exposes:

- `Conversation`, `ConversationSummary`, `ConversationMember`, and `ConversationLastMessage`
- `ConversationMessage`, `MessageAttachment`, `MessageReplyPreview`, `MessagePage`, and `MessageCursor`
- `MessagingUser`, `MessagingPresence`, and `TypingParticipant`
- `SendMessageRequest` and `ConversationPreferencesUpdate`
- repository interfaces for durable messaging, presence, attachments, device tokens, and platform media picking

## Durable read model

### Inbox

Every member receives a server-owned summary at:

```text
users/{uid}/conversation_inbox/{conversationId}
```

It contains the safe conversation title/avatar, bounded member snapshots, last-message preview, unread count, notification state, mute/archive state, and timestamps. This avoids collection-group membership joins for the primary inbox query and keeps Rules owner-scoped.

### Conversation

The canonical aggregate is:

```text
conversations/{conversationId}
  members/{uid}
  messages/{messageId}
    reactions/{uid}
```

Direct conversation IDs are a stable hash of the sorted user IDs, making creation idempotent. Groups use generated IDs and a maximum of 50 members. Removed member documents are retained with `removedAt` for audit/history while Rules deny their access.

### Reactions

Message reaction aggregates live on the message. Each viewer also has a private reaction mirror under their user document. The client reads only its own mirror and cannot enumerate another user’s reactions.

## Sending flow

1. The client creates a globally unique `clientMessageId`.
2. Selected attachments upload to a path containing conversation, message, and asset IDs.
3. Storage Rules validate active membership and exact metadata/path agreement.
4. The client calls `sendMessage` with text, attachment metadata, and optional reply ID.
5. The Function verifies every uploaded object and writes the message transactionally.
6. Member unread/read state and every user inbox summary are updated server-side.
7. A Firestore trigger sends FCM notifications to eligible devices.
8. The live Firestore query renders the authoritative message.

The same client message ID makes retries idempotent and prevents duplicate sends after uncertain network responses.

## Message policy

- Text: maximum 4,000 normalized characters.
- Attachments: maximum four images, or one video/audio attachment.
- Image: under 15 MB.
- Video: under 100 MB.
- Audio contract: under 25 MB; audio capture UI is reserved for a later media enhancement.
- Reactions: `❤️`, `👏`, `🔥`, `💪`, `😂`, or `⚡`.
- Editing: sender-only and time-bounded.
- Deletion: sender-only and time-bounded; history becomes a deleted-message tombstone.
- Reports: allowlisted reasons, bounded optional details, rate-limited and audited.

## Presence and typing

When a conversation opens, the client registers `onDisconnect()` cleanup and writes its own online node. Typing writes expire in the UI after eight seconds even if a disconnect cleanup is delayed. Leaving a screen removes both nodes. Only users listed in the server-managed `messaging_acl/{conversationId}` may read the conversation's ephemeral state.

## Read receipts

`markConversationRead` updates the member’s `lastReadAt`, last-read message ID, unread count, and inbox summary. The UI labels the sender’s message as read when another active member’s trusted read marker is at or after the message timestamp.

## Push notifications

The message-created trigger:

- excludes the sender;
- respects per-conversation notification, mute, and member status;
- loads user device tokens in bounded batches;
- sends a conversation deep link and IDs in the data payload;
- records a minimized delivery result;
- removes tokens rejected as invalid or unregistered.

The Flutter shell registers eligible devices, follows token refreshes, handles terminated/background notification opens, and routes to `/messages/{conversationId}`.

## Blocking and moderation

Conversation creation and sending call the canonical profile/message-access policy. Reciprocal block documents are authoritative. Reports create server-only moderation records. Direct client writes to conversation data are denied, preventing forged sender identity, unread counts, group roles, reports, and message history.

## Offline and failure behavior

Firestore listeners use the SDK cache automatically. The UI keeps selected attachment bytes and composer text in memory while a send is active, displays per-upload progress, and leaves content in place after a failed send. Durable offline draft persistence can be added without changing repository contracts.
