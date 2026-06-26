import 'package:genui_template/location/bay_area_transit_stops.dart';
import 'package:genui_template/location/location_point.dart';

enum LocationSnapshotStatus {
  idle,
  locating,
  available,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class UserLocationFix {
  const UserLocationFix({
    required this.coordinate,
    required this.accuracyMeters,
    required this.timestamp,
    this.headingDegrees,
    this.speedMetersPerSecond,
  });

  final LocationCoordinate coordinate;
  final double accuracyMeters;
  final DateTime timestamp;
  final double? headingDegrees;
  final double? speedMetersPerSecond;
}

class LocationSnapshot {
  const LocationSnapshot({
    required this.status,
    required this.capturedAt,
    this.fix,
    this.nearestStop,
    this.message,
  });

  factory LocationSnapshot.idle({required DateTime capturedAt}) {
    return LocationSnapshot(
      status: LocationSnapshotStatus.idle,
      capturedAt: capturedAt,
    );
  }

  factory LocationSnapshot.locating({required DateTime capturedAt}) {
    return LocationSnapshot(
      status: LocationSnapshotStatus.locating,
      capturedAt: capturedAt,
    );
  }

  factory LocationSnapshot.available({
    required DateTime capturedAt,
    required UserLocationFix fix,
    required NearestTransitStop? nearestStop,
  }) {
    return LocationSnapshot(
      status: LocationSnapshotStatus.available,
      capturedAt: capturedAt,
      fix: fix,
      nearestStop: nearestStop,
    );
  }

  factory LocationSnapshot.serviceDisabled({required DateTime capturedAt}) {
    return LocationSnapshot(
      status: LocationSnapshotStatus.serviceDisabled,
      capturedAt: capturedAt,
      message: 'Location services are off.',
    );
  }

  factory LocationSnapshot.permissionDenied({required DateTime capturedAt}) {
    return LocationSnapshot(
      status: LocationSnapshotStatus.permissionDenied,
      capturedAt: capturedAt,
      message: 'Location permission was denied.',
    );
  }

  factory LocationSnapshot.permissionDeniedForever({
    required DateTime capturedAt,
  }) {
    return LocationSnapshot(
      status: LocationSnapshotStatus.permissionDeniedForever,
      capturedAt: capturedAt,
      message: 'Location permission was permanently denied.',
    );
  }

  factory LocationSnapshot.unavailable({
    required DateTime capturedAt,
    required String message,
  }) {
    return LocationSnapshot(
      status: LocationSnapshotStatus.unavailable,
      capturedAt: capturedAt,
      message: message,
    );
  }

  final LocationSnapshotStatus status;
  final DateTime capturedAt;
  final UserLocationFix? fix;
  final NearestTransitStop? nearestStop;
  final String? message;

  bool get hasLocation =>
      status == LocationSnapshotStatus.available && fix != null;

  String? get promptContext {
    switch (status) {
      case LocationSnapshotStatus.idle:
        return null;
      case LocationSnapshotStatus.locating:
        return 'User location snapshot: locating is in progress.';
      case LocationSnapshotStatus.available:
        return _availablePromptContext();
      case LocationSnapshotStatus.serviceDisabled:
      case LocationSnapshotStatus.permissionDenied:
      case LocationSnapshotStatus.permissionDeniedForever:
      case LocationSnapshotStatus.unavailable:
        return 'User location snapshot: unavailable '
            "(${message ?? 'unknown'}). Do not infer the user's current "
            'station or neighborhood.';
    }
  }

  String _availablePromptContext() {
    final fix = this.fix;
    if (fix == null) {
      return 'User location snapshot: unavailable (missing coordinates).';
    }

    final nearest = nearestStop;
    final accuracy = fix.accuracyMeters.round();
    final coordinate = fix.coordinate;
    final coordinateText =
        '${coordinate.latitude.toStringAsFixed(5)}, '
        '${coordinate.longitude.toStringAsFixed(5)}';

    if (nearest == null) {
      return 'User location snapshot: coordinates $coordinateText, '
          'accuracy about $accuracy m, no nearby transit stop matched.';
    }

    final stop = nearest.stop;
    final stopCode = stop.stopCode;
    final bartAbbr = stop.bartAbbr;
    final codeText = stopCode == null ? '' : ', stop code $stopCode';
    final bartText = bartAbbr == null ? '' : ', BART abbreviation $bartAbbr';

    return 'User location snapshot: nearest stop ${stop.promptLabel}, '
        '${nearest.distanceLabel} away, coordinates $coordinateText, '
        'accuracy about $accuracy m$bartText$codeText.';
  }
}
