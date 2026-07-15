# Deep-link and universal-link setup

## Route host

Use a dedicated HTTPS host such as `links.reemove.app`. The host must serve the verification files directly over HTTPS with no redirects.

Run native configuration after `flutter create`:

```bash
APP_LINK_HOST=links.reemove.app ./scripts/bootstrap_project.sh
```

Or run only the link patcher:

```bash
python3 scripts/configure_deep_links.py --host links.reemove.app
```

The script is safe to run repeatedly.

## Android App Links

1. Replace the placeholder SHA-256 certificate fingerprint in `docs/app_links/assetlinks.json`.
2. Host it at:

```text
https://links.reemove.app/.well-known/assetlinks.json
```

3. Include every signing certificate used by production and approved testing channels.
4. Keep the Android application ID aligned with the hosted `package_name`.

Test after installation:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "https://links.reemove.app/u/demo_athlete"
```

## iOS Universal Links

1. Replace `REPLACE_TEAM_ID` in `docs/app_links/apple-app-site-association.json`.
2. Host the file without an extension at either supported location:

```text
https://links.reemove.app/.well-known/apple-app-site-association
```

3. Confirm `Runner/Runner.entitlements` contains `applinks:links.reemove.app`.
4. Confirm the Associated Domains capability is enabled for the App ID in the Apple Developer portal.

Test on a physical device from Notes, Messages, or Safari. Typing a URL directly into Safari's address bar may remain in Safari by design.

## Custom scheme

The native patcher also registers:

```text
reemove://open/u/demo_athlete
reemove://open/p/post-id
reemove://open/c/conversation-id
reemove://open/s/running
```

Verified HTTPS links are the production default. The custom scheme is for controlled integrations and development fallback because custom schemes cannot prove domain ownership.

## Supported links

| Link | Destination |
|---|---|
| `/p/:postId` | Post detail in Home |
| `/u/:username` | Public profile in Profile |
| `/c/:conversationId` | Conversation in Messages |
| `/s/:sportId` | Sport hub in Sports |
| `/home/*` | Home branch |
| `/discover/*` | Discover branch |
| `/sports/*` | Sports branch |
| `/messages/*` | Messages branch |
| `/profile/*` | Profile branch |

Protected links survive sign-in, username setup, email verification, and onboarding through a validated internal `returnTo` parameter.

## Release gate

Before staging or production release:

- Verification files return HTTP 200 with correct JSON content types.
- Android and iOS signing identifiers match the hosted files.
- Links work from a cold start, background, and foreground.
- Signed-out links return to the exact target after authentication and onboarding.
- Private, removed, or unauthorized resources render a safe unavailable state.
- No external URL is accepted as `returnTo`.
