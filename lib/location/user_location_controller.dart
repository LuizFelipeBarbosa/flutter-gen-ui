import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:genui_template/location/bay_area_transit_stops.dart';
import 'package:genui_template/location/location_point.dart';
import 'package:genui_template/location/location_snapshot.dart';
import 'package:geolocator/geolocator.dart';

abstract class UserLocationGateway {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<Position?> getLastKnownPosition();

  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  });
}

class GeolocatorUserLocationGateway implements UserLocationGateway {
  const GeolocatorUserLocationGateway();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) {
    return Geolocator.getCurrentPosition(locationSettings: locationSettings);
  }
}

class UserLocationController extends ValueNotifier<LocationSnapshot> {
  UserLocationController({
    this.gateway = const GeolocatorUserLocationGateway(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(LocationSnapshot.idle(capturedAt: (now ?? DateTime.now)()));

  final UserLocationGateway gateway;
  final DateTime Function() _now;
  bool _isDisposed = false;
  bool _requestInFlight = false;

  Future<void> refresh() async {
    if (_requestInFlight) return;

    _requestInFlight = true;
    _setSnapshot(LocationSnapshot.locating(capturedAt: _now()));

    var emittedCachedFix = false;
    try {
      final servicesEnabled = await gateway.isLocationServiceEnabled();
      if (!servicesEnabled) {
        _setSnapshot(LocationSnapshot.serviceDisabled(capturedAt: _now()));
        return;
      }

      final permission = await _resolvePermission();
      if (!_isPermissionGranted(permission)) {
        _setSnapshot(_permissionSnapshot(permission));
        return;
      }

      final cached = await gateway.getLastKnownPosition();
      if (cached != null) {
        emittedCachedFix = true;
        _setSnapshot(_snapshotFromPosition(cached));
      }

      final fresh = await gateway.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _setSnapshot(_snapshotFromPosition(fresh));
    } on TimeoutException {
      if (!emittedCachedFix) {
        _setSnapshot(
          LocationSnapshot.unavailable(
            capturedAt: _now(),
            message: 'Location timed out.',
          ),
        );
      }
    } on Exception catch (error) {
      if (!emittedCachedFix) {
        _setSnapshot(
          LocationSnapshot.unavailable(
            capturedAt: _now(),
            message: error.toString(),
          ),
        );
      }
    } finally {
      _requestInFlight = false;
    }
  }

  Future<LocationPermission> _resolvePermission() async {
    final permission = await gateway.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return gateway.requestPermission();
    }
    return permission;
  }

  bool _isPermissionGranted(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  LocationSnapshot _permissionSnapshot(LocationPermission permission) {
    if (permission == LocationPermission.deniedForever) {
      return LocationSnapshot.permissionDeniedForever(capturedAt: _now());
    }
    return LocationSnapshot.permissionDenied(capturedAt: _now());
  }

  LocationSnapshot _snapshotFromPosition(Position position) {
    final fix = UserLocationFix(
      coordinate: LocationCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp,
      headingDegrees: position.heading,
      speedMetersPerSecond: position.speed,
    );

    return LocationSnapshot.available(
      capturedAt: _now(),
      fix: fix,
      nearestStop: nearestBayAreaTransitStop(fix.coordinate),
    );
  }

  void _setSnapshot(LocationSnapshot snapshot) {
    if (_isDisposed) return;
    value = snapshot;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
