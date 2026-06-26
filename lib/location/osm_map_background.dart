import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:genui_template/location/location_snapshot.dart';
import 'package:latlong2/latlong.dart';

class OsmMapBackground extends StatefulWidget {
  const OsmMapBackground({
    required this.location,
    this.onRequestLocation,
    super.key,
  });

  final ValueListenable<LocationSnapshot> location;
  final Future<void> Function()? onRequestLocation;

  @override
  State<OsmMapBackground> createState() => _OsmMapBackgroundState();
}

class _OsmMapBackgroundState extends State<OsmMapBackground> {
  static const _bayAreaCenter = LatLng(37.789, -122.315);

  bool _tileLoadFailed = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationSnapshot>(
      valueListenable: widget.location,
      builder: (context, snapshot, _) {
        final center = _centerFor(snapshot);

        return Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              key: ValueKey(_mapKeyFor(center, snapshot.status)),
              options: MapOptions(
                initialCenter: center,
                initialZoom: snapshot.hasLocation ? 14.2 : 10,
                minZoom: 9,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
                backgroundColor: const Color(0xFFE7EDF0),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.genui_template',
                  errorTileCallback: (_, _, _) => _markTileLoadFailed(),
                ),
                MarkerLayer(markers: _markersFor(snapshot)),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                  backgroundColor: Color(0xCFFFFFFF),
                ),
              ],
            ),
            const _MapScrim(),
            if (_fallbackFor(snapshot) case final fallback?)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 78,
                left: 16,
                right: 16,
                child: fallback,
              ),
          ],
        );
      },
    );
  }

  LatLng _centerFor(LocationSnapshot snapshot) {
    final coordinate = snapshot.fix?.coordinate;
    if (coordinate == null) return _bayAreaCenter;
    return LatLng(coordinate.latitude, coordinate.longitude);
  }

  String _mapKeyFor(LatLng center, LocationSnapshotStatus status) {
    return '${status.name}:'
        '${center.latitude.toStringAsFixed(4)},'
        '${center.longitude.toStringAsFixed(4)}';
  }

  List<Marker> _markersFor(LocationSnapshot snapshot) {
    final fix = snapshot.fix;
    if (fix == null) return const [];

    final markers = <Marker>[
      Marker(
        point: LatLng(fix.coordinate.latitude, fix.coordinate.longitude),
        width: 54,
        height: 54,
        child: const _UserLocationMarker(),
      ),
    ];

    final nearest = snapshot.nearestStop;
    if (nearest != null) {
      final coordinate = nearest.stop.coordinate;
      markers.add(
        Marker(
          point: LatLng(coordinate.latitude, coordinate.longitude),
          width: 44,
          height: 44,
          child: const _TransitStopMarker(),
        ),
      );
    }

    return markers;
  }

  Widget? _fallbackFor(LocationSnapshot snapshot) {
    if (_tileLoadFailed) {
      return const _MapFallbackBanner(
        title: 'Map tiles unavailable',
        message: 'Showing saved location context without map imagery.',
      );
    }

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

  void _markTileLoadFailed() {
    if (!mounted || _tileLoadFailed) return;
    setState(() => _tileLoadFailed = true);
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
                const Icon(Icons.my_location_rounded, size: 20),
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

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0x330091D2),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x660091D2), width: 2),
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF0091D2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransitStopMarker extends StatelessWidget {
  const _TransitStopMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF151A20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33121C26),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.train_rounded,
          size: 15,
          color: Colors.white,
        ),
      ),
    );
  }
}
