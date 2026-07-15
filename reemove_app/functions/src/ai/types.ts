export type AiModule =
  | 'coach'
  | 'workout'
  | 'nutrition'
  | 'matchmaker'
  | 'challenge'
  | 'content'
  | 'trainer_insights';

export interface UserAiContext {
  uid: string;
  displayName: string;
  favoriteSports: string[];
  goals: string[];
  sportsLevels: Record<string, string>;
  ageGroup: 'under18' | 'adult' | 'unknown';
  preferredLanguage: string;
  role: 'user' | 'trainer' | 'admin';
}

export interface CandidateProfile {
  userId: string;
  displayName: string;
  sport: string;
  level: string;
  approximateDistanceKm: number | null;
  goals: string[];
}

export interface AiGenerationOptions {
  module: AiModule;
  uid: string;
  input: unknown;
  userContext: UserAiContext;
  trustedContext?: unknown;
}
