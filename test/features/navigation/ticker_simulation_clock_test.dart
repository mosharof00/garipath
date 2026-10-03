import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/features/navigation/data/ticker_simulation_clock.dart';

void main() {
  testWidgets('reports time between frames, fresh after a restart', (
    tester,
  ) async {
    final clock = TickerSimulationClock();
    final deltas = <Duration>[];

    clock.start(deltas.add);
    await tester.pump(); // first frame: elapsed 0
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 20));
    expect(deltas, [
      Duration.zero,
      const Duration(milliseconds: 16),
      const Duration(milliseconds: 20),
    ]);

    clock.stop();
    expect(clock.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 30)); // stopped: no ticks

    deltas.clear();
    clock.start(deltas.add);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // The 30 s spent stopped is not reported as one huge step.
    expect(deltas, [Duration.zero, const Duration(milliseconds: 16)]);

    clock.dispose();
  });
}
