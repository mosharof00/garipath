/// Calls back once per frame with the time since the previous frame.
///
/// An interface so tests can push exact time steps instead of waiting for
/// real frames.
abstract interface class SimulationClock {
  bool get isRunning;

  /// Starts ticking. The first tick after every start counts from that
  /// start, so time spent stopped (paused, in the background) is never
  /// added in one big jump.
  void start(void Function(Duration dt) onTick);

  void stop();

  void dispose();
}
