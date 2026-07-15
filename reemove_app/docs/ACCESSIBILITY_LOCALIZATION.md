# Accessibility and Localization Quality Plan

## Accessibility target

Use WCAG 2.2 AA principles as a common quality baseline while testing native mobile semantics with TalkBack and VoiceOver.

## Automated checks

- Flutter semantics tests for labels, roles, values, enabled state, and actions
- Text scaling at 1.0, 1.3, 1.6, and 2.0
- Tap target checks for critical controls
- Contrast review for light and dark themes
- No clipped or unreachable content
- Focus order and modal focus containment

## Manual checks

- Complete registration, onboarding, feed interaction, messaging, challenge join, marketplace contact, and AI request using a screen reader
- Error messages are announced and identify the affected field
- Media controls have accessible names
- Images support appropriate descriptions where meaningful
- Animations respect reduced-motion preferences where available
- Status is not expressed by color alone
- Captions/transcripts are supported for important spoken media when the product enables such content

## Languages

ReeMove must be checked in:

- English (LTR)
- Arabic (RTL)
- Hebrew (RTL)

## RTL requirements

- Navigation direction and back affordances are correct
- Directional icons mirror only when semantically appropriate
- Mixed usernames, numbers, scores, units, and timestamps remain readable
- Maps, media, and sports diagrams are not incorrectly mirrored
- Text fields handle mixed LTR/RTL input
- Notification and deep-link copy uses the active locale

## Localization test data

Use short and long names, Arabic/Hebrew diacritics, emoji, combining characters, plural forms, large numbers, dates around daylight-saving changes, and strings that are substantially longer than English.

## Release blockers

- Critical control inaccessible by screen reader or keyboard/switch input
- Text required for task completion is clipped at supported text scales
- RTL flow prevents task completion
- Meaning depends only on color
- Insufficient contrast on critical content
- Untranslated critical safety, permission, error, or purchase/contact-related copy
