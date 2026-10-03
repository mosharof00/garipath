import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Small, pure geo helpers used by the route geometry and the car animation.
///
/// Angles are in degrees, 0 = north, growing clockwise (like a compass).
abstract final class GeoMath {
  /// Mean Earth radius in metres.
  static const earthRadiusMeters = 6371008.8;

  /// Straight-line distance over the Earth's surface (haversine formula).
  static double distanceMeters(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLat = lat2 - lat1;
    final dLng = _toRadians(to.longitude - from.longitude);

    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final a =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;

    // Rounding can push `a` slightly outside 0..1, and sqrt(-0.0000001)
    // would be NaN. Clamping keeps the result a real number.
    final clamped = a.clamp(0.0, 1.0);
    return 2 * earthRadiusMeters * math.asin(math.sqrt(clamped));
  }

  /// Compass direction to travel from [from] towards [to], in `[0, 360)`.
  static double bearingDegrees(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLng = _toRadians(to.longitude - from.longitude);

    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return normalizeDegrees(_toDegrees(math.atan2(y, x)));
  }

  /// Any angle into `[0, 360)`. For example -90 -> 270 and 450 -> 90.
  static double normalizeDegrees(double degrees) {
    // Dart's % always returns a value >= 0 for a positive divisor.
    final result = degrees % 360;
    // A tiny negative input like -1e-15 gives exactly 360.0 after rounding.
    return result >= 360 ? 0 : result;
  }

  /// The smallest turn from [from] to [to], in `[-180, 180]`.
  /// Positive = clockwise. 359 -> 1 is +2 (not -358).
  static double shortestTurnDegrees(double from, double to) {
    return (to - from + 540) % 360 - 180;
  }

  /// The point a fraction [t] (0..1) of the way from [a] to [b].
  /// Straight lines in lat/lng are fine for short route segments.
  static LatLng lerp(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
  static double _toDegrees(double radians) => radians * 180 / math.pi;
}
