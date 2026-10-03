import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:garipath/features/navigation/presentation/map_camera_controller.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';

/// Shown after the user moves the map away from the moving car. Tapping it
/// brings the camera back and follows the car again.
class RecenterButton extends StatelessWidget {
  const RecenterButton({
    super.key,
    required this.camera,
    required this.navigation,
  });

  final MapCameraController camera;
  final NavigationController navigation;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = navigation.playback.value;
      final animating =
          state == PlaybackState.playing || state == PlaybackState.paused;
      final frame = navigation.frame.value;
      if (!animating || camera.following.value || frame == null) {
        return const SizedBox.shrink();
      }

      return FloatingActionButton.small(
        heroTag: null,
        tooltip: 'Follow the car',
        onPressed: () => camera.recenter(frame.position),
        child: const Icon(Icons.navigation),
      );
    });
  }
}
