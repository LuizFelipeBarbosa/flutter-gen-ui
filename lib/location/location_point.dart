import 'dart:math' as math;

class LocationCoordinate {
  const LocationCoordinate({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  double distanceTo(LocationCoordinate other) =>
      distanceMetersBetween(this, other);
}

double distanceMetersBetween(
  LocationCoordinate a,
  LocationCoordinate b,
) {
  const earthRadiusMeters = 6371008.8;
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final dLat = _radians(b.latitude - a.latitude);
  final dLon = _radians(b.longitude - a.longitude);

  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);

  return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

String formatDistanceMeters(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

double _radians(double degrees) => degrees * math.pi / 180;
