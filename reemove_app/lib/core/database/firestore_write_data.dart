import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_parser.dart';

abstract final class FirestoreWriteData {
  static FirestoreMap forCreate(FirestoreMap data, {int schemaVersion = 1}) =>
      <String, dynamic>{
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': schemaVersion,
      };

  static FirestoreMap forUpdate(FirestoreMap data) => <String, dynamic>{
    ...data,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
