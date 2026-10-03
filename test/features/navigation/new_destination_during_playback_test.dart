import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';
import 'package:garipath/features/routing/presentation/route_controller.dart';
import 'package:latlong2/latlong.dart';

import '../../fakes/fake_route_repository.dart';
import '../../fakes/fake_simulation_clock.dart';

const _home = LatLng(23.7625, 90.4368);
const _placeA = LatLng(23.7500, 90.4250);
const _placeB = LatLng(23.7806, 90.4070);

/// Both real controllers together: a long-press during playback must stop
/// the car and set up the new route (PLAN T31, device test T-17).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('new destination while driving: stop, new route, idle at start', () {
    fakeAsync((async) {
      final startTime = DateTime(2026, 10, 3, 12);
      final repository = FakeRouteRepository();
      final fix = Rxn<LocationFix>(
        LocationFix(
          latitude: _home.latitude,
          longitude: _home.longitude,
          timestamp: startTime,
        ),
      );
      final routes = Get.put(
        RouteController(
          repository,
          fix,
          now: () => startTime.add(async.elapsed),
        ),
      );
      final clock = FakeSimulationClock();
      final navigation = Get.put(
        NavigationController(routes.route, clock, baseSpeedMps: 10),
      );

      // First trip, driving.
      routes.onMapLongPress(_placeA);
      async.elapse(const Duration(milliseconds: 500));
      repository.last.succeed(fakeRoute(_home, _placeA));
      async.flushMicrotasks();
      navigation.start();
      clock.tickTimes(20);
      expect(navigation.playback.value, PlaybackState.playing);

      // New destination: once the new request starts, the car stops.
      routes.onMapLongPress(_placeB);
      async.elapse(const Duration(seconds: 2)); // debounce + rate-limit gate
      expect(navigation.playback.value, PlaybackState.idle);
      expect(navigation.frame.value, isNull);
      expect(clock.isRunning, isFalse);

      // The new route arrives: the car waits at its start, ready to go.
      repository.last.succeed(fakeRoute(_home, _placeB));
      async.flushMicrotasks();
      expect(routes.status.value, RouteStatus.ready);
      expect(navigation.playback.value, PlaybackState.idle);
      expect(navigation.frame.value!.position, _home);
      expect(navigation.frame.value!.distanceMeters, 0);
    });
  });
}
