import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:latlong2/latlong.dart';

import '../../fakes/fake_simulation_clock.dart';

// About 1.1 km due north. At this latitude 0.001° of longitude is ~100 m.
const _start = LatLng(23.75, 90.40);
const _end = LatLng(23.76, 90.40);

const _route = RouteModel(
  points: [_start, _end],
  distanceMeters: 1112,
  durationSeconds: 120,
);
const _newRoute = RouteModel(
  points: [LatLng(23.755, 90.401), _end],
  distanceMeters: 560,
  durationSeconds: 60,
);

LocationFix _fix(double lat, double lng) => LocationFix(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 10, 3),
  accuracyMeters: 10,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSimulationClock clock;
  late Rxn<RouteModel> route;
  late Rxn<LocationFix> location;
  late NavigationController controller;
  late int reroutes;

  setUp(() {
    Get.testMode = true;
    clock = FakeSimulationClock();
    route = Rxn<RouteModel>(_route);
    location = Rxn<LocationFix>();
    reroutes = 0;
    controller = Get.put(
      NavigationController(
        route,
        clock,
        baseSpeedMps: 10,
        locationFix: location,
        onRerouteNeeded: () => reroutes++,
      ),
    );
  });

  tearDown(Get.reset);

  test('Live is not allowed without a device location', () {
    controller.setMode(DriveMode.live);

    expect(controller.canUseLive, isFalse);
    expect(controller.mode.value, DriveMode.simulated);
  });

  test('live: the car follows the GPS fixes, not the simulation', () {
    location.value = _fix(23.752, 90.40);
    controller.setMode(DriveMode.live);
    controller.start();
    clock.tickTimes(5);

    expect(controller.playback.value, PlaybackState.playing);
    expect(controller.frame.value!.position.latitude, closeTo(23.752, 1e-6));

    location.value = _fix(23.754, 90.40);
    clock.tickTimes(200); // let the glide finish

    expect(controller.frame.value!.position.latitude, closeTo(23.754, 1e-5));
  });

  test('switching mode stops the trip', () {
    location.value = _fix(23.752, 90.40);
    controller.setMode(DriveMode.live);
    controller.start();

    controller.setMode(DriveMode.simulated);

    expect(controller.playback.value, PlaybackState.idle);
    expect(clock.isRunning, isFalse);
  });

  test('leaving the route asks for one reroute, then continues live', () {
    location.value = _fix(23.752, 90.40);
    controller.setMode(DriveMode.live);
    controller.start();

    // Three accurate fixes ~100 m east of the route.
    location.value = _fix(23.753, 90.401);
    location.value = _fix(23.754, 90.401);
    expect(reroutes, 0);
    location.value = _fix(23.755, 90.401);
    expect(reroutes, 1);

    // The routing controller answers with a new route from here.
    route.value = _newRoute;

    expect(controller.mode.value, DriveMode.live);
    expect(controller.playback.value, PlaybackState.playing);
    clock.tickTimes(5);
    expect(controller.frame.value!.position.longitude, closeTo(90.401, 1e-6));
  });

  test('paused live trip ignores fixes and never reroutes', () {
    location.value = _fix(23.752, 90.40);
    controller.setMode(DriveMode.live);
    controller.start();
    controller.pause();

    location.value = _fix(23.753, 90.401);
    location.value = _fix(23.754, 90.401);
    location.value = _fix(23.755, 90.401);

    expect(reroutes, 0);
  });

  test('reaching the destination finishes the live trip', () {
    location.value = _fix(23.752, 90.40);
    controller.setMode(DriveMode.live);
    controller.start();

    location.value = _fix(23.7599, 90.40);
    clock.tickTimes(2);

    expect(controller.playback.value, PlaybackState.finished);
    expect(clock.isRunning, isFalse);
  });
}
