# Beta test plan — ReeMove

## Goals

Validate staging builds with synthetic / consented tester accounts before production staged rollout.

## Entry criteria

- [ ] Staging Firebase deployed (rules, indexes, functions, remote config)
- [ ] Android internal build **or** iOS TestFlight build installed
- [ ] ≥ one physical Android and one physical iOS device available
- [ ] Phase 15 scorecard open items accepted or waived in writing

## Tester matrix

| Role | Accounts |
|------|----------|
| Public athlete | 2 |
| Private / minor-band (policy) | 1 adult guardian path if required by policy |
| Trainer | 1 |
| Marketplace seller + buyer | 1 each |
| Blocked pair | 2 |
| Moderator/admin claim | 1 (staging only) |

## Critical journeys (must pass)

1. Sign up / verify / username / onboarding resume  
2. Feed: publish image, like, comment, open deep link alias  
3. Messaging: DM + group + media  
4. Nearby map with location permission (Maps key present)  
5. Challenge join + progress submit  
6. Marketplace listing + contact seller chat  
7. Notifications open → correct Activity route  
8. AI Coach success + rate-limit / safety refusal samples  
9. Kill switch: Remote Config `maintenance_mode=true` shows maintenance UI  
10. Force update: raise min build → Update Required UI  

## Accessibility / localization spot checks

- Dynamic type / large text  
- VoiceOver / TalkBack on nav + create post  
- RTL smoke if Arabic/Hebrew builds are in scope  

## Exit criteria

- No open **P0/P1** defects  
- FCM delivery ≥90% in tester sample  
- Crash-free sessions acceptable per `config/monitoring_thresholds.json`  
- Written signoff in `quality/release_signoff.yaml`

## Explicit

Do not promote to production tracks without **deployment approval**.
