import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';
import 'package:garipath/features/routing/presentation/route_controller.dart';
import 'package:latlong2/latlong.dart';

import '../../fakes/fake_route_repository.dart';

const _home = LatLng(23.7625, 90.4368);
const _placeA = LatLng(23.7500, 90.4250);
const _placeB = LatLng(23.7806, 90.4070);
const _placeC = LatLng(23.7700, 90.4000);

const _debounce = Duration(milliseconds: 500);

void main() {
  final startTime = DateTime(2026, 10, 3, 12);

  late FakeRouteRepository repository;
  late Rxn<LocationFix> fix;

  setUp(() {
    Get.testMode = true;
    repository = FakeRouteRepository();
    fix = Rxn<LocationFix>();
  });

  tearDown(Get.reset);

  /// Runs [body] in fake time with a controller whose clock follows it.
  void withController(
    void Function(FakeAsync async, RouteController controller) body,
  ) {
    fakeAsync((async) {
      DateTime now() => startTime.add(async.elapsed);
      final controller = Get.put(RouteController(repository, fix, now: now));
      body(async, controller);
    });
  }

  LocationFix fixAt(LatLng point, DateTime time) => LocationFix(
    latitude: point.latitude,
    longitude: point.longitude,
    timestamp: time,
  );

  group('debounce', () {
    test('10 long-presses within 300 ms -> 1 request, for the last', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        final places = [
          for (var i = 0; i < 10; i++) LatLng(23.75 + i * 0.001, 90.42),
        ];

        for (final place in places) {
          controller.onMapLongPress(place);
          async.elapse(const Duration(milliseconds: 30));
        }
        async.elapse(_debounce);

        expect(repository.requests, hasLength(1));
        expect(repository.last.destination, places.last);
      });
    });

    test('the destination marker moves right away', () {
      withController((async, controller) {
        controller.onMapLongPress(_placeA);

        expect(controller.destination.value, _placeA);
        expect(repository.requests, isEmpty);
      });
    });
  });

  group('happy path', () {
    test('request uses the device location as start -> ready', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);

        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        expect(controller.status.value, RouteStatus.loading);
        expect(repository.last.start, _home);

        repository.last.succeed(fakeRoute(_home, _placeA));
        async.flushMicrotasks();

        expect(controller.status.value, RouteStatus.ready);
        expect(controller.route.value!.points.last, _placeA);
      });
    });

    test('slow hint after 3 s', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);

        async.elapse(const Duration(milliseconds: 2900));
        expect(controller.status.value, RouteStatus.loading);

        async.elapse(const Duration(milliseconds: 200));
        expect(controller.status.value, RouteStatus.loadingSlow);
      });
    });
  });

  group('start point', () {
    test('no location -> waitingForStart, first fix then requests', () {
      withController((async, controller) {
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        expect(controller.status.value, RouteStatus.waitingForStart);
        expect(repository.requests, isEmpty);

        fix.value = fixAt(_home, startTime.add(async.elapsed));
        async.elapse(_debounce);

        expect(repository.requests, hasLength(1));
      });
    });

    test('a location older than 2 minutes is not used', () {
      withController((async, controller) {
        fix.value = fixAt(
          _home,
          startTime.subtract(const Duration(minutes: 3)),
        );

        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);

        expect(controller.status.value, RouteStatus.waitingForStart);
      });
    });

    test('later location updates do not re-route', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        repository.last.succeed(fakeRoute(_home, _placeA));
        async.flushMicrotasks();

        fix.value = fixAt(_placeC, startTime.add(async.elapsed));
        async.elapse(const Duration(seconds: 5));

        expect(repository.requests, hasLength(1));
      });
    });

    test('manual start: next long-press sets the start, and it wins', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.startPickingStart();

        controller.onMapLongPress(_placeC);
        expect(controller.manualStart.value, _placeC);
        expect(controller.pickingStart.value, isFalse);
        expect(controller.destination.value, isNull);

        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);

        expect(repository.last.start, _placeC);
      });
    });

    test('no location ever: destination, then a manual start -> routes', () {
      withController((async, controller) {
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        expect(controller.status.value, RouteStatus.waitingForStart);

        controller.startPickingStart();
        controller.onMapLongPress(_placeC);
        async.elapse(_debounce);

        expect(controller.destination.value, _placeA);
        expect(repository.last.start, _placeC);
        expect(repository.last.destination, _placeA);
      });
    });

    test('cancel picking: the next long-press sets the destination', () {
      withController((async, controller) {
        controller.startPickingStart();
        controller.cancelPickingStart();

        controller.onMapLongPress(_placeA);

        expect(controller.manualStart.value, isNull);
        expect(controller.destination.value, _placeA);
      });
    });

    test('"Use my location" clears the manual start and re-routes', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.startPickingStart();
        controller.onMapLongPress(_placeC);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        repository.last.succeed(fakeRoute(_placeC, _placeA));
        async.flushMicrotasks();

        controller.clearManualStart();
        async.elapse(const Duration(seconds: 2)); // debounce + 1.1 s gate

        expect(controller.manualStart.value, isNull);
        expect(repository.requests, hasLength(2));
        expect(repository.last.start, _home);
      });
    });

    test('manual start closer than 15 m to the destination -> too close', () {
      withController((async, controller) {
        controller.onMapLongPress(_placeA);
        controller.startPickingStart();
        controller.onMapLongPress(const LatLng(23.75005, 90.4250)); // ~5.5 m
        async.elapse(_debounce);

        expect(controller.failure.value, isA<RouteDestinationTooClose>());
        expect(repository.requests, isEmpty);
      });
    });

    test('destination closer than 15 m -> too close, no request', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);

        controller.onMapLongPress(const LatLng(23.76255, 90.4368)); // ~5.5 m
        async.elapse(_debounce);

        expect(controller.failure.value, isA<RouteDestinationTooClose>());
        expect(repository.requests, isEmpty);
      });
    });
  });

  group('rate limit gate', () {
    test('a second request waits until 1.1 s after the first started', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce); // request 1 starts at 500 ms
        repository.last.succeed(fakeRoute(_home, _placeA));
        async.flushMicrotasks();

        controller.onMapLongPress(_placeB); // debounce ends at 1000 ms
        async.elapse(_debounce);
        expect(repository.requests, hasLength(1), reason: 'too soon');

        async.elapse(const Duration(milliseconds: 599)); // 1599 ms
        expect(repository.requests, hasLength(1));

        async.elapse(const Duration(milliseconds: 1)); // 1600 ms
        expect(repository.requests, hasLength(2));
      });
    });
  });

  group('stale answers', () {
    test('a newer request cancels the older one', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        final first = repository.last;

        controller.onMapLongPress(_placeB);
        async.elapse(const Duration(seconds: 2));

        expect(first.wasCancelled, isTrue);
        expect(repository.requests, hasLength(2));
      });
    });

    test('answers out of order -> the newest destination wins', () {
      withController((async, controller) {
        repository.honorCancel = false; // test the request-id guard alone
        fix.value = fixAt(_home, startTime);

        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        final old = repository.last;
        controller.onMapLongPress(_placeB);
        async.elapse(const Duration(seconds: 2));
        final newest = repository.last;

        newest.succeed(fakeRoute(_home, _placeB));
        async.flushMicrotasks();
        old.succeed(fakeRoute(_home, _placeA)); // late answer
        async.flushMicrotasks();

        expect(controller.route.value!.points.last, _placeB);
        expect(controller.status.value, RouteStatus.ready);
      });
    });

    test('a late failure of an old request is ignored', () {
      withController((async, controller) {
        repository.honorCancel = false;
        fix.value = fixAt(_home, startTime);

        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        final old = repository.last;
        controller.onMapLongPress(_placeB);
        async.elapse(const Duration(seconds: 2));
        repository.last.succeed(fakeRoute(_home, _placeB));
        async.flushMicrotasks();

        old.fail(const RouteTimeout());
        async.flushMicrotasks();

        expect(controller.failure.value, isNull);
        expect(controller.status.value, RouteStatus.ready);
      });
    });

    test('closing the screen while a request is pending is safe', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        final pending = repository.last;

        Get.delete<RouteController>();
        async.flushMicrotasks();
        expect(pending.wasCancelled, isTrue);

        pending.succeed(fakeRoute(_home, _placeA));
        async.flushMicrotasks();

        expect(controller.route.value, isNull);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  test('closing during the automatic 429 retry wait leaves no timers', () {
    withController((async, controller) {
      fix.value = fixAt(_home, startTime);
      controller.onMapLongPress(_placeA);
      async.elapse(_debounce);
      repository.last.fail(const RouteRateLimited());
      async.flushMicrotasks();
      expect(async.pendingTimers, isNotEmpty); // the 2 s retry

      Get.delete<RouteController>();

      expect(async.pendingTimers, isEmpty);
      async.elapse(const Duration(seconds: 5));
      expect(repository.requests, hasLength(1));
    });
  });

  group('dedupe and retry', () {
    test('same destination (< 10 m) with the same start is not requested', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        repository.last.succeed(fakeRoute(_home, _placeA));
        async.flushMicrotasks();

        controller.onMapLongPress(const LatLng(23.75003, 90.4250)); // ~3 m
        async.elapse(const Duration(seconds: 3));

        expect(repository.requests, hasLength(1));
        expect(controller.status.value, RouteStatus.ready);
      });
    });

    test('failure -> error, Retry requests again', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        repository.last.fail(const RouteNetworkFailure());
        async.flushMicrotasks();
        expect(controller.failure.value, isA<RouteNetworkFailure>());

        controller.retry();
        async.elapse(const Duration(seconds: 2));

        expect(repository.requests, hasLength(2));
        expect(controller.status.value, RouteStatus.loading);
      });
    });

    test('rate limited -> one automatic retry after 2 s, not more', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        repository.last.fail(const RouteRateLimited());
        async.flushMicrotasks();
        expect(controller.failure.value, isA<RouteRateLimited>());

        async.elapse(const Duration(seconds: 2));
        expect(repository.requests, hasLength(2));

        repository.last.fail(const RouteRateLimited());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        expect(repository.requests, hasLength(2));
      });
    });

    test('clear removes the destination and route', () {
      withController((async, controller) {
        fix.value = fixAt(_home, startTime);
        controller.onMapLongPress(_placeA);
        async.elapse(_debounce);
        repository.last.succeed(fakeRoute(_home, _placeA));
        async.flushMicrotasks();

        controller.clear();

        expect(controller.destination.value, isNull);
        expect(controller.route.value, isNull);
        expect(controller.status.value, RouteStatus.idle);
      });
    });
  });
}
