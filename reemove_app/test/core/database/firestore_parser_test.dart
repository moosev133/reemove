import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/database/dto/geo_location_dto.dart';
import 'package:reemove/core/database/dto/media_asset_dto.dart';
import 'package:reemove/core/database/dto/money_dto.dart';
import 'package:reemove/core/domain/value_objects/media_asset.dart';

void main() {
  group('Firestore value-object DTOs', () {
    test('converts GeoPoint data without leaking Firebase into the domain', () {
      final GeoLocationDto dto = GeoLocationDto.fromMap(<String, dynamic>{
        'location': const GeoPoint(32.794, 34.9896),
        'geohash': 'svbcr',
        'locality': 'Haifa',
        'countryCode': 'IL',
      });

      final location = dto.toDomain();

      expect(location.latitude, 32.794);
      expect(location.longitude, 34.9896);
      expect(location.geohash, 'svbcr');
      expect(location.locality, 'Haifa');
    });

    test('round-trips money in minor currency units', () {
      const MoneyDto dto = MoneyDto(amountMinor: 55000, currency: 'ILS');

      expect(dto.toDomain().amountMajor, 550);
      expect(MoneyDto.fromMap(dto.toMap()).amountMinor, 55000);
    });

    test('converts media processing metadata', () {
      final MediaAssetDto dto = MediaAssetDto.fromMap(<String, dynamic>{
        'id': 'asset-1',
        'storagePath': 'posts/user/post/original/asset-1.jpg',
        'kind': 'image',
        'processingState': 'ready',
        'width': 1080,
        'height': 1350,
        'contentType': 'image/jpeg',
        'sizeBytes': 200000,
      });

      final asset = dto.toDomain();

      expect(asset.kind, MediaKind.image);
      expect(asset.processingState, MediaProcessingState.ready);
      expect(asset.width, 1080);
    });
  });
}
