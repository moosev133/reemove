class MarketplaceSellerProfile {
  const MarketplaceSellerProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.isVerified,
    required this.activeListingCount,
    required this.soldListingCount,
    required this.memberSince,
    this.avatarUrl,
    this.verificationType,
    this.locality,
  });

  final String uid;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final String? verificationType;
  final String? locality;
  final int activeListingCount;
  final int soldListingCount;
  final DateTime memberSince;
}
