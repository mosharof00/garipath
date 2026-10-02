import 'package:get/get.dart';
import 'package:garipath/config/app_config.dart';
import 'package:garipath/features/location/data/method_channel_location_service.dart';
import 'package:garipath/features/location/domain/location_service.dart';
import 'package:garipath/features/location/presentation/location_controller.dart';

/// Creates the dependencies for the map screen.
///
/// This is the only place that registers objects with GetX. Controllers get
/// their dependencies through their constructors, so they stay easy to test.
class NavigationBinding extends Bindings {
  NavigationBinding(this.config);

  final AppConfig config;

  @override
  void dependencies() {
    Get.put<AppConfig>(config);
    Get.put<LocationService>(MethodChannelLocationService());
    Get.put(
      LocationController(
        Get.find<LocationService>(),
        locationTimeout: config.locationTimeout,
      ),
    );
  }
}
