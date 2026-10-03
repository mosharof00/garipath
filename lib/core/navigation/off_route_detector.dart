/// Decides when the device has really left the route.
///
/// One bad GPS fix must not trigger a new route, so it needs
/// [requiredFixes] fixes in a row farther than [thresholdMeters], each
/// accurate enough to trust. After a reroute it waits [cooldown] before
/// allowing another, to protect the routing server.
class OffRouteDetector {
  OffRouteDetector({
    this.thresholdMeters = 50,
    this.maxAccuracyMeters = 50,
    this.requiredFixes = 3,
    this.cooldown = const Duration(seconds: 30),
  });

  final double thresholdMeters;
  final double maxAccuracyMeters;
  final int requiredFixes;
  final Duration cooldown;

  int _offRouteCount = 0;
  DateTime? _lastReroute;

  /// Returns true when a reroute should start now.
  bool update({
    required double offsetMeters,
    required double? accuracyMeters,
    required DateTime now,
  }) {
    // An inaccurate fix says nothing either way: ignore it.
    if (accuracyMeters == null || accuracyMeters > maxAccuracyMeters) {
      return false;
    }
    if (offsetMeters <= thresholdMeters) {
      _offRouteCount = 0;
      return false;
    }

    _offRouteCount++;
    if (_offRouteCount < requiredFixes) return false;

    final last = _lastReroute;
    if (last != null && now.difference(last) < cooldown) return false;

    _offRouteCount = 0;
    _lastReroute = now;
    return true;
  }

  /// Start counting again (new route, mode change). The cooldown is kept.
  void resetCount() => _offRouteCount = 0;
}
