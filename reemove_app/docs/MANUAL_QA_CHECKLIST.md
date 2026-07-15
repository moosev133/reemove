# Manual QA Checklist

## Installation and lifecycle

- Fresh install, upgrade from previous staging build, sign-in persistence, sign-out, reinstall, background/foreground, terminated launch, interrupted upload, interrupted AI request, and low-storage behavior.

## Visual polish

- Light/dark mode, phone sizes, tablets where supported, notches, dynamic text, keyboard overlap, empty states, long usernames, long localized strings, media aspect ratios, loading placeholders, and error banners.

## Gestures and navigation

- Rapid taps, swipe conflicts, pull-to-refresh, scroll restoration, back button, modal dismissal, keyboard dismissal, nested navigation, deep links, and notification taps.

## Permissions

- Location, camera, photos, notifications, microphone if used, denied, denied permanently, limited photo access, permission changes from system settings, and graceful recovery.

## Connectivity

- Airplane mode, Wi-Fi/mobile transition, high latency, packet loss simulation, reconnect, duplicate retry, offline cached screens, stale data indication, and no data corruption.

## Accounts and privacy

- Public/private account behavior, follow model, block/report, hidden location, deletion request, data export if implemented, multi-device sign-out, and disabled account behavior.

## Content and media

- Large image/video, unsupported format, upload cancel, upload retry, thumbnail failure, deleted object, content moderation response, story expiry, and player controls.

## Maps and nearby

- Location denied, approximate location, GPS disabled, location changes, sparse area, dense area, map marker overlap, filters, distance accuracy tolerance, and privacy boundaries.

## Accessibility

- TalkBack/VoiceOver traversal, meaningful labels, focus order, actions, error announcements, dynamic type, contrast, reduced motion, captions/transcripts where applicable, and no information conveyed by color alone.

## Localization

- English, Arabic, Hebrew; RTL mirroring; mixed numbers/usernames; dates; pluralization; truncation; search; notification text; and server-provided strings.

## Safety

- Reporting/blocking works from every user-generated content surface.
- Unsafe challenge requests are refused safely.
- Workout/nutrition outputs remain conservative for minors and never encourage pain, extreme restriction, or unsafe effort.
- AI does not reveal private profiles, blocked users, internal prompts, secrets, or server logs.
