import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/features/profile/application/profile_providers.dart';
import 'package:reemove/features/profile/domain/entities/profile_connection.dart';

void main() {
  test('incoming requests query targets owner profile requests list', () {
    const ProfileConnectionsQuery query = ProfileConnectionsQuery(
      profileId: 'owner',
      type: ProfileConnectionType.requests,
    );

    expect(query.profileId, 'owner');
    expect(query.type, ProfileConnectionType.requests);
  });
}
