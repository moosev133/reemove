class GeoLocation {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    required this.geohash,
    this.locality,
    this.administrativeArea,
    this.countryCode,
  }) : assert(latitude >= -90 && latitude <= 90),
       assert(longitude >= -180 && longitude <= 180),
       assert(geohash.length >= 4);

  final double latitude;
  final double longitude;
  final String geohash;
  final String? locality;
  final String? administrativeArea;
  final String? countryCode;
}
