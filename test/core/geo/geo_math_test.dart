import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/geo/geo_math.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const dhaka = LatLng(23.8103, 90.4125);
  const chattogram = LatLng(22.3569, 91.7832);

  group('distanceMeters', () {
    test('Dhaka to Chattogram is about 213 km (±1%)', () {
      final km = GeoMath.distanceMeters(dhaka, chattogram) / 1000;

      expect(km, closeTo(213, 213 * 0.01));
    });

    test('same point is 0', () {
      expect(GeoMath.distanceMeters(dhaka, dhaka), 0);
    });

    test('is the same in both directions', () {
      expect(
        GeoMath.distanceMeters(dhaka, chattogram),
        closeTo(GeoMath.distanceMeters(chattogram, dhaka), 1e-6),
      );
    });

    test('one degree of latitude is about 111.2 km', () {
      final meters = GeoMath.distanceMeters(
        const LatLng(0, 0),
        const LatLng(1, 0),
      );

      expect(meters, closeTo(111195, 10));
    });

    test('opposite sides of the Earth stay a real number', () {
      final meters = GeoMath.distanceMeters(
        const LatLng(0, 0),
        const LatLng(0, 180),
      );

      expect(meters.isFinite, isTrue);
      expect(meters, closeTo(GeoMath.earthRadiusMeters * 3.14159265, 10));
    });

    test('tiny distances are not rounded to NaN or negative', () {
      final meters = GeoMath.distanceMeters(
        dhaka,
        const LatLng(23.8103, 90.41250001),
      );

      expect(meters.isFinite, isTrue);
      expect(meters, greaterThan(0));
      expect(meters, lessThan(0.01));
    });
  });

  group('bearingDegrees', () {
    const origin = LatLng(0, 0);

    test('north, east, south, west', () {
      expect(
        GeoMath.bearingDegrees(origin, const LatLng(1, 0)),
        closeTo(0, 1e-9),
      );
      expect(
        GeoMath.bearingDegrees(origin, const LatLng(0, 1)),
        closeTo(90, 1e-9),
      );
      expect(
        GeoMath.bearingDegrees(origin, const LatLng(-1, 0)),
        closeTo(180, 1e-9),
      );
      expect(
        GeoMath.bearingDegrees(origin, const LatLng(0, -1)),
        closeTo(270, 1e-9),
      );
    });

    test('Dhaka to Chattogram is south-east', () {
      final bearing = GeoMath.bearingDegrees(dhaka, chattogram);

      expect(bearing, greaterThan(90));
      expect(bearing, lessThan(180));
    });

    test('is always in [0, 360)', () {
      final bearing = GeoMath.bearingDegrees(origin, const LatLng(1, -0.001));

      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });
  });

  group('normalizeDegrees', () {
    test('wraps negatives and values above 360', () {
      expect(GeoMath.normalizeDegrees(-90), 270);
      expect(GeoMath.normalizeDegrees(450), 90);
      expect(GeoMath.normalizeDegrees(360), 0);
      expect(GeoMath.normalizeDegrees(-720), 0);
      expect(GeoMath.normalizeDegrees(0), 0);
    });

    test('a tiny negative number becomes 0, never 360', () {
      expect(GeoMath.normalizeDegrees(-1e-15), 0);
    });
  });

  group('shortestTurnDegrees', () {
    test('359 -> 1 turns +2, not -358', () {
      expect(GeoMath.shortestTurnDegrees(359, 1), closeTo(2, 1e-9));
    });

    test('1 -> 359 turns -2', () {
      expect(GeoMath.shortestTurnDegrees(1, 359), closeTo(-2, 1e-9));
    });

    test('simple turns', () {
      expect(GeoMath.shortestTurnDegrees(0, 90), 90);
      expect(GeoMath.shortestTurnDegrees(90, 0), -90);
      expect(GeoMath.shortestTurnDegrees(45, 45), 0);
    });

    test('a half turn stays within [-180, 180]', () {
      final turn = GeoMath.shortestTurnDegrees(0, 180);

      expect(turn.abs(), 180);
    });

    test('works with negative and very large inputs', () {
      expect(GeoMath.shortestTurnDegrees(-720, 30), closeTo(30, 1e-9));
      expect(GeoMath.shortestTurnDegrees(-10, 10), closeTo(20, 1e-9));
      expect(GeoMath.shortestTurnDegrees(725, 0), closeTo(-5, 1e-9));
    });
  });

  group('lerp', () {
    const a = LatLng(10, 20);
    const b = LatLng(20, 40);

    test('0 is the start, 1 is the end, 0.5 is the middle', () {
      expect(GeoMath.lerp(a, b, 0), a);
      expect(GeoMath.lerp(a, b, 1), b);
      expect(GeoMath.lerp(a, b, 0.5), const LatLng(15, 30));
    });
  });
}
