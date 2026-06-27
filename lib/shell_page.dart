import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui_template/explore/explore_handoff_controller.dart';
import 'package:genui_template/explore/explore_page.dart';
import 'package:genui_template/explore/itinerary.dart';
import 'package:genui_template/explore/itinerary_store.dart';
import 'package:genui_template/explore/transit_route_handoff_controller.dart';
import 'package:genui_template/home_page.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/transit/bayhop_tokens.dart';

class BayHopShellPage extends StatefulWidget {
  const BayHopShellPage({
    super.key,
    this.itineraryStore,
    this.placeOverlayController,
  });

  final ItineraryStore? itineraryStore;
  final MapPlaceOverlayController? placeOverlayController;

  @override
  State<BayHopShellPage> createState() => _BayHopShellPageState();
}

class _BayHopShellPageState extends State<BayHopShellPage> {
  late final UserLocationController _locationController =
      UserLocationController();
  late final ExploreHandoffController _exploreHandoffController =
      ExploreHandoffController();
  late final TransitRouteHandoffController _transitRouteHandoffController =
      TransitRouteHandoffController();
  late final ItineraryController _itineraryController = ItineraryController();
  late final MapPlaceOverlayController _placeOverlayController =
      widget.placeOverlayController ?? MapPlaceOverlayController();
  late final ItineraryStore _itineraryStore =
      widget.itineraryStore ?? ItineraryStore();
  late final bool _ownsPlaceOverlayController =
      widget.placeOverlayController == null;
  bool _isLoadingItinerary = true;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_locationController.refresh());
    _itineraryController
      ..addListener(_persistItinerary)
      ..addListener(_syncSavedItineraryMarkers);
    unawaited(_loadItinerary());
  }

  @override
  void dispose() {
    _itineraryController
      ..removeListener(_persistItinerary)
      ..removeListener(_syncSavedItineraryMarkers)
      ..dispose();
    if (_ownsPlaceOverlayController) _placeOverlayController.dispose();
    _transitRouteHandoffController.dispose();
    _exploreHandoffController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadItinerary() async {
    try {
      final stops = await _itineraryStore.load();
      if (!mounted) return;

      _itineraryController.replaceAll(stops);
    } on Object catch (error, stackTrace) {
      debugPrint('Failed to load itinerary: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isLoadingItinerary = false);
      }
    }
  }

  void _persistItinerary() {
    if (_isLoadingItinerary) return;
    unawaited(
      _itineraryStore.save(_itineraryController.value).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Failed to save itinerary: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }

  void _syncSavedItineraryMarkers() {
    final markers = <MapPlaceMarker>[];
    final stops = _itineraryController.value;
    for (var index = 0; index < stops.length; index++) {
      final stop = stops[index];
      final latitude = stop.latitude;
      final longitude = stop.longitude;
      if (latitude == null || longitude == null) continue;
      if (!latitude.isFinite || !longitude.isFinite) continue;

      markers.add(
        MapPlaceMarker(
          id: stop.localId,
          label: stop.title,
          subtitle: stop.category ?? stop.address,
          coordinate: LocationCoordinate(
            latitude: latitude,
            longitude: longitude,
          ),
          kind: MapPlaceMarkerKind.savedItinerary,
          sequence: index + 1,
          googleMapsUri: stop.googleMapsUri,
        ),
      );
    }

    _placeOverlayController.showSavedItineraryMarkers(markers);
  }

  void _openExplore(String query) {
    setState(() => _selectedIndex = 1);
    _exploreHandoffController.open(query);
  }

  void _routeItineraryInTransit() {
    if (_itineraryController.value.isEmpty) return;
    setState(() => _selectedIndex = 0);
    _transitRouteHandoffController.routeItinerary(_itineraryController.value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingItinerary) {
      return const Scaffold(
        backgroundColor: BayHopColors.bgTop,
        body: Center(
          child: CircularProgressIndicator(
            key: ValueKey('itinerary-loading-indicator'),
          ),
        ),
      );
    }

    return MapPlaceOverlayScope(
      controller: _placeOverlayController,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            HomePage(
              locationController: _locationController,
              itineraryController: _itineraryController,
              routeHandoffController: _transitRouteHandoffController,
              onOpenExplore: _openExplore,
            ),
            ExplorePage(
              itineraryController: _itineraryController,
              locationListenable: _locationController,
              handoffController: _exploreHandoffController,
              onRouteInTransit: _routeItineraryInTransit,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          backgroundColor: BayHopColors.surface,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.train_rounded),
              selectedIcon: Icon(Icons.train_rounded),
              label: 'Transit',
            ),
            NavigationDestination(
              icon: Icon(Icons.travel_explore_rounded),
              selectedIcon: Icon(Icons.travel_explore_rounded),
              label: 'Explore',
            ),
          ],
        ),
      ),
    );
  }
}
