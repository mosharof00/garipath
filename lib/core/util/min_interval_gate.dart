/// Keeps a minimum time between two starts of something (a throttle).
///
/// The public OSRM server allows about 1 request per second. The debouncer
/// waits for the user to stop; this gate makes sure that even then, two
/// requests never start closer than [minInterval].
class MinIntervalGate {
  MinIntervalGate(this.minInterval, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Duration minInterval;

  /// Injectable so tests can control time.
  final DateTime Function() _now;
  DateTime? _lastStart;

  /// How long to wait before the next start is allowed. Zero if it's fine now.
  Duration get waitTime {
    final lastStart = _lastStart;
    if (lastStart == null) return Duration.zero;

    final remaining = minInterval - _now().difference(lastStart);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Call right when the request starts.
  void markStarted() => _lastStart = _now();
}
