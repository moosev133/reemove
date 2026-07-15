import {initializeApp} from "firebase-admin/app";
import {onCall} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2/options";

import {deleteAccount, retryAccountDeletions} from "./account/deleteAccount";
import {provisionAccount} from "./account/provisionAccount";
import {revokeSessions} from "./account/revokeSessions";
import {syncAuthProviders} from "./account/syncAuthProviders";
import {
  claimChallengeRewards,
  createChallenge,
  getChallengeProofReviewUrl,
  joinChallenge,
  leaveChallenge,
  reviewChallengeSubmission,
  setChallengeReminder,
  submitChallengeProgress,
} from "./challenges/challenges";
import {
  finalizeExpiredChallenges,
  generateWeeklyChallenges,
  generateWeeklyChallengesNow,
  refreshChallengeLeaderboards,
  sendChallengeReminders,
} from "./challenges/challengeAutomation";
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
import {
  cancelFollowRequest,
  followProfile,
  getProfileRelationship,
  getPublicProfile,
  listBlockedProfiles,
  listProfileConnections,
  removeFollower,
  respondToFollowRequest,
  unblockUser,
  unfollowProfile,
} from "./profile/followGraph";
import {loadProfileContent} from "./profile/profileContent";
import {
  cancelVerificationRequest,
  reviewVerificationRequest,
  submitVerificationRequest,
  syncProfileSnapshots,
  updateProfile,
  updateProfilePrivacy,
} from "./profile/profileManagement";
import {
  createDirectConversation,
  createGroupConversation,
  leaveConversation,
  updateConversationPreferences,
  updateGroupConversation,
} from "./messaging/conversations";
import {
  registerMessagingDevice,
  unregisterMessagingDevice,
} from "./messaging/deviceTokens";
import {
  deleteMessage,
  editMessage,
  markConversationRead,
  reportMessage,
  sendMessage,
  toggleMessageReaction,
} from "./messaging/messages";
import {notifyConversationMessage} from "./messaging/notifications";
import {
  clearReadNotifications,
  deleteNotification,
  markAllNotificationsRead,
  markNotificationRead,
  updateNotificationPreferences,
} from "./notifications/notificationCallables";
import {
  cleanupNotificationData,
  flushDeferredNotifications,
} from "./notifications/notificationAutomation";
import {
  notifyChallengeRewardCreated,
  notifyChallengeSubmissionCreated,
  notifyChallengeSubmissionReviewed,
  notifyFollowerCreated,
  notifyFollowRequestCreated,
  notifyMarketplaceListingWritten,
  notifyPostCommentCreated,
  notifyPostReactionWritten,
  notifyScheduledEventStarting,
  notifySportsEventAttendanceCreated,
} from "./notifications/notificationTriggers";
import {
  changeMarketplaceListingStatus,
  createMarketplaceListing,
  expireMarketplaceListings,
  getMarketplaceSeller,
  loadMarketplaceSellerListings,
  loadMarketplaceFavorites,
  loadMyMarketplaceListings,
  publishMarketplaceListing,
  recordMarketplaceView,
  reportMarketplaceListing,
  reviewMarketplaceListing,
  searchMarketplace,
  startMarketplaceConversation,
  toggleMarketplaceFavorite,
  updateMarketplaceListing,
} from "./marketplace/marketplace";
import {
  searchNearby,
  updateDiscoveryLocation,
} from "./nearby/nearbySearch";
import {
  syncNearbyEvent,
  syncNearbyPerson,
  syncNearbyPersonPreferences,
  syncNearbyPersonPrivateProfile,
  syncNearbyPlace,
  syncNearbyRoute,
} from "./nearby/nearbyIndex";
import {
  attendSportsEvent,
  createSportCommunity,
  createSportsEvent,
  joinSportCommunity,
  leaveSportCommunity,
  leaveSportsEvent,
  respondSportCommunityRequest,
  upsertTrainerService,
} from "./sports/sportsHub";
import {
  rebuildSportLeaderboardsNow,
  refreshSportLeaderboards,
} from "./sports/leaderboards";
import {
  aiCoach,
  createSportsContent,
  generateNutritionGuidance,
  generateSafeChallenge,
  generateWorkoutPlan,
  getTrainerBusinessInsights,
  rankPlayerMatches,
} from "./ai/functions";
import {callableOptions, primaryRegion} from "./core/functionOptions";

initializeApp();
setGlobalOptions({
  region: primaryRegion,
  maxInstances: 100,
});

export {
  deleteAccount,
  createChallenge,
  joinChallenge,
  leaveChallenge,
  submitChallengeProgress,
  reviewChallengeSubmission,
  setChallengeReminder,
  claimChallengeRewards,
  generateWeeklyChallenges,
  generateWeeklyChallengesNow,
  getChallengeProofReviewUrl,
  refreshChallengeLeaderboards,
  finalizeExpiredChallenges,
  sendChallengeReminders,
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
  getProfileRelationship,
  getPublicProfile,
  followProfile,
  unfollowProfile,
  cancelFollowRequest,
  respondToFollowRequest,
  removeFollower,
  listProfileConnections,
  listBlockedProfiles,
  unblockUser,
  loadProfileContent,
  updateProfile,
  updateProfilePrivacy,
  submitVerificationRequest,
  cancelVerificationRequest,
  reviewVerificationRequest,
  syncProfileSnapshots,
  createDirectConversation,
  createGroupConversation,
  updateGroupConversation,
  leaveConversation,
  updateConversationPreferences,
  sendMessage,
  editMessage,
  deleteMessage,
  toggleMessageReaction,
  markConversationRead,
  reportMessage,
  registerMessagingDevice,
  unregisterMessagingDevice,
  notifyConversationMessage,
  updateNotificationPreferences,
  markNotificationRead,
  markAllNotificationsRead,
  deleteNotification,
  clearReadNotifications,
  flushDeferredNotifications,
  cleanupNotificationData,
  notifyFollowRequestCreated,
  notifyFollowerCreated,
  notifyPostCommentCreated,
  notifyPostReactionWritten,
  notifyChallengeSubmissionCreated,
  notifyChallengeSubmissionReviewed,
  notifyChallengeRewardCreated,
  notifySportsEventAttendanceCreated,
  notifyScheduledEventStarting,
  notifyMarketplaceListingWritten,
  onContentUpload,
  processQueuedMedia,
  completeMediaProcessing,
  expireStories,
  createSportCommunity,
  joinSportCommunity,
  leaveSportCommunity,
  respondSportCommunityRequest,
  createSportsEvent,
  attendSportsEvent,
  leaveSportsEvent,
  upsertTrainerService,
  refreshSportLeaderboards,
  rebuildSportLeaderboardsNow,
  searchNearby,
  updateDiscoveryLocation,
  createMarketplaceListing,
  updateMarketplaceListing,
  publishMarketplaceListing,
  changeMarketplaceListingStatus,
  searchMarketplace,
  loadMarketplaceSellerListings,
  loadMarketplaceFavorites,
  loadMyMarketplaceListings,
  getMarketplaceSeller,
  toggleMarketplaceFavorite,
  recordMarketplaceView,
  reportMarketplaceListing,
  reviewMarketplaceListing,
  startMarketplaceConversation,
  expireMarketplaceListings,
  syncNearbyPlace,
  syncNearbyEvent,
  syncNearbyRoute,
  syncNearbyPerson,
  syncNearbyPersonPreferences,
  syncNearbyPersonPrivateProfile,
  aiCoach,
  generateWorkoutPlan,
  generateNutritionGuidance,
  rankPlayerMatches,
  generateSafeChallenge,
  createSportsContent,
  getTrainerBusinessInsights,
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
