import 'package:flutter_test/flutter_test.dart';
import 'package:reemove/core/geospatial/geohash_encoder.dart';

void main() {
  group('GeohashEncoder', () {
    test('encodes a stable Haifa coordinate', () {
      expect(GeohashEncoder.encode(32.7940, 34.9896, precision: 6), 'svbfs1');
    });

    test('honors requested precision', () {
      expect(GeohashEncoder.encode(0, 0, precision: 4), hasLength(4));
      expect(GeohashEncoder.encode(0, 0, precision: 9), hasLength(9));
    });
  });
}
