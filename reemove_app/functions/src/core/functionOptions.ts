import {defineBoolean} from "firebase-functions/params";

export const primaryRegion = "europe-west1";

const enforceAppCheck = defineBoolean("ENFORCE_APP_CHECK", {
  default: true,
  description: "Reject callable requests without a valid App Check token.",
});

export const callableOptions = {
  region: primaryRegion,
  enforceAppCheck,
  cors: true,
} as const;
