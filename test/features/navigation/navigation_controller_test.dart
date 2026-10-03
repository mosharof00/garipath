import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:latlong2/latlong.dart';

import '../../fakes/fake_simulation_clock.dart';

const _speed = 10.0; // 1 m per 100 ms tick at 1x

const _start = LatLng(23.75, 90.40);
const _end = LatLng(23.76, 90.40); // ~1.1 km north

const _routeA = RouteModel(
  points: [_start, _end],
  distanceMeters: 1112,
  durationSeconds: 120,
);
const _routeB = RouteModel(
  points: [_end, LatLng(23.76, 90.41)],
  distanceMeters: 1018,
  durationSeconds: 110,
);

void main() {
  // The controller listens to app lifecycle events through WidgetsBinding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSimulationClock clock;
  late Rxn<RouteModel> route;
  late NavigationController controller;

  setUp(() {
    Get.testMode = true;
    clock = FakeSimulationClock();
    route = Rxn<RouteModel>();
    controller = Get.put(
      NavigationController(route, clock, baseSpeedMps: _speed),
    );
  });

  tearDown(Get.reset);

  test('no route: idle, no frame, start does nothing', () {
    controller.start();

    expect(controller.hasRoute, isFalse);
    expect(controller.frame.value, isNull);
    expect(clock.isRunning, isFalse);
  });

  test('a route arrives: car waits at the start, idle', () {
    route.value = _routeA;

    expect(controller.playback.value, PlaybackState.idle);
    expect(controller.frame.value!.position, _start);
    expect(controller.hud.value, isNotNull);
    expect(clock.isRunning, isFalse);
  });

  test('start runs the clock and moves the car', () {
    route.value = _routeA;

    controller.start();
    clock.tickTimes(10);

    expect(controller.playback.value, PlaybackState.playing);
    expect(clock.isRunning, isTrue);
    expect(controller.frame.value!.distanceMeters, closeTo(10, 1e-9));
  });

  test('pause stops the clock; resume starts it again', () {
    route.value = _routeA;
    controller.start();
    clock.tickTimes(5);

    controller.pause();
    expect(controller.playback.value, PlaybackState.paused);
    expect(clock.isRunning, isFalse);

    controller.resume();
    expect(controller.playback.value, PlaybackState.playing);
    expect(clock.isRunning, isTrue);
    expect(clock.startCount, 2);
  });

  test('reset: back to the start, clock stopped', () {
    route.value = _routeA;
    controller.start();
    clock.tickTimes(5);

    controller.reset();

    expect(controller.playback.value, PlaybackState.idle);
    expect(controller.frame.value!.distanceMeters, 0);
    expect(clock.isRunning, isFalse);
  });

  test('frame updates every tick, HUD at most every 200 ms', () {
    route.value = _routeA;
    controller.start();
    var frameUpdates = 0;
    var hudUpdates = 0;
    final workers = [
      ever(controller.frame, (_) => frameUpdates++),
      ever(controller.hud, (_) => hudUpdates++),
    ];

    clock.tickTimes(60, const Duration(milliseconds: 16)); // ~1 s at 60 fps

    expect(frameUpdates, 60);
    expect(hudUpdates, inInclusiveRange(4, 5));
    for (final worker in workers) {
      worker.dispose();
    }
  });

  test('finishing stops the clock and updates the HUD', () {
    route.value = _routeA;
    controller.start();

    clock.tickTimes(2000);

    expect(controller.playback.value, PlaybackState.finished);
    expect(clock.isRunning, isFalse);
    expect(controller.hud.value!.remainingMeters, 0);
  });

  test('multiplier: 5x moves 5 m per tick and survives a new route', () {
    route.value = _routeA;
    controller.setMultiplier(5);
    controller.start();
    clock.tick();
    expect(controller.frame.value!.distanceMeters, closeTo(5, 1e-9));

    route.value = _routeB;
    controller.start();
    clock.tick();
    expect(controller.frame.value!.distanceMeters, closeTo(5, 1e-9));
  });

  test('a new route resets playback to the new start', () {
    route.value = _routeA;
    controller.start();
    clock.tickTimes(10);

    route.value = _routeB;

    expect(controller.playback.value, PlaybackState.idle);
    expect(controller.frame.value!.position, _routeB.points.first);
    expect(clock.isRunning, isFalse);
  });

  test('route removed: no car, idle', () {
    route.value = _routeA;
    controller.start();

    route.value = null;

    expect(controller.hasRoute, isFalse);
    expect(controller.frame.value, isNull);
    expect(controller.playback.value, PlaybackState.idle);
    expect(clock.isRunning, isFalse);
  });

  group('app lifecycle', () {
    test('background auto-pauses, return resumes without a jump', () {
      route.value = _routeA;
      controller.start();
      clock.tickTimes(10); // 10 m

      controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(controller.playback.value, PlaybackState.paused);
      expect(clock.isRunning, isFalse);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.playback.value, PlaybackState.playing);
      expect(clock.isRunning, isTrue);
      // A real clock's first tick after a restart is 0: nothing skipped.
      clock.tick(Duration.zero);
      expect(controller.frame.value!.distanceMeters, closeTo(10, 1e-9));
    });

    test('inactive (notification shade) keeps playing', () {
      route.value = _routeA;
      controller.start();

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(controller.playback.value, PlaybackState.playing);
      expect(clock.isRunning, isTrue);
    });

    test('a pause the user chose stays paused after returning', () {
      route.value = _routeA;
      controller.start();
      controller.pause();

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(controller.playback.value, PlaybackState.paused);
    });

    test('reset while in the background: no auto-resume later', () {
      route.value = _routeA;
      controller.start();
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);

      controller.reset();
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(controller.playback.value, PlaybackState.idle);
    });
  });

  test('closing the controller disposes the clock', () {
    Get.delete<NavigationController>();

    expect(clock.isDisposed, isTrue);
  });
}
