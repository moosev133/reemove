# Firestore Schema — Phase 14

## User AI outputs

```text
users/{uid}/ai_outputs/{outputId}
  type: coach | workout | nutrition | matchmaker | challenge | content | trainer_insights
  inputSummary: map
  result: map
  model: string
  createdAt: timestamp
  expiresAt: timestamp | null
  moderation: map
  usage: map
  requestId: string
```

Client permissions: owner read; server-only create/update/delete.

## AI conversations

```text
users/{uid}/ai_conversations/{conversationId}
  title: string
  module: coach
  createdAt: timestamp
  updatedAt: timestamp

users/{uid}/ai_conversations/{conversationId}/messages/{messageId}
  role: user | assistant
  text: string
  createdAt: timestamp
  outputId: string | null
```

For the first Phase 14 implementation, callable functions write messages. Direct client writes should remain disabled.

## Usage quota

```text
ai_usage/{uid}/days/{yyyy-MM-dd}
  count: number
  moduleCounts: map<string, number>
  updatedAt: timestamp
```

Server-only.

## Audit logs

```text
ai_audit_logs/{logId}
  uid: string
  module: string
  requestId: string
  status: success | rejected | failed
  reasonCode: string | null
  model: string | null
  createdAt: timestamp
```

Avoid storing raw sensitive prompts in global audit logs.

## Trainer metrics

```text
trainer_metrics/{trainerId}
  periodStart: timestamp
  periodEnd: timestamp
  profileViews: number
  followerGrowth: number
  contentReach: number
  saves: number
  messagesStarted: number
  eventJoins: number
  challengeParticipants: number
  returningAthletes: number
  topSports: array
  updatedAt: timestamp
```

Client permissions: trainer owner and admin read; server-only write.

## AI challenge drafts

Generated challenge drafts remain in `users/{uid}/ai_outputs`. A user must explicitly review and publish a draft into the existing Phase 11 challenges collection. The AI endpoint never publishes a public challenge automatically.
