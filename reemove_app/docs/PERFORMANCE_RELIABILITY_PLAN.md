# Performance and Reliability Plan

## Measurement modes

- Use profile mode for Flutter frame and startup profiling.
- Use real devices for release decisions.
- Use integration tests for repeatable scroll and critical-flow measurements.
- Use Firebase Performance Monitoring custom traces for production-like staging data.
- Do not use Firebase Test Lab as a backend load generator.

## Default budgets

These are ReeMove product targets and can be adjusted only with recorded device/network context.

| Metric | Target |
|---|---:|
| Warm app start P95 | <= 1.5 s |
| Cold app start P95 | <= 3.0 s |
| Feed first meaningful content P95 | <= 2.5 s on normal network |
| Feed pagination P95 | <= 2.0 s |
| Profile open P95 | <= 2.0 s |
| Message send acknowledgement P95 | <= 1.5 s |
| Notification deep-link destination P95 | <= 2.5 s after app ready |
| Standard callable P95 | <= 3.0 s |
| AI callable P95 | <= 15 s, with visible progress and timeout handling |
| Slow UI frames | < 5% during critical scroll |
| Frozen UI frames | < 1% during critical scroll |
| Crash during critical journeys | 0 |

## Custom traces

Recommended trace names:

- `app_boot_to_shell`
- `feed_first_content`
- `feed_next_page`
- `profile_load`
- `conversation_open`
- `message_send_ack`
- `nearby_map_ready`
- `challenge_join`
- `marketplace_search`
- `notification_route`
- `ai_coach_request`
- `ai_workout_request`
- `ai_matchmaker_request`

Use low-cardinality attributes such as build channel, platform, authenticated state, feature, cache hit, and coarse network class. Never attach usernames, message content, exact location, or AI prompt text.

## Reliability scenarios

- Function timeout and retry
- Firestore unavailable or permission denied
- Storage upload interruption
- Duplicate client retry
- Concurrent follow/join/favorite actions
- Push token rotation
- Offline write then reconnect
- App killed during upload or onboarding
- Stale/deleted deep-link target
- AI provider timeout/refusal/invalid output
- Partial outage with cached data

## Load testing

Load test staging backends only. Begin with small smoke loads, confirm quotas and test-data cleanup, then increase gradually. Measure error rate, P50/P95/P99, instance scaling, Firestore reads/writes, contention, and cost. Never point load scripts at production without explicit operational approval.

## Leak and resource checks

- Repeated route open/close
- Video/image controller disposal
- Map controller lifecycle
- Stream subscription disposal
- Background upload cancellation
- Large feed scroll memory
- Message list pagination memory
- AI result rendering with maximum allowed output
