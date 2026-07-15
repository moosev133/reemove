import 'package:flutter/widgets.dart';

/// Stable selectors for widget/integration tests and accessibility inspection.
/// Add these keys to the matching production widgets.
abstract final class TestKeys {
  static const signInEmail = Key('auth.sign_in.email');
  static const signInPassword = Key('auth.sign_in.password');
  static const signInSubmit = Key('auth.sign_in.submit');
  static const registerSubmit = Key('auth.register.submit');
  static const onboardingNext = Key('onboarding.next');
  static const onboardingFinish = Key('onboarding.finish');

  static const navHome = Key('nav.home');
  static const navDiscover = Key('nav.discover');
  static const navSports = Key('nav.sports');
  static const navCreate = Key('nav.create');
  static const navMessages = Key('nav.messages');
  static const navProfile = Key('nav.profile');

  static const feedList = Key('feed.list');
  static const feedRefresh = Key('feed.refresh');
  static const createPostSubmit = Key('post.create.submit');
  static const commentSubmit = Key('comment.submit');

  static const messageInput = Key('message.input');
  static const messageSend = Key('message.send');
  static const conversationList = Key('messages.conversation_list');

  static const nearbyMap = Key('nearby.map');
  static const nearbyFilters = Key('nearby.filters');
  static const eventJoin = Key('event.join');

  static const challengeJoin = Key('challenge.join');
  static const challengeProgressSubmit = Key('challenge.progress.submit');

  static const marketplaceSearch = Key('marketplace.search');
  static const marketplaceCreate = Key('marketplace.create');
  static const marketplaceContactSeller = Key('marketplace.contact_seller');

  static const notificationsList = Key('notifications.list');
  static const notificationsMarkAllRead = Key('notifications.mark_all_read');

  static const aiHub = Key('ai.hub');
  static const aiSubmit = Key('ai.submit');
  static const aiResult = Key('ai.result');

  static const retry = Key('common.retry');
  static const emptyState = Key('common.empty_state');
  static const errorState = Key('common.error_state');
}
