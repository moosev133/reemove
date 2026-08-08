abstract final class AppRoutes {
  static const String startup = '/';
  static const String authUnavailable = '/auth/unavailable';
  static const String authWelcome = '/auth';
  static const String signIn = '/auth/sign-in';
  static const String signUp = '/auth/sign-up';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyEmail = '/auth/verify-email';
  static const String usernameSetup = '/auth/username';
  static const String accountBlocked = '/auth/blocked';
  static const String onboarding = '/onboarding';

  static const String home = '/home';
  static const String activity = '/home/activity';
  static const String notificationSettings = '/home/activity/settings';
  static const String reels = '/home/reels';
  static const String discover = '/discover';
  static const String discoverSearch = '/discover/search';
  static const String aiHub = '/discover/ai';
  static const String aiCoach = '/discover/ai/coach';
  static const String aiWorkout = '/discover/ai/workout';
  static const String aiNutrition = '/discover/ai/nutrition';
  static const String aiMatchmaker = '/discover/ai/matchmaker';
  static const String aiChallenge = '/discover/ai/challenge';
  static const String aiContent = '/discover/ai/content';
  static const String aiTrainerInsights = '/discover/ai/trainer-insights';
  static const String sports = '/sports';
  static const String create = '/create';
  static const String messages = '/messages';
  static const String newConversation = '/messages/new';
  static const String newGroupConversation = '/messages/group/new';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String profileSettings = '/profile/settings';
  static const String profilePrivacy = '/profile/settings/privacy';
  static const String blockedProfiles = '/profile/settings/blocked';
  static const String profileVerification = '/profile/settings/verification';

  static const String accountSecurity = '/account/security';

  static String homePost(String postId) => '/home/post/${_segment(postId)}';

  static String storyGroup(String authorId) =>
      '/home/stories/${_segment(authorId)}';

  static String discoverCategory(String category) =>
      '/discover/category/${_segment(category)}';

  static const String nearby = '/discover/nearby';

  static String nearbyForSport(String sportId) => Uri(
    path: nearby,
    queryParameters: <String, String>{'sport': sportId},
  ).toString();

  static String nearbyForType(String type) => Uri(
    path: nearby,
    queryParameters: <String, String>{'type': type},
  ).toString();

  static String sportsRoute(String routeId) =>
      '$nearby/routes/${_segment(routeId)}';

  static const String challenges = '/discover/challenges';
  static const String challengeRewards = '/discover/challenges/rewards';
  static const String marketplace = '/discover/marketplace';
  static const String marketplaceFavorites = '/discover/marketplace/favorites';
  static const String myMarketplaceListings = '/profile/marketplace';
  static const String groups = '/discover/groups';
  static const String createGroup = '/discover/groups/create';
  static const String groupInvitations = '/discover/groups/invitations';

  static String group(String groupId) =>
      '/discover/groups/${_segment(groupId)}';

  static String editGroup(String groupId) => '${group(groupId)}/edit';

  static String groupMembers(String groupId) => '${group(groupId)}/members';

  static String groupJoinRequests(String groupId) =>
      '${group(groupId)}/requests';

  static String groupInvite(String groupId) => '${group(groupId)}/invite';

  static String groupSchedule(String groupId) => '${group(groupId)}/schedule';

  static String groupChannels(String groupId) => '${group(groupId)}/channels';

  static String groupNotificationSettings(String groupId) =>
      '${group(groupId)}/notifications';

  static String groupChannel(String groupId, String channelType) =>
      '${groupChannels(groupId)}/${_segment(channelType)}';

  /// Notification / deep-link helper including optional message focus.
  static String groupChannelDeepLink(
    String groupId,
    String channelType, {
    String? messageId,
  }) {
    final String path = groupChannel(groupId, channelType);
    if (messageId == null || messageId.trim().isEmpty) {
      return path;
    }
    return Uri(
      path: path,
      queryParameters: <String, String>{'messageId': messageId.trim()},
    ).toString();
  }

  static String groupDetail(String groupId) => group(groupId);

  static String challengesForSport(String sportId) => Uri(
    path: challenges,
    queryParameters: <String, String>{'sport': sportId},
  ).toString();

  static String challenge(String challengeId) =>
      '$challenges/${_segment(challengeId)}';

  static String submitChallengeProgress(String challengeId) =>
      '${challenge(challengeId)}/submit';

  static String reviewChallengeSubmissions(String challengeId) =>
      '${challenge(challengeId)}/review';

  static String challengeAlias(String challengeId) =>
      '/ch/${_segment(challengeId)}';

  static String get createChallenge => createFlow('challenge');

  static String marketplaceForSport(String sportId) => Uri(
    path: marketplace,
    queryParameters: <String, String>{'sport': sportId},
  ).toString();

  static String marketplaceListing(String listingId) =>
      '$marketplace/${_segment(listingId)}';

  static String marketplaceSeller(String sellerId) =>
      '$marketplace/seller/${_segment(sellerId)}';

  static String marketplaceAlias(String listingId) =>
      '/m/${_segment(listingId)}';

  static String get createMarketplaceListing => createFlow('listing');

  static String editMarketplaceListing(String listingId) =>
      '/create/listing/${_segment(listingId)}/edit';

  static String conversationForListing(
    String conversationId,
    String listingId,
  ) => Uri(
    path: conversation(conversationId),
    queryParameters: <String, String>{'listing': listingId},
  ).toString();

  static String sportHub(String sportId) => '/sports/${_segment(sportId)}';

  static String sportPlaces(String sportId) => '${sportHub(sportId)}/places';

  static String sportPlace(String sportId, String placeId) =>
      '${sportPlaces(sportId)}/${_segment(placeId)}';

  static String sportCommunities(String sportId) =>
      '${sportHub(sportId)}/communities';

  static String sportCommunity(String sportId, String communityId) =>
      '${sportCommunities(sportId)}/${_segment(communityId)}';

  static String createSportCommunity(String sportId) =>
      '${sportCommunities(sportId)}/create';

  static String sportEvents(String sportId) => '${sportHub(sportId)}/events';

  static String sportEvent(String sportId, String eventId) =>
      '${sportEvents(sportId)}/${_segment(eventId)}';

  static String createSportEvent(String sportId) =>
      '${sportEvents(sportId)}/create';

  static String sportTrainers(String sportId) =>
      '${sportHub(sportId)}/trainers';

  static String sportTrainer(String sportId, String trainerId) =>
      '${sportTrainers(sportId)}/${_segment(trainerId)}';

  static String manageTrainerService(String sportId) =>
      '${sportTrainers(sportId)}/service';

  static String sportLeaderboards(String sportId) =>
      '${sportHub(sportId)}/leaderboards';

  static String createFlow(String creationType) =>
      '/create/${_segment(creationType)}';

  static String conversation(String conversationId) =>
      '/messages/${_segment(conversationId)}';

  static String conversationDetails(String conversationId) =>
      '/messages/${_segment(conversationId)}/details';

  static String newConversationFor(String username) => Uri(
    path: newConversation,
    queryParameters: <String, String>{'username': username},
  ).toString();

  static String publicProfile(String username) =>
      '/profile/user/${_segment(username.toLowerCase())}';

  static String profileConnections(String profileId, String type) =>
      '/profile/connections/${_segment(profileId)}/${_segment(type)}';

  static String postAlias(String postId) => '/p/${_segment(postId)}';

  static String profileAlias(String username) =>
      '/u/${_segment(username.toLowerCase())}';

  /// Shareable short profile link (`/u/:username`).
  static String shareableProfile(String username) => profileAlias(username);

  static String conversationAlias(String conversationId) =>
      '/c/${_segment(conversationId)}';

  static String sportAlias(String sportId) => '/s/${_segment(sportId)}';

  /// Resolves short aliases (for example `/u/:username`) to canonical routes.
  /// Also rewrites sports-group notification paths `/groups/:id/...` to the
  /// shell location under `/discover/groups/:id/...`.
  static String normalizeDeepLinkLocation(String location) {
    final Uri? uri = Uri.tryParse(location);
    final String path = (uri?.path.isNotEmpty ?? false) ? uri!.path : location;
    final Map<String, String> query =
        uri?.queryParameters ?? const <String, String>{};

    String normalized = path;
    final Match? sportsGroupMatch = RegExp(
      r'^/groups/([^/]+)(/.*)?$',
    ).firstMatch(path);
    if (sportsGroupMatch != null) {
      final String groupId = Uri.decodeComponent(sportsGroupMatch.group(1)!);
      final String suffix = sportsGroupMatch.group(2) ?? '';
      normalized = '${group(groupId)}$suffix';
    } else {
      final Match? profileAliasMatch = RegExp(
        r'^/u/([^/]+)/?$',
      ).firstMatch(path);
      if (profileAliasMatch != null) {
        normalized = publicProfile(
          Uri.decodeComponent(profileAliasMatch.group(1)!),
        );
      } else {
        final Match? postAliasMatch = RegExp(
          r'^/p/([^/]+)/?$',
        ).firstMatch(path);
        if (postAliasMatch != null) {
          normalized = homePost(Uri.decodeComponent(postAliasMatch.group(1)!));
        } else {
          final Match? conversationAliasMatch = RegExp(
            r'^/c/([^/]+)/?$',
          ).firstMatch(path);
          if (conversationAliasMatch != null) {
            normalized = conversation(
              Uri.decodeComponent(conversationAliasMatch.group(1)!),
            );
          }
        }
      }
    }

    if (query.isEmpty) {
      return normalized;
    }
    return Uri(path: normalized, queryParameters: query).toString();
  }

  static String withReturnTo(String target, String? returnTo) {
    if (returnTo == null || returnTo.trim().isEmpty) {
      return target;
    }
    return Uri(
      path: target,
      queryParameters: <String, String>{'returnTo': returnTo},
    ).toString();
  }

  static String inheritReturnTo(Uri currentUri, String target) {
    return withReturnTo(target, currentUri.queryParameters['returnTo']);
  }

  static bool isShellLocation(String location) {
    final String path = Uri.tryParse(location)?.path ?? location;
    return <String>[
      home,
      discover,
      sports,
      groups,
      create,
      messages,
      profile,
    ].any((String root) => path == root || path.startsWith('$root/'));
  }

  static bool isProtectedAlias(String location) {
    final String path = Uri.tryParse(location)?.path ?? location;
    return <String>[
          '/p/',
          '/u/',
          '/c/',
          '/s/',
          '/ch/',
          '/m/',
          '/groups/',
        ].any((String prefix) => path.startsWith(prefix)) ||
        path == '/groups';
  }

  static bool isAuthenticatedLocation(String location) {
    final String path = Uri.tryParse(location)?.path ?? location;
    return isShellLocation(path) ||
        isProtectedAlias(path) ||
        path == accountSecurity;
  }

  static String _segment(String value) => Uri.encodeComponent(value.trim());
}

abstract final class AppRouteNames {
  static const String startup = 'startup';
  static const String authUnavailable = 'auth-unavailable';
  static const String authWelcome = 'auth-welcome';
  static const String signIn = 'sign-in';
  static const String signUp = 'sign-up';
  static const String forgotPassword = 'forgot-password';
  static const String verifyEmail = 'verify-email';
  static const String usernameSetup = 'username-setup';
  static const String accountBlocked = 'account-blocked';
  static const String onboarding = 'onboarding';
  static const String accountSecurity = 'account-security';

  static const String home = 'home';
  static const String activity = 'activity';
  static const String notificationSettings = 'notification-settings';
  static const String homePost = 'home-post';
  static const String reels = 'reels';
  static const String storyGroup = 'story-group';
  static const String discover = 'discover';
  static const String discoverSearch = 'discover-search';
  static const String discoverCategory = 'discover-category';
  static const String aiHub = 'ai-hub';
  static const String aiCoach = 'ai-coach';
  static const String aiWorkout = 'ai-workout';
  static const String aiNutrition = 'ai-nutrition';
  static const String aiMatchmaker = 'ai-matchmaker';
  static const String aiChallenge = 'ai-challenge';
  static const String aiContent = 'ai-content';
  static const String aiTrainerInsights = 'ai-trainer-insights';
  static const String nearby = 'nearby';
  static const String sportsRoute = 'sports-route';
  static const String challenges = 'challenges';
  static const String challenge = 'challenge';
  static const String challengeRewards = 'challenge-rewards';
  static const String submitChallengeProgress = 'submit-challenge-progress';
  static const String reviewChallengeSubmissions =
      'review-challenge-submissions';
  static const String marketplace = 'marketplace';
  static const String marketplaceListing = 'marketplace-listing';
  static const String marketplaceSeller = 'marketplace-seller';
  static const String marketplaceFavorites = 'marketplace-favorites';
  static const String editMarketplaceListing = 'edit-marketplace-listing';
  static const String myMarketplaceListings = 'my-marketplace-listings';
  static const String groups = 'groups';
  static const String createGroup = 'create-group';
  static const String groupInvitations = 'group-invitations';
  static const String groupDetail = 'group-detail';
  static const String editGroup = 'edit-group';
  static const String groupMembers = 'group-members';
  static const String groupJoinRequests = 'group-join-requests';
  static const String groupInvite = 'group-invite';
  static const String groupSchedule = 'group-schedule';
  static const String groupChannels = 'group-channels';
  static const String groupChannel = 'group-channel';
  static const String groupNotificationSettings =
      'group-notification-settings';
  static const String sports = 'sports';
  static const String sportHub = 'sport-hub';
  static const String sportPlaces = 'sport-places';
  static const String sportPlace = 'sport-place';
  static const String sportCommunities = 'sport-communities';
  static const String sportCommunity = 'sport-community';
  static const String createSportCommunity = 'create-sport-community';
  static const String sportEvents = 'sport-events';
  static const String sportEvent = 'sport-event';
  static const String createSportEvent = 'create-sport-event';
  static const String sportTrainers = 'sport-trainers';
  static const String sportTrainer = 'sport-trainer';
  static const String manageTrainerService = 'manage-trainer-service';
  static const String sportLeaderboards = 'sport-leaderboards';
  static const String create = 'create';
  static const String createFlow = 'create-flow';
  static const String messages = 'messages';
  static const String newConversation = 'new-conversation';
  static const String newGroupConversation = 'new-group-conversation';
  static const String conversation = 'conversation';
  static const String conversationDetails = 'conversation-details';
  static const String profile = 'profile';
  static const String publicProfile = 'public-profile';
  static const String editProfile = 'edit-profile';
  static const String profileSettings = 'profile-settings';
  static const String profilePrivacy = 'profile-privacy';
  static const String blockedProfiles = 'blocked-profiles';
  static const String profileVerification = 'profile-verification';
  static const String profileConnections = 'profile-connections';

  static const String postAlias = 'post-alias';
  static const String profileAlias = 'profile-alias';
  static const String conversationAlias = 'conversation-alias';
  static const String sportAlias = 'sport-alias';
  static const String challengeAlias = 'challenge-alias';
  static const String marketplaceAlias = 'marketplace-alias';
}
