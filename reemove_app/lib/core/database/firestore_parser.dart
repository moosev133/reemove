import 'package:cloud_firestore/cloud_firestore.dart';

typedef FirestoreMap = Map<String, dynamic>;

abstract final class FirestoreParser {
  static String string(FirestoreMap data, String key, {String? fallback}) {
    final Object? value = data[key];
    if (value is String) {
      return value;
    }
    if (fallback != null) {
      return fallback;
    }
    throw FormatException(
      'Expected String at "$key", got ${value.runtimeType}.',
    );
  }

  static String? nullableString(FirestoreMap data, String key) {
    final Object? value = data[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw FormatException('Expected nullable String at "$key".');
  }

  static int integer(FirestoreMap data, String key, {int? fallback}) {
    final Object? value = data[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (fallback != null) {
      return fallback;
    }
    throw FormatException('Expected int at "$key".');
  }

  static int? nullableInteger(FirestoreMap data, String key) {
    final Object? value = data[key];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Expected nullable int at "$key".');
  }

  static double number(FirestoreMap data, String key, {double? fallback}) {
    final Object? value = data[key];
    if (value is num) {
      return value.toDouble();
    }
    if (fallback != null) {
      return fallback;
    }
    throw FormatException('Expected number at "$key".');
  }

  static bool boolean(FirestoreMap data, String key, {bool? fallback}) {
    final Object? value = data[key];
    if (value is bool) {
      return value;
    }
    if (fallback != null) {
      return fallback;
    }
    throw FormatException('Expected bool at "$key".');
  }

  static DateTime dateTime(FirestoreMap data, String key, {DateTime? fallback}) {
    final DateTime? parsed = _tryParseDateTime(data[key]);
    if (parsed != null) {
      return parsed;
    }
    if (fallback != null) {
      return fallback.toUtc();
    }
    throw FormatException('Expected Timestamp at "$key".');
  }

  static DateTime? nullableDateTime(FirestoreMap data, String key) {
    final Object? value = data[key];
    if (value == null) {
      return null;
    }
    final DateTime? parsed = _tryParseDateTime(value);
    if (parsed != null) {
      return parsed;
    }
    throw FormatException('Expected nullable Timestamp at "$key".');
  }

  static DateTime? _tryParseDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    if (value is Map) {
      final Object? seconds = value['_seconds'] ?? value['seconds'];
      final Object? nanos = value['_nanoseconds'] ?? value['nanoseconds'];
      if (seconds is num) {
        final int nanoPart = nanos is num ? nanos.toInt() : 0;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds.toInt() * 1000 + (nanoPart / 1000000).round(),
          isUtc: true,
        );
      }
    }
    return null;
  }

  static GeoPoint geoPoint(FirestoreMap data, String key) {
    final Object? value = data[key];
    if (value is GeoPoint) {
      return value;
    }
    throw FormatException('Expected GeoPoint at "$key".');
  }

  static List<String> stringList(
    FirestoreMap data,
    String key, {
    List<String> fallback = const <String>[],
  }) {
    final Object? value = data[key];
    if (value == null) {
      return fallback;
    }
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    throw FormatException('Expected List<String> at "$key".');
  }

  static FirestoreMap map(
    FirestoreMap data,
    String key, {
    FirestoreMap fallback = const <String, dynamic>{},
  }) {
    final Object? value = data[key];
    if (value == null) {
      return fallback;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw FormatException('Expected map at "$key".');
  }

  static List<FirestoreMap> mapList(
    FirestoreMap data,
    String key, {
    List<FirestoreMap> fallback = const <FirestoreMap>[],
  }) {
    final Object? value = data[key];
    if (value == null) {
      return fallback;
    }
    if (value is! List) {
      throw FormatException('Expected list at "$key".');
    }
    return value
        .map((Object? item) {
          if (item is Map<String, dynamic>) {
            return item;
          }
          if (item is Map) {
            return item.cast<String, dynamic>();
          }
          throw FormatException('Expected map item at "$key".');
        })
        .toList(growable: false);
  }

  static Map<String, String> stringMap(
    FirestoreMap data,
    String key, {
    Map<String, String> fallback = const <String, String>{},
  }) {
    final FirestoreMap raw = map(data, key, fallback: fallback);
    return raw.map((String key, Object? value) {
      if (value is! String) {
        throw FormatException('Expected String value at "$key".');
      }
      return MapEntry<String, String>(key, value);
    });
  }
}
