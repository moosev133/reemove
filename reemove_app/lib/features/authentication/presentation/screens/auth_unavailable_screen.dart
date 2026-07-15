import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/providers/core_providers.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_scaffold.dart';

class AuthUnavailableScreen extends ConsumerWidget {
  const AuthUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(firebaseBootstrapReportProvider);
    return AuthScaffold(
      heroTitle: 'Configuration\nrequired.',
      heroMessage:
          'The application shell is healthy, but this build is not connected to its Firebase project yet.',
      child: AuthCard(
        icon: Icons.settings_suggest_rounded,
        title: 'Firebase is unavailable',
        subtitle:
            'Add the project-specific FlutterFire files and restart the application.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Required owner actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const _SetupRow(
              number: '1',
              text: 'Run flutterfire configure for each environment.',
            ),
            const _SetupRow(
              number: '2',
              text: 'Enable Email/Password, Google, and Apple providers.',
            ),
            const _SetupRow(
              number: '3',
              text: 'Deploy Firestore rules, indexes, and Cloud Functions.',
            ),
            if (report.details != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Technical details'),
                children: <Widget>[
                  SelectableText(
                    report.details!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(radius: 15, child: Text(number)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}
