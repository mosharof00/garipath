import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/location/presentation/location_controller.dart';

/// Moves the map to the user's location. Without a location yet, it asks
/// for one (this counts as a user tap, so showing the dialog is fine).
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({
    super.key,
    required this.controller,
    required this.onShowLocation,
  });

  final LocationController controller;
  final ValueChanged<LocationFix> onShowLocation;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fix = controller.fix.value;
      return FloatingActionButton.small(
        heroTag: null,
        tooltip: 'My location',
        onPressed: () {
          if (fix != null) {
            onShowLocation(fix);
          } else {
            controller.requestAndLocate();
          }
        },
        child: Icon(fix != null ? Icons.my_location : Icons.location_searching),
      );
    });
  }
}
