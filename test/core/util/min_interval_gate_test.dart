import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/util/min_interval_gate.dart';

void main() {
  var now = DateTime(2026, 10, 3, 12);
  late MinIntervalGate gate;

  setUp(() {
    now = DateTime(2026, 10, 3, 12);
    gate = MinIntervalGate(const Duration(milliseconds: 1100), now: () => now);
  });

  test('the first start never waits', () {
    expect(gate.waitTime, Duration.zero);
  });

  test('right after a start, waits the full interval', () {
    gate.markStarted();

    expect(gate.waitTime, const Duration(milliseconds: 1100));
  });

  test('waits only the remaining part of the interval', () {
    gate.markStarted();
    now = now.add(const Duration(milliseconds: 400));

    expect(gate.waitTime, const Duration(milliseconds: 700));
  });

  test('no wait once the interval has passed', () {
    gate.markStarted();
    now = now.add(const Duration(seconds: 5));

    expect(gate.waitTime, Duration.zero);
  });
}
