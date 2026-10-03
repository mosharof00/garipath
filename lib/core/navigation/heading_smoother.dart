import 'dart:math' as math;

import 'package:garipath/core/geo/geo_math.dart';

/// Turns the car smoothly toward a target heading, always the short way.
///
/// Each update moves the heading a fraction of the way to the target:
/// `fraction = 1 - e^(-dt / tau)`. Because it uses the real time step `dt`,
/// the car turns at the same rate at 30, 60 or 120 frames per second, and
/// it never overshoots the target.
class HeadingSmoother {
  HeadingSmoother({this.timeConstantSeconds = 0.12});

  /// About how long a turn takes at 1x. Smaller = snappier.
  final double timeConstantSeconds;

  double? _current;

  /// The smoothed heading in degrees [0, 360), or null before the first
  /// update.
  double? get current => _current;

  /// Moves toward [targetDegrees] and returns the new heading.
  ///
  /// The first call jumps straight to the target, so the car doesn't spin
  /// when it appears. At a higher [multiplier] the car turns faster, to keep
  /// up with its higher speed.
  double update(double targetDegrees, Duration dt, {int multiplier = 1}) {
    final target = GeoMath.normalizeDegrees(targetDegrees);
    final current = _current;
    if (current == null) {
      _current = target;
      return target;
    }

    final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return current;

    final tau = timeConstantSeconds / multiplier;
    final fraction = 1 - math.exp(-seconds / tau);
    final turn = GeoMath.shortestTurnDegrees(current, target);
    final next = GeoMath.normalizeDegrees(current + turn * fraction);
    _current = next;
    return next;
  }

  /// Forget the heading; the next update jumps to its target again.
  void reset() => _current = null;
}
