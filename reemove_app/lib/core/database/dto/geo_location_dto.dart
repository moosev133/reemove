import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/value_objects/geo_location.dart';
import '../firestore_parser.dart';

class GeoLocationDto {
  const GeoLocationDto({
    required this.latitude,
    required this.longitude,
    required this.geohash,
    this.locality,
    this.administrativeArea,
    this.countryCode,
  });

  factory GeoLocationDto.fromMap(FirestoreMap data) {
    final GeoPoint point = FirestoreParser.geoPoint(data, 'location');
    return GeoLocationDto(
      latitude: point.latitude,
      longitude: point.longitude,
      geohash: FirestoreParser.string(data, 'geohash'),
      locality: FirestoreParser.nullableString(data, 'locality'),
      administrativeArea: FirestoreParser.nullableString(
        data,
        'administrativeArea',
      ),
      countryCode: FirestoreParser.nullableString(data, 'countryCode'),
    );
  }

  factory GeoLocationDto.fromDomain(GeoLocation value) => GeoLocationDto(
    latitude: value.latitude,
    longitude: value.longitude,
    geohash: value.geohash,
    locality: value.locality,
    administrativeArea: value.administrativeArea,
    countryCode: value.countryCode,
  );

  final double latitude;
  final double longitude;
  final String geohash;
  final String? locality;
  final String? administrativeArea;
  final String? countryCode;

  GeoLocation toDomain() => GeoLocation(
    latitude: latitude,
    longitude: longitude,
    geohash: geohash,
    locality: locality,
    administrativeArea: administrativeArea,
    countryCode: countryCode,
  );

  FirestoreMap toMap() => <String, Object?>{
    'location': GeoPoint(latitude, longitude),
    'geohash': geohash,
    if (locality != null) 'locality': locality,
    if (administrativeArea != null) 'administrativeArea': administrativeArea,
    if (countryCode != null) 'countryCode': countryCode,
  };
}
