import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:garipath/config/app_config.dart';

/// The only screen of the app.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const _osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final config = Get.find<AppConfig>();

    return Scaffold(
      body: FlutterMap(
        options: MapOptions(
          initialCenter: config.defaultMapCenter,
          initialZoom: 13,
          // Rotation is disabled so the car's heading always matches the screen.
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: _osmTileUrl,
            // OSM tile policy: identify the app making the requests.
            userAgentPackageName: config.applicationId,
          ),
          // OSM tile policy: attribution must always be visible.
          const SimpleAttributionWidget(
            source: Text('OpenStreetMap contributors'),
          ),
        ],
      ),
    );
  }
}
