import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/geo/geo_math.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('constant speed: 2 points and 200 points give the same position', () {
    const start = LatLng(23.7500, 90.4000);
    const end = LatLng(23.7600, 90.4100); // ~1.5 km diagonal
    final dense = [
      for (var i = 0; i < 200; i++) GeoMath.lerp(start, end, i / 199),
    ];

    final simple = RouteAnimator(
      RouteGeometry.fromPoints([start, end]),
      baseSpeedMps: 13.9,
    )..start();
    final detailed = RouteAnimator(
      RouteGeometry.fromPoints(dense),
      baseSpeedMps: 13.9,
    )..start();

    for (var i = 0; i < 600; i++) {
      // Uneven frame times, like a real device.
      final dt = Duration(milliseconds: 8 + (i % 5) * 7);
      final a = simple.tick(dt).position;
      final b = detailed.tick(dt).position;
      expect(GeoMath.distanceMeters(a, b), lessThan(0.5), reason: 'tick $i');
    }
  });

  test('fuzz: messy routes never produce NaN or a bad heading', () {
    // A fixed seed makes any failure reproducible.
    final random = Random(42);

    for (var route = 0; route < 1000; route++) {
      final points = _messyRoute(random);
      final animator = RouteAnimator(
        RouteGeometry.fromPoints(points),
        baseSpeedMps: 13.9,
      )..start();
      animator.setMultiplier([1, 2, 5][random.nextInt(3)]);

      for (var i = 0; i < 200; i++) {
        final dt = Duration(microseconds: random.nextInt(200000));
        final frame = animator.tick(dt);
        final where = 'route $route, tick $i';
        expect(frame.isFinite, isTrue, reason: where);
        expect(frame.headingDegrees, inInclusiveRange(0, 359.999999));
        expect(frame.progress, inInclusiveRange(0, 1), reason: where);
      }
    }
  });
}

/// A random walk around Dhaka with duplicates, tiny steps and NaN points.
List<LatLng> _messyRoute(Random random) {
  var lat = 23.8 + random.nextDouble() * 0.1;
  var lng = 90.4 + random.nextDouble() * 0.1;
  final points = [LatLng(lat, lng)];
  final count = 1 + random.nextInt(40);

  for (var i = 0; i < count; i++) {
    final roll = random.nextDouble();
    if (roll < 0.3) {
      points.add(points.last); // exact duplicate
    } else if (roll < 0.4) {
      lat += 1e-9; // micro-segment, far below 0.5 m
      points.add(LatLng(lat, lng));
    } else if (roll < 0.45) {
      points.add(const LatLng(double.nan, double.nan));
    } else {
      lat += (random.nextDouble() - 0.5) * 0.002;
      lng += (random.nextDouble() - 0.5) * 0.002;
      points.add(LatLng(lat, lng));
    }
  }
  return points;
}
