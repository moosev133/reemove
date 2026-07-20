import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../application/authentication_providers.dart';

/// Signs out of Firebase Auth and Google, clears local session state, and
/// replaces the navigation stack with the auth welcome screen.
Future<bool> performLogout(BuildContext context, WidgetRef ref) async {
  final bool signedOut = await ref
      .read(authActionControllerProvider.notifier)
      .signOut();
  if (!context.mounted || !signedOut) {
    return false;
  }
  context.go(AppRoutes.authWelcome);
  return true;
}
