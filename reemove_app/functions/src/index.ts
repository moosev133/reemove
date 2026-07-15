import {initializeApp} from "firebase-admin/app";
import {onCall} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2/options";

import {deleteAccount, retryAccountDeletions} from "./account/deleteAccount";
import {provisionAccount} from "./account/provisionAccount";
import {revokeSessions} from "./account/revokeSessions";
import {syncAuthProviders} from "./account/syncAuthProviders";
import {completeOnboarding} from "./onboarding/completeOnboarding";
import {
  blockUser,
  createPostComment,
  deletePostComment,
  deleteStory,
  markStoryViewed,
  recordPostView,
  reportContent,
  toggleCommentLike,
  togglePostReaction,
} from "./feed/interactions";
import {publishPost, publishStory} from "./feed/publishContent";
import {fanoutPublishedPost} from "./feed/fanout";
import {
  completeMediaProcessing,
  expireStories,
  onContentUpload,
  processQueuedMedia,
} from "./media/mediaProcessing";
import {saveOnboardingProgress} from "./onboarding/saveOnboardingProgress";
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
  saveOnboardingProgress,
  completeOnboarding,
  publishPost,
  publishStory,
  fanoutPublishedPost,
  togglePostReaction,
  createPostComment,
  toggleCommentLike,
  deletePostComment,
  recordPostView,
  markStoryViewed,
  deleteStory,
  reportContent,
  blockUser,
  onContentUpload,
  processQueuedMedia,
  completeMediaProcessing,
  expireStories,
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
