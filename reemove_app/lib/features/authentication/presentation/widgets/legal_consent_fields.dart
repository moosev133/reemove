import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

class LegalConsentFields extends StatelessWidget {
  const LegalConsentFields({
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.ageConfirmed,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onAgeChanged,
    super.key,
  });

  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool ageConfirmed;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<bool> onAgeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ConsentTile(
          value: ageConfirmed,
          onChanged: onAgeChanged,
          text:
              'I confirm that I meet the minimum age required to use ReeMove in my country.',
        ),
        const SizedBox(height: AppSpacing.xs),
        _ConsentTile(
          value: acceptedTerms,
          onChanged: onTermsChanged,
          text: 'I agree to the ReeMove Terms of Service.',
        ),
        const SizedBox(height: AppSpacing.xs),
        _ConsentTile(
          value: acceptedPrivacy,
          onChanged: onPrivacyChanged,
          text: 'I have read and accept the Privacy Policy.',
        ),
      ],
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: value,
              onChanged: (bool? checked) => onChanged(checked ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
