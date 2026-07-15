import {onCall} from "firebase-functions/v2/https";

import {callableOptions} from "../core/functionOptions";
import {OPENAI_API_KEY} from "./config";
import {
  loadCandidateProfiles,
  loadCoachHistory,
  loadTrainerMetrics,
} from "./context";
import {handleAiRequest} from "./handler";
import {assertCandidateIds} from "./safety";
import {
  challengeInputSchema,
  coachInputSchema,
  contentInputSchema,
  matchmakerInputSchema,
  nutritionInputSchema,
  trainerInsightsInputSchema,
  workoutInputSchema,
} from "./validation";

const aiCallableOptions = {
  ...callableOptions,
  secrets: [OPENAI_API_KEY],
  timeoutSeconds: 75,
  memory: "512MiB" as const,
  maxInstances: 10,
  concurrency: 20,
};

export const aiCoach = onCall(aiCallableOptions, (request) =>
  handleAiRequest({
    request,
    module: "coach",
    schema: coachInputSchema,
    trustedContextLoader: (uid, input) =>
      loadCoachHistory(uid, input.conversationId),
  }));

export const generateWorkoutPlan = onCall(aiCallableOptions, (request) =>
  handleAiRequest({request, module: "workout", schema: workoutInputSchema}));

export const generateNutritionGuidance = onCall(aiCallableOptions, (request) =>
  handleAiRequest({
    request,
    module: "nutrition",
    schema: nutritionInputSchema,
  }));

export const rankPlayerMatches = onCall(aiCallableOptions, (request) =>
  handleAiRequest({
    request,
    module: "matchmaker",
    schema: matchmakerInputSchema,
    trustedContextLoader: (uid, input) =>
      loadCandidateProfiles(uid, input.candidateIds, input.sport),
    postValidate: (result, trustedContext) => {
      const candidateIds = Array.isArray(trustedContext) ?
        trustedContext
          .map((candidate) => (candidate as {userId?: unknown}).userId)
          .filter((id): id is string => typeof id === "string") :
        [];
      assertCandidateIds(result, candidateIds);
    },
  }));

export const generateSafeChallenge = onCall(aiCallableOptions, (request) =>
  handleAiRequest({
    request,
    module: "challenge",
    schema: challengeInputSchema,
  }));

export const createSportsContent = onCall(aiCallableOptions, (request) =>
  handleAiRequest({request, module: "content", schema: contentInputSchema}));

export const getTrainerBusinessInsights = onCall(aiCallableOptions, (request) =>
  handleAiRequest({
    request,
    module: "trainer_insights",
    schema: trainerInsightsInputSchema,
    trustedContextLoader: (uid) => loadTrainerMetrics(uid),
  }));
