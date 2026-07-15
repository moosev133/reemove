import 'package:flutter/material.dart';

import '../../domain/entities/messaging_presence.dart';

class PresenceBadge extends StatelessWidget {
  const PresenceBadge({required this.state, super.key});

  final MessagingPresenceState state;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      MessagingPresenceState.online => Colors.green,
      MessagingPresenceState.away => Colors.orange,
      MessagingPresenceState.offline => Theme.of(context).colorScheme.outline,
    };
    return Semantics(
      label: state.name,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 2,
          ),
        ),
      ),
    );
  }
}
