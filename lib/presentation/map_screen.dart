import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:garipath/config/app_config.dart';
import 'package:garipath/features/location/presentation/location_controller.dart';
import 'package:garipath/features/navigation/presentation/map_camera_controller.dart';
import 'package:garipath/features/routing/presentation/route_controller.dart';
import 'package:garipath/presentation/widgets/my_location_button.dart';
import 'package:garipath/presentation/widgets/route_layer.dart';
import 'package:garipath/presentation/widgets/route_summary_card.dart';
import 'package:garipath/presentation/widgets/status_card.dart';
import 'package:garipath/presentation/widgets/user_location_layer.dart';
import 'package:latlong2/latlong.dart';

/// The only screen of the app.
///
/// Layout: the map fills the space above the bottom route panel. Because
/// the panel is below the map (not on top of it), the attribution and the
/// buttons are never hidden by it.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final _config = Get.find<AppConfig>();
  final _location = Get.find<LocationController>();
  final _route = Get.find<RouteController>();
  final _camera = Get.find<MapCameraController>();

  /// Used to measure the top card so a fitted route isn't hidden under it.
  final _statusCardKey = GlobalKey();

  late final List<Worker> _workers;
  bool _movedToFirstFix = false;

  @override
  void initState() {
    super.initState();
    _workers = [
      // Jump to the user once, when the first location arrives.
      ever(_location.fix, (fix) {
        if (fix == null || _movedToFirstFix) return;
        _movedToFirstFix = true;
        _camera.showPoint(LatLng(fix.latitude, fix.longitude));
      }),
      // Show the whole route when it arrives.
      ever(_route.route, (route) {
        if (route != null) _camera.fitRoute(route.points, _fitPadding());
      }),
    ];
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    super.dispose();
  }

  EdgeInsets _fitPadding() {
    final cardHeight = _statusCardKey.currentContext?.size?.height ?? 0;
    final topInset = MediaQuery.paddingOf(context).top;
    return EdgeInsets.fromLTRB(40, topInset + cardHeight + 40, 40, 56);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _camera.mapController,
                  options: MapOptions(
                    initialCenter: _config.defaultMapCenter,
                    initialZoom: 13,
                    onMapReady: _camera.onMapReady,
                    onLongPress: (_, point) => _route.onMapLongPress(point),
                    // Rotation is disabled so the car's heading always
                    // matches the screen.
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
                    RouteLineLayer(controller: _route),
                    UserAccuracyLayer(controller: _location),
                    UserLocationDotLayer(controller: _location),
                    RouteMarkersLayer(controller: _route),
                    // OSM tile policy: attribution must always be visible.
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap contributors'),
                    ),
                  ],
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: StatusCard(
                      key: _statusCardKey,
                      controller: _location,
                      onPickStartOnMap: _route.startPickingStart,
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 40, // above the attribution text
                  child: MyLocationButton(
                    controller: _location,
                    onShowLocation: (fix) =>
                        _camera.showPoint(LatLng(fix.latitude, fix.longitude)),
                  ),
                ),
              ],
            ),
          ),
          RouteSummaryCard(controller: _route),
        ],
      ),
    );
  }
}
