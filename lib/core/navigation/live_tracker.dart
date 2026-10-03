import 'dart:math' as math;

import 'package:garipath/core/geo/geo_math.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:garipath/core/navigation/heading_smoother.dart';
import 'package:garipath/core/navigation/navigation_frame.dart';
import 'package:latlong2/latlong.dart';

/// Live GPS mode: the car shows where the device really is.
///
/// GPS fixes arrive about every 2 seconds. Drawing each fix directly would
/// make the car jump, so [onFix] only sets a target and every [tick] glides
/// the car a little closer to it (same smoothing idea as the heading).
class LiveTracker {
  LiveTracker(
    this.geometry, {
    required this.secondsPerMeter,
    this.glideSeconds = 0.6,
    this.snapMeters = 25,
    this.arrivalMeters = 20,
    HeadingSmoother? headingSmoother,
  }) : _smoother = headingSmoother ?? HeadingSmoother(timeConstantSeconds: 0.4);

  final RouteGeometry geometry;

  /// Used for the remaining time: the route's own pace (OSRM duration /
  /// distance), since real driving speed changes all the time.
  final double secondsPerMeter;

  /// About how long the car takes to catch up with a new fix.
  final double glideSeconds;

  /// A fix closer than this to the route is drawn on the route line
  /// ("snap to route"); GPS is often a few metres off the road.
  final double snapMeters;

  /// Closer than this to the destination counts as arrived.
  final double arrivalMeters;

  /// Below this speed, the GPS direction is unreliable.
  static const _minSpeedForGpsBearing = 1.5;

  final HeadingSmoother _smoother;

  LatLng? _target;
  LatLng? _shown;
  double _targetHeading = 0;
  RouteProjection? _projection;

  /// Where the latest fix falls on the route (offset, distance along).
  RouteProjection? get lastProjection => _projection;

  bool get hasFix => _target != null;

  bool get arrived {
    final projection = _projection;
    if (projection == null) return false;
    return geometry.totalMeters - projection.distanceAlongMeters <=
        arrivalMeters;
  }

  /// A new GPS fix. Returns where it falls on the route.
  RouteProjection onFix(
    LatLng position, {
    double? bearingDegrees,
    double? speedMps,
  }) {
    final projection = geometry.project(position);
    final target = projection.offsetMeters <= snapMeters
        ? projection.point
        : position;

    _targetHeading = _headingFor(
      target,
      projection,
      bearingDegrees: bearingDegrees,
      speedMps: speedMps,
    );
    _projection = projection;
    _target = target;
    _shown ??= target; // the first fix appears directly
    return projection;
  }

  /// Glides the car toward the latest fix. Null until the first fix.
  NavigationFrame? tick(Duration dt) {
    final target = _target;
    final shown = _shown;
    final projection = _projection;
    if (target == null || shown == null || projection == null) return null;

    final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
    final fraction = seconds <= 0 ? 0.0 : 1 - math.exp(-seconds / glideSeconds);
    final position = GeoMath.lerp(shown, target, fraction);
    _shown = position;

    final remaining = math.max(
      0.0,
      geometry.totalMeters - projection.distanceAlongMeters,
    );
    final frame = NavigationFrame(
      position: position,
      headingDegrees: _smoother.update(_targetHeading, dt),
      distanceMeters: projection.distanceAlongMeters,
      remainingMeters: remaining,
      remainingSeconds: remaining * secondsPerMeter,
      progress: geometry.totalMeters > 0
          ? projection.distanceAlongMeters / geometry.totalMeters
          : 1,
    );
    return frame.isFinite ? frame : null;
  }

  /// GPS direction when moving; otherwise the direction of movement
  /// between fixes; otherwise the direction of the route at that spot.
  double _headingFor(
    LatLng target,
    RouteProjection projection, {
    double? bearingDegrees,
    double? speedMps,
  }) {
    if (bearingDegrees != null &&
        speedMps != null &&
        speedMps >= _minSpeedForGpsBearing) {
      return bearingDegrees;
    }
    final previous = _target;
    if (previous != null && GeoMath.distanceMeters(previous, target) > 3) {
      return GeoMath.bearingDegrees(previous, target);
    }
    return geometry.bearingAt(projection.distanceAlongMeters);
  }
}
