export interface OutputSchemaDefinition {
  name: string;
  schema: Record<string, unknown>;
}

const stringArray = {
  type: 'array',
  items: { type: 'string' },
};

export const outputSchemas: Record<string, OutputSchemaDefinition> = {
  coach: {
    name: 'reemove_coach_reply',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['answer', 'actions', 'warnings', 'followUpQuestion'],
      properties: {
        answer: { type: 'string' },
        actions: stringArray,
        warnings: stringArray,
        followUpQuestion: { type: ['string', 'null'] },
      },
    },
  },
  workout: {
    name: 'reemove_workout_plan',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['title', 'goal', 'weeklySchedule', 'safetyNotes', 'progressionNotes'],
      properties: {
        title: { type: 'string' },
        goal: { type: 'string' },
        weeklySchedule: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            required: ['day', 'focus', 'durationMinutes', 'exercises'],
            properties: {
              day: { type: 'string' },
              focus: { type: 'string' },
              durationMinutes: { type: 'integer' },
              exercises: {
                type: 'array',
                items: {
                  type: 'object',
                  additionalProperties: false,
                  required: ['name', 'sets', 'reps', 'restSeconds', 'intensityNote'],
                  properties: {
                    name: { type: 'string' },
                    sets: { type: 'integer' },
                    reps: { type: 'string' },
                    restSeconds: { type: 'integer' },
                    intensityNote: { type: 'string' },
                  },
                },
              },
            },
          },
        },
        safetyNotes: stringArray,
        progressionNotes: stringArray,
      },
    },
  },
  nutrition: {
    name: 'reemove_nutrition_guidance',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['title', 'principles', 'sampleDay', 'hydration', 'safetyNotes'],
      properties: {
        title: { type: 'string' },
        principles: stringArray,
        sampleDay: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            required: ['meal', 'examples'],
            properties: {
              meal: { type: 'string' },
              examples: stringArray,
            },
          },
        },
        hydration: stringArray,
        safetyNotes: stringArray,
      },
    },
  },
  matchmaker: {
    name: 'reemove_match_recommendations',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['summary', 'recommendations'],
      properties: {
        summary: { type: 'string' },
        recommendations: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            required: [
              'userId',
              'displayName',
              'sport',
              'level',
              'approximateDistanceKm',
              'compatibilityScore',
              'reasons',
              'safetyNotes'
            ],
            properties: {
              userId: { type: 'string' },
              displayName: { type: 'string' },
              sport: { type: 'string' },
              level: { type: 'string' },
              approximateDistanceKm: { type: ['number', 'null'] },
              compatibilityScore: { type: 'integer', minimum: 0, maximum: 100 },
              reasons: stringArray,
              safetyNotes: stringArray,
            },
          },
        },
      },
    },
  },
  challenge: {
    name: 'reemove_safe_challenge',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: [
        'title',
        'sport',
        'description',
        'durationDays',
        'difficulty',
        'rules',
        'scoring',
        'safetyNotes',
        'verificationMethod'
      ],
      properties: {
        title: { type: 'string' },
        sport: { type: 'string' },
        description: { type: 'string' },
        durationDays: { type: 'integer', minimum: 1, maximum: 30 },
        difficulty: { type: 'string', enum: ['low', 'moderate'] },
        rules: stringArray,
        scoring: { type: 'string' },
        safetyNotes: stringArray,
        verificationMethod: { type: 'string' },
      },
    },
  },
  content: {
    name: 'reemove_content_assistant',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['caption', 'hashtags', 'accessibilityText', 'moderationNotes'],
      properties: {
        caption: { type: 'string' },
        hashtags: stringArray,
        accessibilityText: { type: 'string' },
        moderationNotes: stringArray,
      },
    },
  },
  trainer_insights: {
    name: 'reemove_trainer_business_insights',
    schema: {
      type: 'object',
      additionalProperties: false,
      required: ['headline', 'kpis', 'insights', 'recommendedActions', 'risks'],
      properties: {
        headline: { type: 'string' },
        kpis: {
          type: 'array',
          items: {
            type: 'object',
            additionalProperties: false,
            required: ['label', 'value', 'trend'],
            properties: {
              label: { type: 'string' },
              value: { type: 'string' },
              trend: { type: 'string', enum: ['up', 'down', 'flat', 'unknown'] },
            },
          },
        },
        insights: stringArray,
        recommendedActions: stringArray,
        risks: stringArray,
      },
    },
  },
};
