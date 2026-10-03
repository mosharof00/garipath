import 'package:garipath/core/geo/geo_math.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:garipath/core/navigation/heading_smoother.dart';
import 'package:garipath/core/navigation/navigation_frame.dart';

enum PlaybackState { idle, playing, paused, finished }

/// Moves a car along a route at a constant speed.
///
/// Pure Dart: it has no timer of its own. Something else calls [tick] with
/// the time since the last frame, so tests can drive it with exact steps.
///
/// Progress is stored in metres, so the speed is the same whether the route
/// has 2 points or 2,000.
class RouteAnimator {
  RouteAnimator(
    this.geometry, {
    required this.baseSpeedMps,
    this.lookAheadMeters = 15,
    HeadingSmoother? headingSmoother,
  }) : _smoother = headingSmoother ?? HeadingSmoother() {
    if (!baseSpeedMps.isFinite || baseSpeedMps <= 0) {
      throw ArgumentError.value(baseSpeedMps, 'baseSpeedMps', 'must be > 0');
    }
    _frame = _buildFrame(Duration.zero) ?? _startFrame();
  }

  /// Longest time step used for one tick. After a long pause (app in the
  /// background, debugger, slow frame) the car moves at most this much
  /// time worth of distance instead of jumping ahead.
  static const maxTickStep = Duration(milliseconds: 100);

  /// Below this, two points are treated as the same for the heading.
  static const _sameSpotMeters = 0.1;

  final RouteGeometry geometry;

  /// Speed at 1x, in metres per second.
  final double baseSpeedMps;

  /// The car points at the spot this far ahead on the route. Corners then
  /// turn a little before the corner, like a real driver.
  final double lookAheadMeters;

  final HeadingSmoother _smoother;

  PlaybackState _state = PlaybackState.idle;
  PlaybackState get state => _state;

  int _multiplier = 1;
  int get multiplier => _multiplier;

  double _distance = 0;
  double? _lastTargetHeading;

  late NavigationFrame _frame;
  NavigationFrame get frame => _frame;

  /// Starts from the beginning. Works from idle or finished.
  void start() {
    if (_state == PlaybackState.playing || _state == PlaybackState.paused) {
      return;
    }
    _restart();
    // A route with no length is already at its destination.
    _state = geometry.totalMeters > 0
        ? PlaybackState.playing
        : PlaybackState.finished;
  }

  void pause() {
    if (_state == PlaybackState.playing) _state = PlaybackState.paused;
  }

  void resume() {
    if (_state == PlaybackState.paused) _state = PlaybackState.playing;
  }

  /// Back to the start, not moving.
  void reset() {
    _restart();
    _state = PlaybackState.idle;
  }

  /// Changes the speed (for example 1, 2 or 5). The car keeps its place;
  /// only the following ticks move faster or slower.
  void setMultiplier(int multiplier) {
    if (multiplier <= 0) {
      throw ArgumentError.value(multiplier, 'multiplier', 'must be > 0');
    }
    _multiplier = multiplier;
    // Remaining time depends on the speed, so refresh the frame now.
    _frame = _buildFrame(Duration.zero) ?? _frame;
  }

  /// Advances the car by [dt] (time since the previous frame). Does nothing
  /// unless playing. Returns the new frame.
  NavigationFrame tick(Duration dt) {
    if (_state != PlaybackState.playing) return _frame;

    final step = dt > maxTickStep ? maxTickStep : dt;
    final seconds = step.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return _frame;

    _distance += baseSpeedMps * _multiplier * seconds;
    if (_distance >= geometry.totalMeters) {
      _distance = geometry.totalMeters;
      _state = PlaybackState.finished;
    }

    // If something produced NaN, keep showing the last good frame.
    _frame = _buildFrame(step) ?? _frame;
    return _frame;
  }

  void _restart() {
    _distance = 0;
    _lastTargetHeading = null;
    _smoother.reset();
    _frame = _buildFrame(Duration.zero) ?? _startFrame();
  }

  /// The frame for the current distance, or null if any value isn't finite.
  NavigationFrame? _buildFrame(Duration dt) {
    final total = geometry.totalMeters;
    final remaining = total - _distance;
    final frame = NavigationFrame(
      position: geometry.positionAt(_distance),
      headingDegrees: _smoother.update(
        _targetHeading(),
        dt,
        multiplier: _multiplier,
      ),
      distanceMeters: _distance,
      remainingMeters: remaining,
      remainingSeconds: remaining / (baseSpeedMps * _multiplier),
      progress: total > 0 ? _distance / total : 1,
    );
    return frame.isFinite ? frame : null;
  }

  /// Direction from the car to the point [lookAheadMeters] ahead. Near the
  /// end there's nothing ahead, so the last direction is kept.
  double _targetHeading() {
    final here = geometry.positionAt(_distance);
    final ahead = geometry.positionAt(_distance + lookAheadMeters);
    if (GeoMath.distanceMeters(here, ahead) < _sameSpotMeters) {
      return _lastTargetHeading ?? geometry.bearingAt(_distance);
    }
    final heading = GeoMath.bearingDegrees(here, ahead);
    _lastTargetHeading = heading;
    return heading;
  }

  /// Fallback used only if even the first frame couldn't be computed.
  NavigationFrame _startFrame() => NavigationFrame(
    position: geometry.points.first,
    headingDegrees: 0,
    distanceMeters: 0,
    remainingMeters: 0,
    remainingSeconds: 0,
    progress: 0,
  );
}
