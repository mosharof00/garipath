import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/geo/geo_math.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:latlong2/latlong.dart';

// About 1.1 km due north, then about 1 km due east.
const _start = LatLng(23.75, 90.40);
const _corner = LatLng(23.76, 90.40);
const _end = LatLng(23.76, 90.41);

void main() {
  final route = RouteGeometry.fromPoints([_start, _corner, _end]);
  final firstLeg = GeoMath.distanceMeters(_start, _corner);

  test('a point on the line projects onto itself', () {
    const onLine = LatLng(23.755, 90.40);

    final result = route.project(onLine);

    expect(result.offsetMeters, closeTo(0, 0.01));
    expect(result.distanceAlongMeters, closeTo(firstLeg / 2, 0.5));
    expect(result.point.latitude, closeTo(onLine.latitude, 1e-9));
  });

  test('a point beside the line: perpendicular offset', () {
    // 0.0005° east of the first leg, at its middle: ~51 m away.
    const beside = LatLng(23.755, 90.4005);

    final result = route.project(beside);

    expect(result.offsetMeters, closeTo(50.9, 0.5));
    expect(result.distanceAlongMeters, closeTo(firstLeg / 2, 0.5));
    expect(result.point.longitude, closeTo(90.40, 1e-9));
  });

  test('before the start: clamps to the start', () {
    final result = route.project(const LatLng(23.74, 90.40));

    expect(result.distanceAlongMeters, 0);
    expect(result.point, _start);
    expect(result.offsetMeters, closeTo(1112, 2));
  });

  test('past the end: clamps to the end', () {
    final result = route.project(const LatLng(23.76, 90.42));

    expect(result.distanceAlongMeters, closeTo(route.totalMeters, 0.01));
    expect(result.point.longitude, closeTo(_end.longitude, 1e-9));
  });

  test('picks the second leg when it is closer', () {
    // Just south of the middle of the east-going leg.
    final result = route.project(const LatLng(23.7598, 90.405));

    expect(result.distanceAlongMeters, greaterThan(firstLeg));
    expect(result.offsetMeters, closeTo(22.2, 0.5));
  });

  test('single-point route: distance to that point', () {
    final single = RouteGeometry.fromPoints([_start]);

    final result = single.project(_corner);

    expect(result.point, _start);
    expect(result.distanceAlongMeters, 0);
    expect(result.offsetMeters, closeTo(firstLeg, 0.01));
  });
}
