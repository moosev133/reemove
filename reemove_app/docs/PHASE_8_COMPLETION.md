# Phase 8 completion — messaging

Completion date: 2026-07-14

## Scope delivered

Phase 8 replaces the Messages placeholder with a production-oriented communication system for direct and group conversations. Durable history is stored in Cloud Firestore, ephemeral presence and typing state is stored in Firebase Realtime Database, attachments use Firebase Storage, and all relationship-sensitive mutations run through trusted callable Cloud Functions.

## User-facing capabilities

- Searchable active and archived conversation inboxes.
- Deterministic one-to-one conversations created from an exact username or a profile action.
- Group creation from people the user follows.
- Group rename, member addition, member removal, and leave-group workflows.
- Live message history with cursor-based loading of earlier messages.
- Text, image, and video messages with upload progress and retry-safe composer state.
- Replies, allowlisted emoji reactions, edits, deletion, and abuse reports.
- Read receipts derived from server-owned member read markers.
- Live online state and bounded typing indicators.
- Mute, notification, and archive preferences per conversation.
- Message push deep links that open the correct stateful Messages branch.
- Empty, loading, denied, offline/error, processing, and unavailable-media states.
- Accessible semantic labels, large-layout constraints, light/dark theme support, and RTL-compatible Material layout.

## Trusted backend capabilities

Cloud Functions own all durable messaging mutations:

- `createDirectConversation`
- `createGroupConversation`
- `updateGroupConversation`
- `leaveConversation`
- `updateConversationPreferences`
- `sendMessage`
- `editMessage`
- `deleteMessage`
- `toggleMessageReaction`
- `markConversationRead`
- `reportMessage`
- `registerMessagingDevice`
- `unregisterMessagingDevice`
- `notifyConversationMessage`

The backend validates messaging privacy, blocks, membership, group administration, message size, attachment metadata, edit/delete windows, reactions, report reasons, rate limits, and idempotent client message IDs. It maintains conversation member records, per-user inbox summaries, unread counts, private reaction mirrors, Realtime Database access-control records, audit events, notification delivery records, and invalid-token cleanup.

## Security and privacy

- Clients cannot create or modify conversation, member, message, reaction, counter, report, token, or delivery records directly.
- Firestore conversation and message reads require active membership; removed members and outsiders are denied.
- User inbox summaries, viewer reactions, and device tokens are owner-only.
- Realtime Database ACL documents are server-only. Members may write only their own presence and typing nodes.
- Storage attachment reads require active membership. Uploads require path-bound owner, conversation, message, asset, type, size, and schema metadata.
- Blocking prevents conversation creation and message delivery and removes messaging access through the reciprocal visibility model.
- Push payloads contain routing identifiers and a short preview, not full conversation history.
- Reports are private to the reporter and administrators and use bounded, allowlisted reasons.

## Data and indexes

Phase 8 activates:

- `conversations/{conversationId}`
- `conversations/{conversationId}/members/{uid}`
- `conversations/{conversationId}/messages/{messageId}`
- `conversations/{conversationId}/messages/{messageId}/reactions/{uid}`
- `users/{uid}/conversation_inbox/{conversationId}`
- `users/{uid}/message_reactions/{conversationId}--{messageId}`
- `users/{uid}/device_tokens/{tokenHash}`
- `message_reports/{reportId}`
- `notification_deliveries/{deliveryId}`
- Realtime Database `messaging_acl`, `presence`, and `typing`
- Storage `messages/{conversationId}/{messageId}/{assetId}/{filename}`

Composite indexes cover inbox ordering, unread summaries, message chronology, and moderation reports. Emulator seed data includes a direct conversation and a three-person training group.

## Validation completed here

- Cumulative source package contains **391 tracked source/configuration/documentation files**, including **280 Dart source/test files**.

- Repository JSON/YAML, shell, Python, relative-import, and domain-boundary validation passed.
- All Dart source and test files passed grammar parsing with a real Dart tree-sitter parser.
- Cloud Functions ESLint passed.
- Strict TypeScript compilation passed.
- Backend policy tests: **36 passed**.
- Firestore, Storage, and Realtime Database Rules test sources passed JavaScript syntax validation.
- Messaging DTO/mapper and route tests are included for Flutter execution.
- Package locks are present for Functions and Firebase Rules tests.

## Environment-limited checks

The Flutter SDK is unavailable in this execution environment, so Flutter dependency resolution, formatting, analyzer checks, widget tests, integration tests, and native builds must run on a Flutter-equipped machine. The Firebase Rules test dependencies installed, but Firebase CLI emulator execution failed in this runtime before assertions ran. The full three-service emulator suite remains release-blocking in CI/staging.

## Exit status

Phase 8 is complete at the source, architecture, backend-policy, Rules-source, seed-data, navigation, and documentation level. Production deployment remains gated by Flutter analysis/tests, physical-device push/presence/media testing, APNs/FCM configuration, and successful executable Firebase emulator Rules tests.

Next phase: **Phase 9 — Sports hubs**.
