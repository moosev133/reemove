# Dart defines (local only)

Copy the appropriate `*.json.example` file to a sibling `*.json` file (for example
`staging.json.example` → `staging.json`). Git ignores the copied `*.json` files; only
the `*.example` templates are tracked.

## Where to obtain real values

| Key | Where to get it |
|-----|-----------------|
| `GOOGLE_SERVER_CLIENT_ID` | Firebase Console → **Authentication** → **Sign-in method** → **Google** → **Web SDK configuration** → Web client ID. Use the staging or production project that matches `APP_FLAVOR`. |
| `FIREBASE_DATABASE_URL` | Firebase Console → **Realtime Database** → database URL for the matching project (production: `reemove-production`; staging: `reemove-staging`). |
| `FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY` | Firebase Console → **App Check** → your web app → reCAPTCHA v3 site key. |
| `SUPPORT_URL`, `STATUS_URL`, `STORE_URL` | Your public support, status, and store/download pages for that environment. |

Run Flutter with:

```bash
flutter run --dart-define-from-file=dart_defines/staging.json
```

Never commit filled `dart_defines/*.json` files or paste OAuth client secrets into the repository.
