import '../../../../../core/domain/value_objects/content_policy.dart';
import '../../domain/entities/sport_community.dart';
import '../dto/sport_community_dto.dart';

extension SportCommunityDtoMapper on SportCommunityDto {
  SportCommunity toDomain() => SportCommunity(
    id: id,
    sportId: sportId,
    ownerId: ownerId,
    name: name,
    description: description,
    type: SportCommunityType.values.byName(type),
    joinPolicy: SportCommunityJoinPolicy.values.byName(joinPolicy),
    memberCount: memberCount,
    capacity: capacity,
    tags: tags,
    city: city,
    countryCode: countryCode,
    isVerified: isVerified,
    visibility: VisibilityStorageValue.fromStorage(visibility),
    moderationState: ModerationStateStorageValue.fromStorage(moderationState),
    audit: audit.toDomain(),
    avatarUrl: avatarUrl,
    coverUrl: coverUrl,
    pricingText: pricingText,
  );
}

extension SportCommunityMemberDtoMapper on SportCommunityMemberDto {
  SportCommunityMember toDomain() => SportCommunityMember(
    userId: userId,
    displayName: displayName,
    username: username,
    status: switch (status) {
      'owner' => SportCommunityMembershipStatus.owner,
      'administrator' ||
      'admin' => SportCommunityMembershipStatus.administrator,
      'pending' => SportCommunityMembershipStatus.pending,
      _ => SportCommunityMembershipStatus.member,
    },
    joinedAt: joinedAt,
    avatarUrl: avatarUrl,
    sportLevel: sportLevel,
  );
}
