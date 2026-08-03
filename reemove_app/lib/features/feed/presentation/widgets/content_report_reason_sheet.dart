import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/content_report.dart';

/// Shared reason picker for post and profile reports.
Future<ContentReportReason?> showContentReportReasonSheet(
  BuildContext context, {
  String title = 'Why are you reporting this?',
}) {
  return showModalBottomSheet<ContentReportReason>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => _ContentReportReasonSheet(title: title),
  );
}

class _ContentReportReasonSheet extends StatelessWidget {
  const _ContentReportReasonSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const List<(ContentReportReason, String)> reasons =
        <(ContentReportReason, String)>[
          (ContentReportReason.spam, 'Spam or scam'),
          (ContentReportReason.harassment, 'Harassment or bullying'),
          (ContentReportReason.hate, 'Hateful conduct'),
          (ContentReportReason.violence, 'Violent content'),
          (ContentReportReason.dangerousActivity, 'Unsafe activity'),
          (ContentReportReason.nudity, 'Nudity or sexual content'),
          (
            ContentReportReason.misinformation,
            'False or misleading information',
          ),
          (ContentReportReason.impersonation, 'Impersonation'),
          (ContentReportReason.intellectualProperty, 'Intellectual property'),
          (ContentReportReason.other, 'Something else'),
        ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: reasons
                    .map(
                      ((ContentReportReason, String) item) => ListTile(
                        title: Text(item.$2),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).pop(item.$1),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
