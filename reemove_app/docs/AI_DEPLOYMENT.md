# Phase 14 Deployment Checklist

## Firebase

1. Confirm the project uses the Blaze plan for Cloud Functions and Secret Manager.
2. Confirm the functions region matches the existing ReeMove backend.
3. Set the OpenAI secret:

```bash
firebase functions:secrets:set OPENAI_API_KEY
```

4. Set or accept the `OPENAI_MODEL` parameter during deployment.
5. Deploy functions:

```bash
firebase deploy --only functions
```

6. Deploy Firestore rules and indexes after merging:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

7. Enable App Check metrics first, validate legitimate traffic, then enforce App Check for the callable functions.
8. Confirm the mobile builds initialize App Check before AI calls.

## Flutter

```bash
flutter pub get
flutter analyze
flutter test
```

Run with the configured functions region:

```bash
flutter run --dart-define=FIREBASE_FUNCTIONS_REGION=europe-west1
```

## Emulator test

```bash
firebase emulators:start --only auth,firestore,functions
```

Use emulator-only accounts and data. Do not use a production OpenAI key in shared CI logs.

## Production acceptance checks

- Unauthenticated calls are rejected.
- Invalid App Check calls are rejected after enforcement.
- Rate limits work under concurrency.
- Input and output moderation failures return safe error codes.
- No API key appears in Flutter source, logs, Crashlytics, or network responses.
- A user can read only their own AI outputs.
- A non-trainer cannot call trainer insights.
- Matchmaker output contains only supplied candidate IDs.
- Nutrition and challenge safety tests pass.
