import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui_template/location/google_maps_javascript_loader.dart';
import 'package:genui_template/location/location_point.dart';
import 'package:genui_template/location/location_snapshot.dart';
import 'package:genui_template/location/map_place_overlay.dart';
import 'package:genui_template/location/map_route_overlay.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapBackground extends StatefulWidget {
  const GoogleMapBackground({
    required this.location,
    this.onRequestLocation,
    this.routeOverlayListenable,
    this.placeOverlayListenable,
    super.key,
  });

  final ValueListenable<LocationSnapshot> location;
  final Future<void> Function()? onRequestLocation;
  final ValueListenable<MapRouteOverlay?>? routeOverlayListenable;
  final ValueListenable<List<MapPlaceMarker>>? placeOverlayListenable;

  @override
  State<GoogleMapBackground> createState() => _GoogleMapBackgroundState();
}

class _GoogleMapBackgroundState extends State<GoogleMapBackground> {
  static const _bayAreaCenter = LatLng(37.789, -122.315);
  static const _mapPadding = EdgeInsets.fromLTRB(52, 116, 52, 360);
  static const _mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _appPinsOnlyMapStyle = '''
[
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  }
]
''';

  GoogleMapController? _controller;
  Future<String?>? _mapsJavaScriptLoadFuture;
  String? _mapsJavaScriptLoadError;
  CameraPosition? _webCameraPosition;
  _CameraTarget? _pendingCameraTarget;
  String? _lastScheduledCameraSignature;
  String? _lastAppliedCameraSignature;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationSnapshot>(
      valueListenable: widget.location,
      builder: (context, snapshot, _) {
        final routeListenable = widget.routeOverlayListenable;
        if (routeListenable == null) {
          return _buildWithPlaces(snapshot: snapshot);
        }

        return ValueListenableBuilder<MapRouteOverlay?>(
          valueListenable: routeListenable,
          builder: (context, overlay, _) {
            return _buildWithPlaces(snapshot: snapshot, overlay: overlay);
          },
        );
      },
    );
  }

  Widget _buildWithPlaces({
    required LocationSnapshot snapshot,
    MapRouteOverlay? overlay,
  }) {
    final placeListenable = widget.placeOverlayListenable;
    if (placeListenable == null) {
      return _buildMapStack(
        snapshot: snapshot,
        overlay: overlay,
        placeMarkers: const [],
      );
    }

    return ValueListenableBuilder<List<MapPlaceMarker>>(
      valueListenable: placeListenable,
      builder: (context, placeMarkers, _) {
        return _buildMapStack(
          snapshot: snapshot,
          overlay: overlay,
          placeMarkers: placeMarkers,
        );
      },
    );
  }

  Widget _buildMapStack({
    required LocationSnapshot snapshot,
    required List<MapPlaceMarker> placeMarkers,
    MapRouteOverlay? overlay,
  }) {
    final activeOverlay = overlay == null || overlay.isEmpty ? null : overlay;
    final fallback = _blockingFallbackFor(snapshot);
    final cameraTarget = _cameraTargetFor(
      snapshot,
      activeOverlay,
      placeMarkers,
    );
    final mapPins = _mapPinsFor(
      snapshot: snapshot,
      overlay: activeOverlay,
      placeMarkers: placeMarkers,
    );

    if (fallback == null) {
      _scheduleCameraUpdate(cameraTarget);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (fallback == null)
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: cameraTarget.center,
              zoom: cameraTarget.zoom,
            ),
            onMapCreated: _handleMapCreated,
            onCameraMove: _handleCameraMove,
            markers: kIsWeb ? const <Marker>{} : _markersFor(mapPins),
            polylines: _polylinesFor(activeOverlay),
            padding: _mapPadding,
            style: _appPinsOnlyMapStyle,
            minMaxZoomPreference: const MinMaxZoomPreference(9, 18),
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            webGestureHandling: WebGestureHandling.greedy,
            zoomControlsEnabled: false,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          )
        else
          const _MapBackdrop(),
        if (fallback == null && kIsWeb)
          IgnorePointer(
            child: _WebMapPinsOverlay(
              cameraPosition:
                  _webCameraPosition ??
                  CameraPosition(
                    target: cameraTarget.center,
                    zoom: cameraTarget.zoom,
                  ),
              pins: mapPins,
            ),
          ),
        const IgnorePointer(child: _MapScrim()),
        if (fallback ?? _locationFallbackFor(snapshot) case final banner?)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 78,
            left: 16,
            right: 16,
            child: banner,
          ),
      ],
    );
  }

  void _handleMapCreated(GoogleMapController controller) {
    _controller = controller;

    final target = _pendingCameraTarget;
    if (target != null) {
      unawaited(_applyCameraTarget(target));
    }
  }

  void _handleCameraMove(CameraPosition position) {
    if (!kIsWeb || !mounted) return;

    setState(() {
      _webCameraPosition = position;
    });
  }

  void _scheduleCameraUpdate(_CameraTarget target) {
    _pendingCameraTarget = target;
    if (_lastScheduledCameraSignature == target.signature) return;
    _lastScheduledCameraSignature = target.signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingCameraTarget?.signature != target.signature) {
        return;
      }
      unawaited(_applyCameraTarget(target));
    });
  }

  Future<void> _applyCameraTarget(_CameraTarget target) async {
    final controller = _controller;
    if (controller == null || _lastAppliedCameraSignature == target.signature) {
      return;
    }

    _lastAppliedCameraSignature = target.signature;
    final update = target.bounds == null
        ? CameraUpdate.newLatLngZoom(target.center, target.zoom)
        : CameraUpdate.newLatLngBounds(target.bounds!, 52);
    await controller.animateCamera(update);
  }

  _CameraTarget _cameraTargetFor(
    LocationSnapshot snapshot,
    MapRouteOverlay? overlay,
    List<MapPlaceMarker> placeMarkers,
  ) {
    final routePoints = _routePointsFor(overlay);
    if (routePoints.isNotEmpty) {
      return _CameraTarget.fromPoints(
        points: routePoints,
        fallbackZoom: 10.8,
        signature: 'route:${overlay?.id}:${_pointsSignature(routePoints)}',
      );
    }

    final searchResultPoints = [
      for (final marker in placeMarkers)
        if (marker.kind == MapPlaceMarkerKind.searchResult)
          _latLngFor(marker.coordinate),
    ];
    if (searchResultPoints.isNotEmpty) {
      return _CameraTarget.fromPoints(
        points: searchResultPoints,
        fallbackZoom: 14,
        signature: 'places:${_pointsSignature(searchResultPoints)}',
      );
    }

    final coordinate = snapshot.fix?.coordinate;
    if (coordinate == null) {
      return const _CameraTarget(
        center: _bayAreaCenter,
        zoom: 10,
        signature: 'bay-area',
      );
    }

    final center = _latLngFor(coordinate);
    return _CameraTarget(
      center: center,
      zoom: 14.2,
      signature:
          'location:${center.latitude.toStringAsFixed(4)},'
          '${center.longitude.toStringAsFixed(4)}',
    );
  }

  List<_MapPin> _mapPinsFor({
    required LocationSnapshot snapshot,
    required List<MapPlaceMarker> placeMarkers,
    MapRouteOverlay? overlay,
  }) {
    return [
      ..._locationPinsFor(snapshot),
      if (overlay != null) ..._routePinsFor(overlay),
      ..._placePinsFor(placeMarkers),
    ];
  }

  List<_MapPin> _locationPinsFor(LocationSnapshot snapshot) {
    final fix = snapshot.fix;
    if (fix == null) return const [];

    final pins = <_MapPin>[
      _MapPin(
        id: 'user-location',
        position: _latLngFor(fix.coordinate),
        title: 'Current location',
        hue: BitmapDescriptor.hueAzure,
        color: const Color(0xFF1A73E8),
        zIndexInt: 4,
      ),
    ];

    final nearest = snapshot.nearestStop;
    if (nearest != null) {
      pins.add(
        _MapPin(
          id: 'nearest-stop-${nearest.stop.id}',
          position: _latLngFor(nearest.stop.coordinate),
          title: nearest.stop.name,
          subtitle: '${nearest.stop.modeLabel} · ${nearest.distanceLabel}',
          hue: BitmapDescriptor.hueViolet,
          color: const Color(0xFF7E57C2),
          glyph: 'T',
          zIndexInt: 3,
        ),
      );
    }

    return pins;
  }

  List<_MapPin> _routePinsFor(MapRouteOverlay overlay) {
    return [
      for (var index = 0; index < overlay.markers.length; index++)
        _MapPin(
          id: 'route-${overlay.id}-$index',
          position: _latLngFor(overlay.markers[index].coordinate),
          title: overlay.markers[index].label,
          hue: _routeMarkerHueFor(overlay.markers[index].kind),
          color: _routeMarkerColorFor(overlay.markers[index].kind),
          glyph: _routeMarkerGlyphFor(overlay.markers[index].kind),
          zIndexInt: 5,
        ),
    ];
  }

  List<_MapPin> _placePinsFor(List<MapPlaceMarker> markers) {
    return [
      for (final marker in markers)
        _MapPin(
          id: 'place-${marker.kind.name}-${marker.id}',
          position: _latLngFor(marker.coordinate),
          title: marker.sequence == null
              ? marker.label
              : '${marker.sequence}. ${marker.label}',
          subtitle: marker.subtitle,
          hue: marker.kind == MapPlaceMarkerKind.savedItinerary
              ? BitmapDescriptor.hueRose
              : BitmapDescriptor.hueGreen,
          color: marker.kind == MapPlaceMarkerKind.savedItinerary
              ? const Color(0xFFDB4477)
              : const Color(0xFF188038),
          glyph: marker.sequence?.toString() ?? 'P',
          zIndexInt: marker.kind == MapPlaceMarkerKind.savedItinerary ? 2 : 6,
        ),
    ];
  }

  Set<Marker> _markersFor(List<_MapPin> pins) {
    return {
      for (final pin in pins) _marker(pin),
    };
  }

  Marker _marker(_MapPin pin) {
    return Marker(
      markerId: MarkerId(pin.id),
      position: pin.position,
      infoWindow: InfoWindow(title: pin.title, snippet: pin.subtitle),
      icon: BitmapDescriptor.defaultMarkerWithHue(pin.hue),
      zIndexInt: pin.zIndexInt,
    );
  }

  Set<Polyline> _polylinesFor(MapRouteOverlay? overlay) {
    if (overlay == null) return const {};

    final polylines = <Polyline>{};
    for (var index = 0; index < overlay.segments.length; index++) {
      final segment = overlay.segments[index];
      if (segment.points.length < 2) continue;

      final points = [
        for (final point in segment.points) _latLngFor(point),
      ];
      final patterns = segment.dashed
          ? [PatternItem.dash(20), PatternItem.gap(14)]
          : const <PatternItem>[];

      polylines
        ..add(
          Polyline(
            polylineId: PolylineId('route-${overlay.id}-$index-halo'),
            points: points,
            color: const Color(0xEFFFFFFF),
            width: segment.dashed ? 8 : 9,
            patterns: patterns,
            zIndex: 1,
          ),
        )
        ..add(
          Polyline(
            polylineId: PolylineId('route-${overlay.id}-$index'),
            points: points,
            color: segment.color,
            width: segment.dashed ? 4 : 5,
            patterns: patterns,
            zIndex: 2,
          ),
        );
    }

    return polylines;
  }

  List<LatLng> _routePointsFor(MapRouteOverlay? overlay) {
    if (overlay == null) return const [];
    return [
      for (final coordinate in overlay.coordinates) _latLngFor(coordinate),
    ];
  }

  Widget? _blockingFallbackFor(LocationSnapshot snapshot) {
    if (!_isSupportedPlatform) {
      return const _MapFallbackBanner(
        title: 'Google Maps unsupported',
        message:
            'Interactive Google Maps are available on Android, iOS, and web.',
      );
    }

    if (_mapsApiKey.trim().isEmpty) {
      return const _MapFallbackBanner(
        title: 'Google Maps API key missing',
        message:
            'Add GOOGLE_MAPS_API_KEY to your local run config to enable '
            'the map.',
      );
    }

    if (googleMapsJavaScriptSdkRequired) {
      if (_mapsJavaScriptLoadError case final error?) {
        return _MapFallbackBanner(
          title: 'Google Maps unavailable',
          message: error,
        );
      }

      if (!isGoogleMapsJavaScriptSdkReady) {
        _startMapsJavaScriptLoad();
        return const _MapFallbackBanner(
          title: 'Loading Google Maps',
          message: 'Preparing the interactive map.',
          isBusy: true,
        );
      }
    }

    if (_isWidgetTest) {
      return const _MapFallbackBanner(
        title: 'Google Maps disabled in tests',
        message: 'Map markers are still available through the overlay state.',
      );
    }

    return null;
  }

  void _startMapsJavaScriptLoad() {
    if (_mapsJavaScriptLoadFuture != null || _isWidgetTest) return;

    _mapsJavaScriptLoadFuture = ensureGoogleMapsJavaScriptSdkLoaded(
      apiKey: _mapsApiKey,
    );
    unawaited(
      _mapsJavaScriptLoadFuture!.then((error) {
        if (!mounted) return;
        setState(() {
          _mapsJavaScriptLoadError = error;
        });
      }),
    );
  }

  Widget? _locationFallbackFor(LocationSnapshot snapshot) {
    switch (snapshot.status) {
      case LocationSnapshotStatus.idle:
        return _MapFallbackBanner(
          title: 'Location not shared',
          message: 'Use current location to find nearby Bay Area transit.',
          onPressed: widget.onRequestLocation,
        );
      case LocationSnapshotStatus.locating:
        return const _MapFallbackBanner(
          title: 'Locating',
          message: 'Finding the nearest transit stop.',
          isBusy: true,
        );
      case LocationSnapshotStatus.available:
        return null;
      case LocationSnapshotStatus.serviceDisabled:
        return const _MapFallbackBanner(
          title: 'Location services are off',
          message: 'Turn on location services or search by station name.',
        );
      case LocationSnapshotStatus.permissionDenied:
      case LocationSnapshotStatus.permissionDeniedForever:
        return const _MapFallbackBanner(
          title: 'Location permission denied',
          message: 'Search by station name or update location permissions.',
        );
      case LocationSnapshotStatus.unavailable:
        return _MapFallbackBanner(
          title: 'Location unavailable',
          message: snapshot.message ?? 'Search by station name instead.',
          onPressed: widget.onRequestLocation,
        );
    }
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => false,
    };
  }

  bool get _isWidgetTest {
    var isWidgetTest = false;
    assert(
      () {
        isWidgetTest = WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );
        return true;
      }(),
      'Widget tests should use the static map fallback.',
    );
    return isWidgetTest;
  }
}

class _CameraTarget {
  const _CameraTarget({
    required this.center,
    required this.zoom,
    required this.signature,
    this.bounds,
  });

  factory _CameraTarget.fromPoints({
    required List<LatLng> points,
    required double fallbackZoom,
    required String signature,
  }) {
    if (points.length == 1) {
      return _CameraTarget(
        center: points.single,
        zoom: fallbackZoom,
        signature: signature,
      );
    }

    return _CameraTarget(
      center: _centerFor(points),
      zoom: fallbackZoom,
      signature: signature,
      bounds: _boundsFor(points),
    );
  }

  final LatLng center;
  final double zoom;
  final String signature;
  final LatLngBounds? bounds;
}

class _MapPin {
  const _MapPin({
    required this.id,
    required this.position,
    required this.title,
    required this.hue,
    required this.color,
    required this.zIndexInt,
    this.subtitle,
    this.glyph = '',
  });

  final String id;
  final LatLng position;
  final String title;
  final String? subtitle;
  final double hue;
  final Color color;
  final String glyph;
  final int zIndexInt;
}

class _WebMapPinsOverlay extends StatelessWidget {
  const _WebMapPinsOverlay({
    required this.cameraPosition,
    required this.pins,
  });

  final CameraPosition cameraPosition;
  final List<_MapPin> pins;

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) return const SizedBox.expand();

    final sortedPins = [...pins]
      ..sort((a, b) => a.zIndexInt.compareTo(b.zIndexInt));

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final pin in sortedPins)
              if (_screenOffsetFor(pin.position, cameraPosition, size)
                  case final offset?)
                Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -1),
                    child: _WebMapPin(pin: pin),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _WebMapPin extends StatelessWidget {
  const _WebMapPin({required this.pin});

  final _MapPin pin;

  @override
  Widget build(BuildContext context) {
    final glyph = pin.glyph.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: pin.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x45121C26),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox.square(
            dimension: 28,
            child: Center(
              child: glyph.isEmpty
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 8),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          glyph,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pin.color,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33121C26),
                    blurRadius: 6,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
              child: const SizedBox.square(dimension: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFE7EDF0),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _MapScrim extends StatelessWidget {
  const _MapScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x55FFFFFF),
            Color(0x11FFFFFF),
            Color(0x66FFFFFF),
          ],
          stops: [0, 0.48, 1],
        ),
      ),
    );
  }
}

class _MapFallbackBanner extends StatelessWidget {
  const _MapFallbackBanner({
    required this.title,
    required this.message,
    this.onPressed,
    this.isBusy = false,
  });

  final String title;
  final String message;
  final Future<void> Function()? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final action = onPressed;

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEAFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26121C26),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              if (isBusy)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                const Icon(Icons.map_rounded, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF151A20),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: Color(0xFF5E6872),
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => action().ignore(),
                  child: const Text('Use'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

LatLng _latLngFor(LocationCoordinate coordinate) {
  return LatLng(coordinate.latitude, coordinate.longitude);
}

Offset? _screenOffsetFor(
  LatLng position,
  CameraPosition cameraPosition,
  Size viewportSize,
) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) return null;

  final point = _worldPixelFor(position, cameraPosition.zoom);
  final center = _worldPixelFor(cameraPosition.target, cameraPosition.zoom);
  final offset = Offset(
    point.dx - center.dx + viewportSize.width / 2,
    point.dy - center.dy + viewportSize.height / 2,
  );

  const pinMargin = 64.0;
  if (offset.dx < -pinMargin ||
      offset.dx > viewportSize.width + pinMargin ||
      offset.dy < -pinMargin ||
      offset.dy > viewportSize.height + pinMargin) {
    return null;
  }

  return offset;
}

Offset _worldPixelFor(LatLng position, double zoom) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final sineLatitude = math.sin(position.latitude * math.pi / 180);
  final clampedSine = math.max(math.min(sineLatitude, 0.9999), -0.9999);

  return Offset(
    (position.longitude + 180) / 360 * scale,
    (0.5 - math.log((1 + clampedSine) / (1 - clampedSine)) / (4 * math.pi)) *
        scale,
  );
}

LatLng _centerFor(List<LatLng> points) {
  final bounds = _boundsFor(points);
  return LatLng(
    (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
    (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
  );
}

LatLngBounds _boundsFor(List<LatLng> points) {
  final latitudes = points.map((point) => point.latitude);
  final longitudes = points.map((point) => point.longitude);
  return LatLngBounds(
    southwest: LatLng(
      latitudes.reduce(math.min),
      longitudes.reduce(math.min),
    ),
    northeast: LatLng(
      latitudes.reduce(math.max),
      longitudes.reduce(math.max),
    ),
  );
}

String _pointsSignature(List<LatLng> points) {
  final latitudes = points.map((point) => point.latitude);
  final longitudes = points.map((point) => point.longitude);
  return [
    points.length,
    latitudes.reduce(math.min).toStringAsFixed(4),
    latitudes.reduce(math.max).toStringAsFixed(4),
    longitudes.reduce(math.min).toStringAsFixed(4),
    longitudes.reduce(math.max).toStringAsFixed(4),
  ].join(',');
}

double _routeMarkerHueFor(MapRouteMarkerKind kind) {
  return switch (kind) {
    MapRouteMarkerKind.origin => BitmapDescriptor.hueAzure,
    MapRouteMarkerKind.transfer => BitmapDescriptor.hueOrange,
    MapRouteMarkerKind.destination => BitmapDescriptor.hueRed,
    MapRouteMarkerKind.stop => BitmapDescriptor.hueViolet,
  };
}

Color _routeMarkerColorFor(MapRouteMarkerKind kind) {
  return switch (kind) {
    MapRouteMarkerKind.origin => const Color(0xFF1A73E8),
    MapRouteMarkerKind.transfer => const Color(0xFFF9AB00),
    MapRouteMarkerKind.destination => const Color(0xFFDB4437),
    MapRouteMarkerKind.stop => const Color(0xFF7E57C2),
  };
}

String _routeMarkerGlyphFor(MapRouteMarkerKind kind) {
  return switch (kind) {
    MapRouteMarkerKind.origin => 'A',
    MapRouteMarkerKind.transfer => 'X',
    MapRouteMarkerKind.destination => 'B',
    MapRouteMarkerKind.stop => 'S',
  };
}
