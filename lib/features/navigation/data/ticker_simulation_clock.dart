import 'package:flutter/scheduler.dart';
import 'package:garipath/features/navigation/domain/simulation_clock.dart';

/// [SimulationClock] driven by a Flutter [Ticker], which fires once per
/// screen frame.
///
/// A Ticker reports the total time since it started (`elapsed`). This class
/// turns that into the time since the previous frame.
class TickerSimulationClock implements SimulationClock {
  TickerSimulationClock() {
    _ticker = Ticker(_onFrame, debugLabel: 'GariPath simulation');
  }

  late final Ticker _ticker;
  void Function(Duration dt)? _onTick;
  Duration _lastElapsed = Duration.zero;

  @override
  bool get isRunning => _ticker.isActive;

  @override
  void start(void Function(Duration dt) onTick) {
    _onTick = onTick;
    if (_ticker.isActive) return;
    _lastElapsed = Duration.zero; // elapsed restarts at 0 with the ticker
    _ticker.start();
  }

  @override
  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _onTick = null;
    _ticker.dispose();
  }

  void _onFrame(Duration elapsed) {
    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _onTick?.call(dt);
  }
}
