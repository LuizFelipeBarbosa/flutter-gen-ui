import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui_template/explore/explore_handoff_controller.dart';
import 'package:genui_template/explore/explore_page.dart';
import 'package:genui_template/home_page.dart';
import 'package:genui_template/location/location.dart';
import 'package:genui_template/transit/bayhop_tokens.dart';

class BayHopShellPage extends StatefulWidget {
  const BayHopShellPage({super.key});

  @override
  State<BayHopShellPage> createState() => _BayHopShellPageState();
}

class _BayHopShellPageState extends State<BayHopShellPage> {
  late final UserLocationController _locationController =
      UserLocationController();
  late final ExploreHandoffController _exploreHandoffController =
      ExploreHandoffController();
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_locationController.refresh());
  }

  @override
  void dispose() {
    _exploreHandoffController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _openExplore(String query) {
    setState(() => _selectedIndex = 1);
    _exploreHandoffController.open(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            locationController: _locationController,
            onOpenExplore: _openExplore,
          ),
          ExplorePage(
            locationListenable: _locationController,
            handoffController: _exploreHandoffController,
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
    );
  }
}
