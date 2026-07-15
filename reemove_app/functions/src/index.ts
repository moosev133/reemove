import {initializeApp} from "firebase-admin/app";
import {onCall} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2/options";

import {deleteAccount, retryAccountDeletions} from "./account/deleteAccount";
import {provisionAccount} from "./account/provisionAccount";
import {revokeSessions} from "./account/revokeSessions";
import {syncAuthProviders} from "./account/syncAuthProviders";
import {callableOptions, primaryRegion} from "./core/functionOptions";

initializeApp();
setGlobalOptions({
  region: primaryRegion,
  maxInstances: 100,
});

export {
  deleteAccount,
  provisionAccount,
  retryAccountDeletions,
  revokeSessions,
  syncAuthProviders,
};

export const healthCheck = onCall(callableOptions, async (request) => {
  return {
    ok: true,
    authenticated: request.auth !== undefined,
    appCheckVerified: request.app !== undefined,
    service: "reemove-functions",
    timestamp: new Date().toISOString(),
  };
});
