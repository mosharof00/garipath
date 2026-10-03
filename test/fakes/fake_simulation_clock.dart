import 'package:garipath/features/navigation/domain/simulation_clock.dart';

/// Test clock: nothing happens until the test calls [tick].
class FakeSimulationClock implements SimulationClock {
  void Function(Duration dt)? _onTick;
  bool _running = false;
  int startCount = 0;
  bool isDisposed = false;

  @override
  bool get isRunning => _running;

  @override
  void start(void Function(Duration dt) onTick) {
    _onTick = onTick;
    _running = true;
    startCount++;
  }

  @override
  void stop() => _running = false;

  @override
  void dispose() {
    _running = false;
    isDisposed = true;
  }

  /// Simulates one frame. Ignored while stopped, like a real ticker.
  void tick([Duration dt = const Duration(milliseconds: 100)]) {
    if (_running) _onTick?.call(dt);
  }

  void tickTimes(int count, [Duration dt = const Duration(milliseconds: 100)]) {
    for (var i = 0; i < count; i++) {
      tick(dt);
    }
  }
}
