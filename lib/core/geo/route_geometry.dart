import 'dart:math' as math;

import 'package:garipath/core/geo/geo_math.dart';
import 'package:latlong2/latlong.dart';

/// Where a position falls on a route. See [RouteGeometry.project].
class RouteProjection {
  const RouteProjection({
    required this.point,
    required this.distanceAlongMeters,
    required this.offsetMeters,
  });

  /// The closest point on the route line.
  final LatLng point;

  /// Distance from the route start to [point], along the route.
  final double distanceAlongMeters;

  /// How far the position is from the route line.
  final double offsetMeters;
}

/// A route prepared for animation: cleaned points plus the distance from the
/// start to every point.
///
/// The car's progress is measured in metres, not in point index. That keeps
/// its speed constant no matter how close together the points are.
class RouteGeometry {
  RouteGeometry._(this.points, this.cumulativeMeters, this._segmentBearings);

  /// Builds the geometry from raw route points (for example a decoded
  /// polyline).
  ///
  /// Cleaning rules:
  /// - Points with NaN or infinite coordinates are dropped.
  /// - A point closer than [minPointSpacingMeters] to the previous kept point
  ///   is dropped, so no segment has zero length (zero length means a
  ///   division by zero and an undefined direction).
  /// - The last point (the destination) is always kept exactly.
  ///
  /// Throws an [ArgumentError] if there is no valid point at all.
  factory RouteGeometry.fromPoints(List<LatLng> rawPoints) {
    final valid = rawPoints
        .where((p) => p.latitude.isFinite && p.longitude.isFinite)
        .toList();
    if (valid.isEmpty) {
      throw ArgumentError.value(rawPoints, 'rawPoints', 'has no valid point');
    }

    final kept = <LatLng>[valid.first];
    for (final point in valid.skip(1)) {
      if (GeoMath.distanceMeters(kept.last, point) >= minPointSpacingMeters) {
        kept.add(point);
      }
    }

    // Keep the real destination. If it was dropped for being too close,
    // remove the kept points near it instead, then add it.
    final destination = valid.last;
    if (kept.last != destination) {
      bool tooClose() =>
          GeoMath.distanceMeters(kept.last, destination) <
          minPointSpacingMeters;

      while (kept.length > 1 && tooClose()) {
        kept.removeLast();
      }
      if (tooClose()) {
        kept[0] = destination; // start and end are the same place
      } else {
        kept.add(destination);
      }
    }

    final cumulative = <double>[0];
    final bearings = <double>[];
    for (var i = 1; i < kept.length; i++) {
      cumulative.add(
        cumulative.last + GeoMath.distanceMeters(kept[i - 1], kept[i]),
      );
      bearings.add(GeoMath.bearingDegrees(kept[i - 1], kept[i]));
    }

    return RouteGeometry._(
      List.unmodifiable(kept),
      List.unmodifiable(cumulative),
      List.unmodifiable(bearings),
    );
  }

  /// Points closer than this are treated as the same point.
  static const minPointSpacingMeters = 0.5;

  /// The cleaned points, in order. Never empty.
  final List<LatLng> points;

  /// `cumulativeMeters[i]` is the distance along the route from the start to
  /// `points[i]`. Starts at 0 and always increases.
  final List<double> cumulativeMeters;

  /// `_segmentBearings[i]` is the direction from `points[i]` to `points[i+1]`.
  final List<double> _segmentBearings;

  double get totalMeters => cumulativeMeters.last;

  /// True when the route is a single point (start and end are the same place).
  bool get isDegenerate => points.length < 2;

  /// The point [meters] along the route. Values outside the route are
  /// clamped to the start or the end.
  LatLng positionAt(double meters) {
    if (isDegenerate) return points.first;

    final distance = _clampDistance(meters);
    final i = _segmentIndexAt(distance);
    final segmentStart = cumulativeMeters[i];
    final segmentLength = cumulativeMeters[i + 1] - segmentStart;
    // segmentLength > 0 is guaranteed by the cleaning in fromPoints.
    final t = (distance - segmentStart) / segmentLength;
    return GeoMath.lerp(points[i], points[i + 1], t);
  }

  /// Direction of the segment the car is on at [meters]. 0 for a single point.
  double bearingAt(double meters) {
    if (isDegenerate) return 0;
    return _segmentBearings[_segmentIndexAt(_clampDistance(meters))];
  }

  /// The closest point on the route to [position].
  ///
  /// Each segment is checked in a flat (equirectangular) projection centred
  /// on [position]. Over the few hundred metres that matter here, that is
  /// accurate to centimetres, and much simpler than spherical geometry.
  RouteProjection project(LatLng position) {
    if (isDegenerate) {
      return RouteProjection(
        point: points.first,
        distanceAlongMeters: 0,
        offsetMeters: GeoMath.distanceMeters(position, points.first),
      );
    }

    final metersPerDegree = GeoMath.earthRadiusMeters * math.pi / 180;
    final metersPerDegreeLng =
        metersPerDegree * math.cos(position.latitude * math.pi / 180);
    // Position of a point in metres, relative to [position] at (0, 0).
    double x(LatLng p) =>
        (p.longitude - position.longitude) * metersPerDegreeLng;
    double y(LatLng p) => (p.latitude - position.latitude) * metersPerDegree;

    var bestSegment = 0;
    var bestT = 0.0;
    var bestDistanceSquared = double.infinity;

    for (var i = 0; i < points.length - 1; i++) {
      final ax = x(points[i]), ay = y(points[i]);
      final dx = x(points[i + 1]) - ax, dy = y(points[i + 1]) - ay;
      final lengthSquared = dx * dx + dy * dy;
      // How far along the segment the closest point is (0 = start, 1 = end).
      final t = lengthSquared == 0
          ? 0.0
          : ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      final distanceSquared = cx * cx + cy * cy;
      if (distanceSquared < bestDistanceSquared) {
        bestDistanceSquared = distanceSquared;
        bestSegment = i;
        bestT = t;
      }
    }

    final segmentStart = cumulativeMeters[bestSegment];
    final segmentLength = cumulativeMeters[bestSegment + 1] - segmentStart;
    return RouteProjection(
      point: GeoMath.lerp(points[bestSegment], points[bestSegment + 1], bestT),
      distanceAlongMeters: segmentStart + bestT * segmentLength,
      offsetMeters: math.sqrt(bestDistanceSquared),
    );
  }

  double _clampDistance(double meters) {
    if (meters.isNaN) return 0;
    return meters.clamp(0.0, totalMeters);
  }

  /// Index `i` of the segment `points[i] -> points[i+1]` that contains
  /// [distance], found by binary search (fast even for long routes).
  int _segmentIndexAt(double distance) {
    var low = 0;
    var high = cumulativeMeters.length - 1;
    // Find the last index whose cumulative distance is <= distance.
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (cumulativeMeters[mid] <= distance) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    // At the very end, use the last segment instead of "after the last point".
    return low.clamp(0, points.length - 2);
  }
}
