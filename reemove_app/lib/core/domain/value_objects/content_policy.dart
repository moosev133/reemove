enum Visibility { public, followers, private }

enum ModerationState { active, pending, restricted, removed }

extension VisibilityStorageValue on Visibility {
  String get storageValue => switch (this) {
    Visibility.public => 'public',
    Visibility.followers => 'followers',
    Visibility.private => 'private',
  };

  static Visibility fromStorage(String value) => switch (value) {
    'public' => Visibility.public,
    'followers' => Visibility.followers,
    'private' => Visibility.private,
    _ => throw FormatException('Unsupported visibility: $value'),
  };
}

extension ModerationStateStorageValue on ModerationState {
  String get storageValue => switch (this) {
    ModerationState.active => 'active',
    ModerationState.pending => 'pending',
    ModerationState.restricted => 'restricted',
    ModerationState.removed => 'removed',
  };

  static ModerationState fromStorage(String value) => switch (value) {
    'active' => ModerationState.active,
    'pending' => ModerationState.pending,
    'restricted' => ModerationState.restricted,
    'removed' => ModerationState.removed,
    _ => throw FormatException('Unsupported moderation state: $value'),
  };
}
