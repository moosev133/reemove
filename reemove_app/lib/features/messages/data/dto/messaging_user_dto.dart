import '../../../../core/database/firestore_parser.dart';

class MessagingUserDto {
  const MessagingUserDto({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isVerified,
    this.avatarUrl,
  });

  factory MessagingUserDto.fromMap(FirestoreMap data) => MessagingUserDto(
    id: FirestoreParser.string(data, 'id'),
    username: FirestoreParser.string(data, 'username', fallback: ''),
    displayName: FirestoreParser.string(data, 'displayName'),
    avatarUrl: FirestoreParser.nullableString(data, 'avatarUrl'),
    isVerified: FirestoreParser.boolean(data, 'isVerified', fallback: false),
  );

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  FirestoreMap toMap() => <String, Object?>{
    'id': id,
    'username': username,
    'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'isVerified': isVerified,
  };
}
