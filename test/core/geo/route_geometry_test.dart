import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/geo/geo_math.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:latlong2/latlong.dart';

/// Metres per degree of longitude on the equator.
const _metersPerDegree =
    2 * 3.141592653589793 * GeoMath.earthRadiusMeters / 360;

/// A point [meters] east of (0, 0), on the equator.
LatLng east(double meters) => LatLng(0, meters / _metersPerDegree);

/// A point [meters] north of (0, 0).
LatLng north(double meters) => LatLng(meters / _metersPerDegree, 0);

void main() {
  group('cleaning', () {
    test('exact duplicates are removed', () {
      final geometry = RouteGeometry.fromPoints([
        east(0),
        east(0),
        east(100),
        east(100),
        east(200),
      ]);

      expect(geometry.points, [east(0), east(100), east(200)]);
    });

    test('points closer than 0.5 m are removed', () {
      final geometry = RouteGeometry.fromPoints([
        east(0),
        east(0.3),
        east(100),
        east(100.4),
        east(200),
      ]);

      expect(geometry.points, [east(0), east(100), east(200)]);
    });

    test('the destination is kept exactly even when it is very close', () {
      final geometry = RouteGeometry.fromPoints([
        east(0),
        east(100),
        east(100.2),
      ]);

      expect(geometry.points.last, east(100.2));
      expect(geometry.points, hasLength(2));
    });

    test('several points bunched at the end leave no tiny segment', () {
      final geometry = RouteGeometry.fromPoints([
        east(0),
        east(100),
        east(100.6),
        east(100.9),
      ]);

      expect(geometry.points.last, east(100.9));
      for (var i = 1; i < geometry.cumulativeMeters.length; i++) {
        final segment =
            geometry.cumulativeMeters[i] - geometry.cumulativeMeters[i - 1];
        expect(segment, greaterThanOrEqualTo(0.5));
      }
    });

    test('all points identical -> a single point with length 0', () {
      final geometry = RouteGeometry.fromPoints([east(5), east(5), east(5)]);

      expect(geometry.isDegenerate, isTrue);
      expect(geometry.totalMeters, 0);
      expect(geometry.positionAt(10), east(5));
      expect(geometry.bearingAt(10), 0);
    });

    test('a single point is degenerate', () {
      final geometry = RouteGeometry.fromPoints([east(5)]);

      expect(geometry.isDegenerate, isTrue);
      expect(geometry.points, [east(5)]);
    });

    test('no points at all is an error', () {
      expect(() => RouteGeometry.fromPoints([]), throwsArgumentError);
    });
  });

  group('distances', () {
    test('cumulative distances start at 0 and strictly increase', () {
      final geometry = RouteGeometry.fromPoints([
        east(0),
        east(50),
        east(50.1),
        east(120),
        east(300),
      ]);

      expect(geometry.cumulativeMeters.first, 0);
      for (var i = 1; i < geometry.cumulativeMeters.length; i++) {
        expect(
          geometry.cumulativeMeters[i],
          greaterThan(geometry.cumulativeMeters[i - 1]),
        );
      }
    });

    test('total length is the sum of the segments', () {
      final geometry = RouteGeometry.fromPoints([
        east(0),
        east(100),
        east(250),
      ]);

      expect(geometry.totalMeters, closeTo(250, 0.01));
    });
  });

  group('positionAt', () {
    final geometry = RouteGeometry.fromPoints([east(0), east(100), east(300)]);

    test('0 is the start and total is the end', () {
      expect(geometry.positionAt(0), east(0));
      expect(geometry.positionAt(geometry.totalMeters), east(300));
    });

    test('in the middle of a segment', () {
      final position = geometry.positionAt(200);

      expect(position.longitude, closeTo(east(200).longitude, 1e-9));
    });

    test('exactly on an inner point', () {
      final position = geometry.positionAt(geometry.cumulativeMeters[1]);

      expect(position.longitude, closeTo(east(100).longitude, 1e-9));
    });

    test('before the start or after the end is clamped', () {
      expect(geometry.positionAt(-50), east(0));
      expect(geometry.positionAt(10000), east(300));
    });

    test('NaN distance gives the start instead of a NaN position', () {
      expect(geometry.positionAt(double.nan), east(0));
    });

    test('speed does not depend on how many points the route has', () {
      // The same 1 km straight road: 2 points vs 1,001 points.
      final sparse = RouteGeometry.fromPoints([east(0), east(1000)]);
      final dense = RouteGeometry.fromPoints([
        for (var m = 0; m <= 1000; m++) east(m.toDouble()),
      ]);

      for (final meters in [0.0, 137.0, 500.0, 999.0, 1000.0]) {
        expect(
          GeoMath.distanceMeters(
            sparse.positionAt(meters),
            dense.positionAt(meters),
          ),
          lessThan(0.01),
          reason: 'at $meters m',
        );
      }
    });
  });

  group('bearingAt', () {
    // East for 100 m, then north for 100 m.
    final geometry = RouteGeometry.fromPoints([
      east(0),
      east(100),
      LatLng(north(100).latitude, east(100).longitude),
    ]);

    test('first segment heads east, second heads north', () {
      expect(geometry.bearingAt(50), closeTo(90, 0.01));
      expect(geometry.bearingAt(150), closeTo(0, 0.01));
    });

    test('at the very end it keeps the last segment direction', () {
      expect(geometry.bearingAt(geometry.totalMeters), closeTo(0, 0.01));
    });
  });
}
