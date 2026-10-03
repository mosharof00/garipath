import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/navigation/heading_smoother.dart';

const _frame = Duration(milliseconds: 16);

void main() {
  test('the first update jumps to the target (no spin on appear)', () {
    final smoother = HeadingSmoother();

    expect(smoother.current, isNull);
    expect(smoother.update(90, _frame), 90);
  });

  test('350 -> 10 turns through 0, never through 180', () {
    final smoother = HeadingSmoother()..update(350, _frame);

    for (var i = 0; i < 100; i++) {
      final heading = smoother.update(10, _frame);
      final onShortPath = heading >= 350 || heading <= 10;
      expect(onShortPath, isTrue, reason: 'frame $i: $heading');
    }
  });

  test('converges to the target', () {
    final smoother = HeadingSmoother()..update(0, _frame);

    for (var i = 0; i < 120; i++) {
      smoother.update(120, _frame);
    }

    expect(smoother.current, closeTo(120, 0.01));
  });

  test('never overshoots the target', () {
    final smoother = HeadingSmoother()..update(0, _frame);

    for (var i = 0; i < 200; i++) {
      expect(smoother.update(45, _frame), lessThanOrEqualTo(45));
    }
  });

  test('same turn after 1 s at 60 fps and at 30 fps', () {
    final fast = HeadingSmoother()..update(0, _frame);
    final slow = HeadingSmoother()..update(0, _frame);

    for (var i = 0; i < 6; i++) {
      fast.update(90, const Duration(microseconds: 16667));
    }
    for (var i = 0; i < 3; i++) {
      slow.update(90, const Duration(microseconds: 33333));
    }

    expect(fast.current, closeTo(slow.current!, 0.01));
  });

  test('a higher multiplier turns faster', () {
    final normal = HeadingSmoother()..update(0, _frame);
    final fast = HeadingSmoother()..update(0, _frame);

    normal.update(90, _frame);
    fast.update(90, _frame, multiplier: 5);

    expect(fast.current, greaterThan(normal.current!));
  });

  test('zero dt keeps the heading', () {
    final smoother = HeadingSmoother()..update(30, _frame);

    expect(smoother.update(200, Duration.zero), 30);
  });

  test('reset: the next update jumps again', () {
    final smoother = HeadingSmoother()..update(30, _frame);

    smoother.reset();

    expect(smoother.update(200, _frame), 200);
  });
}
