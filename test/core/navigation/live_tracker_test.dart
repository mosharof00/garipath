import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:garipath/core/navigation/live_tracker.dart';
import 'package:latlong2/latlong.dart';

// About 1.1 km due north. At this latitude 0.0001° of longitude is ~10 m.
const _start = LatLng(23.75, 90.40);
const _end = LatLng(23.76, 90.40);
const _tick = Duration(milliseconds: 16);

void main() {
  late LiveTracker tracker;

  setUp(() {
    tracker = LiveTracker(
      RouteGeometry.fromPoints([_start, _end]),
      secondsPerMeter: 0.1,
    );
  });

  test('no fix yet: no frame', () {
    expect(tracker.hasFix, isFalse);
    expect(tracker.tick(_tick), isNull);
  });

  test('first fix appears directly, no glide from nowhere', () {
    tracker.onFix(const LatLng(23.755, 90.40));

    final frame = tracker.tick(_tick)!;

    expect(frame.position.latitude, closeTo(23.755, 1e-9));
  });

  test('a fix a few metres off the road snaps onto the route', () {
    // ~10 m east of the line.
    final projection = tracker.onFix(const LatLng(23.755, 90.4001));

    final frame = tracker.tick(_tick)!;

    expect(projection.offsetMeters, closeTo(10, 1));
    expect(frame.position.longitude, closeTo(90.40, 1e-9));
  });

  test('a fix far off the road is drawn where it really is', () {
    // ~100 m east of the line.
    tracker.onFix(const LatLng(23.755, 90.401));

    final frame = tracker.tick(_tick)!;

    expect(frame.position.longitude, closeTo(90.401, 1e-9));
  });

  test('the car glides to a new fix instead of jumping', () {
    tracker.onFix(const LatLng(23.751, 90.40));
    tracker.tick(_tick);

    tracker.onFix(const LatLng(23.752, 90.40)); // ~110 m further
    final afterOneFrame = tracker.tick(_tick)!.position.latitude;
    for (var i = 0; i < 300; i++) {
      tracker.tick(_tick);
    }
    final afterFiveSeconds = tracker.tick(_tick)!.position.latitude;

    expect(afterOneFrame, greaterThan(23.751));
    expect(afterOneFrame, lessThan(23.7512)); // only a small step
    expect(afterFiveSeconds, closeTo(23.752, 1e-6));
  });

  test('remaining distance and time use the route pace', () {
    tracker.onFix(const LatLng(23.755, 90.40)); // halfway

    final frame = tracker.tick(_tick)!;

    expect(frame.progress, closeTo(0.5, 0.01));
    expect(frame.remainingSeconds, closeTo(frame.remainingMeters * 0.1, 1e-6));
  });

  test('heading: GPS bearing when moving fast enough', () {
    tracker.onFix(const LatLng(23.755, 90.40), bearingDegrees: 90, speedMps: 5);
    for (var i = 0; i < 300; i++) {
      tracker.tick(_tick);
    }

    expect(tracker.tick(_tick)!.headingDegrees, closeTo(90, 0.5));
  });

  test('heading: route direction when standing still', () {
    // A slow, noisy GPS bearing must be ignored.
    tracker.onFix(
      const LatLng(23.755, 90.40),
      bearingDegrees: 200,
      speedMps: 0.2,
    );
    for (var i = 0; i < 300; i++) {
      tracker.tick(_tick);
    }

    expect(tracker.tick(_tick)!.headingDegrees, closeTo(0, 0.5));
  });

  test('arrived only near the destination', () {
    tracker.onFix(const LatLng(23.755, 90.40));
    expect(tracker.arrived, isFalse);

    tracker.onFix(const LatLng(23.7599, 90.40)); // ~11 m before the end
    expect(tracker.arrived, isTrue);
  });
}
