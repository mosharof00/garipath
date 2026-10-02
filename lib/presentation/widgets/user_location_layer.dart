import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:garipath/features/location/presentation/location_controller.dart';
import 'package:latlong2/latlong.dart';

const _dotColor = Color(0xFF1A73E8);

/// The light blue circle showing how accurate the user's location is.
/// Large when only approximate location is allowed.
class UserAccuracyLayer extends StatelessWidget {
  const UserAccuracyLayer({super.key, required this.controller});

  final LocationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fix = controller.fix.value;
      final accuracy = fix?.accuracyMeters;
      if (fix == null || accuracy == null) return const SizedBox.shrink();

      return CircleLayer(
        circles: [
          CircleMarker(
            point: LatLng(fix.latitude, fix.longitude),
            radius: accuracy,
            useRadiusInMeter: true,
            color: _dotColor.withValues(alpha: 0.12),
            borderColor: _dotColor.withValues(alpha: 0.3),
            borderStrokeWidth: 1,
          ),
        ],
      );
    });
  }
}

/// The blue dot at the user's current location.
class UserLocationDotLayer extends StatelessWidget {
  const UserLocationDotLayer({super.key, required this.controller});

  final LocationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fix = controller.fix.value;
      if (fix == null) return const SizedBox.shrink();

      return MarkerLayer(
        markers: [
          Marker(
            point: LatLng(fix.latitude, fix.longitude),
            width: 22,
            height: 22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
