class AccountProvisioningRequest {
  const AccountProvisioningRequest({
    required this.username,
    required this.displayName,
    required this.acceptedTerms,
    required this.acceptedPrivacy,
    required this.ageConfirmed,
  });

  final String username;
  final String displayName;
  final bool acceptedTerms;
  final bool acceptedPrivacy;
  final bool ageConfirmed;
}

class AccountProvisioningResult {
  const AccountProvisioningResult({
    required this.uid,
    required this.username,
    required this.created,
  });

  final String uid;
  final String username;
  final bool created;
}
