import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';
import 'package:garipath/presentation/widgets/car_painter.dart';

/// The car on the map.
///
/// This is the only map layer that rebuilds every frame while the car
/// moves; the tiles and the route line don't.
class CarMarkerLayer extends StatelessWidget {
  const CarMarkerLayer({super.key, required this.controller});

  static const carSize = 40.0;

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final frame = controller.frame.value;
      if (frame == null) return const SizedBox.shrink();

      return MarkerLayer(
        markers: [
          Marker(
            point: frame.position,
            width: carSize,
            height: carSize,
            child: Transform.rotate(
              // Heading is relative to north on the map. The marker turns
              // with the map, so this stays right when the map is rotated.
              // Transform.rotate wants radians.
              angle: frame.headingDegrees * math.pi / 180,
              child: const CustomPaint(painter: CarPainter()),
            ),
          ),
        ],
      );
    });
  }
}
