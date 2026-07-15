# Phase 14 Test Plan

## Unit tests

- Request validation for every module.
- Age-group safety policy.
- Challenge risk validation.
- Matchmaker candidate ID enforcement.
- Quota transaction behavior.
- Structured output parsing.
- Moderation rejection mapping.

## Flutter widget tests

- AI Hub renders all seven modules.
- Loading, success, empty, and error states.
- Forms do not submit invalid input.
- Result cards handle long content and localization.
- Publish/send actions require explicit confirmation.

## Firebase Emulator tests

- Auth required.
- Owner-only reads for AI outputs.
- Direct client writes to AI outputs denied.
- Direct client writes to usage and audit logs denied.
- Trainer metrics owner/admin read only.

## Abuse tests

- Prompt injection attempting to reveal system prompts.
- Requests to ignore safety rules.
- Excessively long prompts.
- Repeated calls across devices.
- Candidate IDs belonging to blocked or private users.
- Attempts to generate dangerous challenges.
- Attempts to generate restrictive diets or unsafe workout plans.

## Performance tests

- P50, P95, and P99 callable latency.
- Cold-start latency.
- Concurrent quota updates.
- Firestore read/write counts per request.
- Maximum output size.

## Failure handling

- OpenAI timeout.
- OpenAI refusal.
- Invalid JSON despite schema enforcement.
- Firestore unavailable.
- Moderation service unavailable.
- App Check rollout with old clients.

A failure must return a user-safe message and a stable machine-readable error code without exposing internal prompts, stack traces, or secrets.
