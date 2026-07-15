import '../../../../../core/domain/entities/entity_audit.dart';
import '../../../../../core/domain/value_objects/content_policy.dart';

enum SportCommunityType { team, club, trainingGroup, socialGroup }

enum SportCommunityJoinPolicy { open, approvalRequired, inviteOnly }

enum SportCommunityMembershipStatus {
  none,
  pending,
  member,
  administrator,
  owner,
}

class SportCommunity {
  const SportCommunity({
    required this.id,
    required this.sportId,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.type,
    required this.joinPolicy,
    required this.memberCount,
    required this.capacity,
    required this.tags,
    required this.city,
    required this.countryCode,
    required this.isVerified,
    required this.visibility,
    required this.moderationState,
    required this.audit,
    this.avatarUrl,
    this.coverUrl,
    this.pricingText,
  });

  final String id;
  final String sportId;
  final String ownerId;
  final String name;
  final String description;
  final SportCommunityType type;
  final SportCommunityJoinPolicy joinPolicy;
  final int memberCount;
  final int capacity;
  final List<String> tags;
  final String city;
  final String countryCode;
  final bool isVerified;
  final Visibility visibility;
  final ModerationState moderationState;
  final EntityAudit audit;
  final String? avatarUrl;
  final String? coverUrl;
  final String? pricingText;

  bool get isFull => capacity > 0 && memberCount >= capacity;
}

class SportCommunityMember {
  const SportCommunityMember({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.status,
    required this.joinedAt,
    this.avatarUrl,
    this.sportLevel,
  });

  final String userId;
  final String displayName;
  final String username;
  final SportCommunityMembershipStatus status;
  final DateTime joinedAt;
  final String? avatarUrl;
  final String? sportLevel;
}
