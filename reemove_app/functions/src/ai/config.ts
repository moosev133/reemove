import {defineInt, defineSecret, defineString} from "firebase-functions/params";

import {primaryRegion} from "../core/functionOptions";

export const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
export const OPENAI_MODEL = defineString("OPENAI_MODEL", {
  default: "gpt-4.1-mini",
  description: "OpenAI model used by ReeMove AI modules.",
});
export const AI_DAILY_LIMIT = defineInt("AI_DAILY_LIMIT", {
  default: 20,
  description: "Maximum AI attempts per user per UTC day.",
});

/** Shared region with the rest of the ReeMove Functions package. */
export const FUNCTIONS_REGION = primaryRegion;
