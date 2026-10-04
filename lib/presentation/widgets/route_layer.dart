import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:garipath/features/routing/presentation/route_controller.dart';

const _routeColor = Color(0xFF1A73E8);
const _routeCasingColor = Color(0xFF0B4FA8);

/// The route line: a darker border ("casing") with the brand colour on top,
/// so it stays visible over any map colour.
class RouteLineLayer extends StatelessWidget {
  const RouteLineLayer({super.key, required this.controller});

  final RouteController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final route = controller.route.value;
      if (route == null) return const SizedBox.shrink();

      return PolylineLayer(
        polylines: [
          Polyline(
            points: route.points,
            strokeWidth: 5,
            color: _routeColor,
            borderStrokeWidth: 2,
            borderColor: _routeCasingColor,
          ),
        ],
      );
    });
  }
}

/// Destination pin, plus the start pin when the user picked one on the map.
class RouteMarkersLayer extends StatelessWidget {
  const RouteMarkersLayer({super.key, required this.controller});

  final RouteController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final destination = controller.destination.value;
      final manualStart = controller.manualStart.value;

      return MarkerLayer(
        // Keep the pins upright when the camera turns the map.
        rotate: true,
        markers: [
          if (manualStart != null)
            Marker(
              point: manualStart,
              width: 36,
              height: 36,
              // The pin's tip sits on the point, not its centre.
              alignment: Alignment.topCenter,
              child: const Icon(
                Icons.location_on,
                color: Colors.green,
                size: 36,
              ),
            ),
          if (destination != null)
            Marker(
              point: destination,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
        ],
      );
    });
  }
}
