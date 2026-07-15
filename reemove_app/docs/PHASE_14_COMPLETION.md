# ReeMove — Phase 14: AI Modules

This package adds the AI layer to the existing ReeMove Flutter + Firebase codebase without exposing the OpenAI API key to the mobile client.

## Included modules

1. AI Coach
2. Workout Plan Generator
3. Nutrition Guidance
4. Player / Teammate Matchmaker
5. Safe Challenge Generator
6. Content Assistant
7. Trainer Business Insights

## Architecture

Flutter calls authenticated Firebase callable functions. The callable functions validate Firebase Authentication and App Check, enforce quotas, moderate user input, load trusted Firestore context, call the OpenAI Responses API with strict JSON schemas, moderate generated output, apply ReeMove safety checks, store an audit-safe result, and return typed JSON to Flutter.

```text
Flutter UI
  -> AiRepository
  -> Firebase Functions callable SDK
  -> Firebase Auth + App Check
  -> Input validation + rate limit + moderation
  -> Firestore trusted context
  -> OpenAI Responses API + Structured Outputs
  -> Output moderation + safety policy
  -> Firestore AI output + usage log
  -> Typed result to Flutter
```

## Important safety decisions

- The mobile app never receives the OpenAI API key.
- Nutrition guidance does not produce aggressive calorie deficits, fasting plans, supplement dosing, or body-shaming content.
- Users marked as under 18 receive conservative wellness guidance only.
- Workout plans exclude one-repetition-max testing, unsafe max-effort instructions, extreme volume, and “train through pain” advice.
- Challenge generation allows only low or moderate risk challenges and excludes dangerous stunts.
- AI Coach does not diagnose injuries or medical conditions.
- Matchmaker only ranks real candidate profiles supplied by the trusted nearby-discovery flow; it must not invent users.

## Package layout

- `flutter/` — merge-ready Dart code and dependency additions.
- `functions/` — Firebase Cloud Functions 2nd gen TypeScript backend.
- `firebase/` — Firestore rules and index snippets.
- `docs/` — merge guide, schema, deployment, testing, and safety documentation.

## Phase status

Phase 14 is complete when:

- Flutter screens are connected to the callable functions.
- Firebase App Check is active in the app.
- `OPENAI_API_KEY` is stored in Secret Manager.
- Functions deploy successfully.
- Firestore rules and indexes are merged.
- Emulator and device tests pass.
- Production quotas and monitoring are enabled.

Phase 15 should test the complete ReeMove application, including these AI modules, under unit, widget, integration, emulator, security, performance, and abuse scenarios.
