import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:garipath/config/app_config.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/location/presentation/location_controller.dart';
import 'package:garipath/presentation/widgets/my_location_button.dart';
import 'package:garipath/presentation/widgets/status_card.dart';
import 'package:garipath/presentation/widgets/user_location_layer.dart';
import 'package:latlong2/latlong.dart';

/// The only screen of the app.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _locationZoom = 15.0;

  final _config = Get.find<AppConfig>();
  final _location = Get.find<LocationController>();
  final _mapController = MapController();

  late final Worker _firstFixWorker;
  bool _mapReady = false;
  bool _movedToFirstFix = false;

  @override
  void initState() {
    super.initState();
    // Jump to the user once, when the first location arrives.
    _firstFixWorker = ever(_location.fix, (fix) {
      if (fix != null && !_movedToFirstFix) _showLocation(fix);
    });
  }

  @override
  void dispose() {
    _firstFixWorker.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _showLocation(LocationFix fix) {
    if (!_mapReady) return; // onMapReady will handle it
    _movedToFirstFix = true;
    final zoom = math.max(_mapController.camera.zoom, _locationZoom);
    _mapController.move(LatLng(fix.latitude, fix.longitude), zoom);
  }

  void _onMapReady() {
    _mapReady = true;
    final fix = _location.fix.value;
    if (fix != null && !_movedToFirstFix) _showLocation(fix);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _config.defaultMapCenter,
              initialZoom: 13,
              onMapReady: _onMapReady,
              // Rotation is disabled so the car's heading always matches the screen.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _osmTileUrl,
                // OSM tile policy: identify the app making the requests.
                userAgentPackageName: _config.applicationId,
              ),
              UserAccuracyLayer(controller: _location),
              UserLocationDotLayer(controller: _location),
              // OSM tile policy: attribution must always be visible.
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: StatusCard(controller: _location),
            ),
          ),
          Positioned(
            right: 16,
            // Above the attribution text and the system navigation bar.
            bottom: 40 + MediaQuery.paddingOf(context).bottom,
            child: MyLocationButton(
              controller: _location,
              onShowLocation: _showLocation,
            ),
          ),
        ],
      ),
    );
  }
}
