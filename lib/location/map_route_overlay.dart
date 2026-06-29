import 'package:bayhop/location/location_point.dart';
import 'package:flutter/material.dart';

enum MapRouteMarkerKind { origin, transfer, destination, stop }

class MapRouteOverlay {
  const MapRouteOverlay({
    required this.id,
    required this.segments,
    required this.markers,
  });

  final String id;
  final List<MapRouteSegment> segments;
  final List<MapRouteMarker> markers;

  bool get isEmpty => segments.isEmpty && markers.isEmpty;

  List<LocationCoordinate> get coordinates {
    final points = <LocationCoordinate>[];
    for (final segment in segments) {
      points.addAll(segment.points);
    }
    for (final marker in markers) {
      points.add(marker.coordinate);
    }
    return points;
  }
}

class MapRouteSegment {
  const MapRouteSegment({
    required this.points,
    required this.color,
    this.label,
    this.dashed = false,
  });

  final List<LocationCoordinate> points;
  final Color color;
  final String? label;
  final bool dashed;
}

class MapRouteMarker {
  const MapRouteMarker({
    required this.coordinate,
    required this.label,
    required this.kind,
    required this.color,
  });

  final LocationCoordinate coordinate;
  final String label;
  final MapRouteMarkerKind kind;
  final Color color;
}
