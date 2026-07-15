import { z } from 'zod';

const shortText = z.string().trim().min(1).max(300);
const mediumText = z.string().trim().min(1).max(1200);

export const coachInputSchema = z.object({
  message: mediumText,
  conversationId: z.string().trim().max(128).optional(),
});

export const workoutInputSchema = z.object({
  sport: shortText,
  goal: shortText,
  level: z.string().trim().min(1).max(80),
  daysPerWeek: z.number().int().min(1).max(6),
  sessionMinutes: z.number().int().min(20).max(90),
  availableEquipment: z.string().trim().max(500).optional(),
  limitations: z.string().trim().max(500).optional(),
});

export const nutritionInputSchema = z.object({
  sport: shortText,
  goal: shortText,
  activityLevel: z.string().trim().min(1).max(100),
  dietaryPreferences: z.string().trim().max(500).optional(),
  allergies: z.string().trim().max(500).optional(),
});

export const matchmakerInputSchema = z.object({
  sport: shortText,
  candidateIds: z.array(z.string().trim().min(1).max(128)).min(1).max(20),
  preferences: z.string().trim().max(500).optional(),
});

export const challengeInputSchema = z.object({
  sport: shortText,
  level: z.string().trim().min(1).max(80),
  durationDays: z.number().int().min(1).max(30),
  equipment: z.string().trim().max(500).optional(),
});

export const contentInputSchema = z.object({
  sourceText: mediumText,
  tone: z.string().trim().min(1).max(80),
  platform: z.string().trim().min(1).max(80),
});

export const trainerInsightsInputSchema = z.object({
  period: z.enum(['last_7_days', 'last_30_days', 'last_90_days']),
});
