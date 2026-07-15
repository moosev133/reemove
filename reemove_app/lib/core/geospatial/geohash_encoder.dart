abstract final class GeohashEncoder {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode(double latitude, double longitude, {int precision = 9}) {
    assert(latitude >= -90 && latitude <= 90);
    assert(longitude >= -180 && longitude <= 180);
    assert(precision > 0 && precision <= 12);

    final List<double> latitudeRange = <double>[-90, 90];
    final List<double> longitudeRange = <double>[-180, 180];
    final StringBuffer hash = StringBuffer();
    int bits = 0;
    int bitCount = 0;
    bool useLongitude = true;

    while (hash.length < precision) {
      final List<double> range = useLongitude ? longitudeRange : latitudeRange;
      final double value = useLongitude ? longitude : latitude;
      final double midpoint = (range[0] + range[1]) / 2;
      bits <<= 1;
      if (value >= midpoint) {
        bits |= 1;
        range[0] = midpoint;
      } else {
        range[1] = midpoint;
      }
      useLongitude = !useLongitude;
      bitCount += 1;

      if (bitCount == 5) {
        hash.write(_base32[bits]);
        bits = 0;
        bitCount = 0;
      }
    }
    return hash.toString();
  }
}
