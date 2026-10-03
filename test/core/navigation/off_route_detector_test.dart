import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/navigation/off_route_detector.dart';

void main() {
  late OffRouteDetector detector;
  final t0 = DateTime(2026, 10, 3, 12);

  setUp(() => detector = OffRouteDetector());

  bool far({double accuracy = 10, Duration at = Duration.zero}) => detector
      .update(offsetMeters: 80, accuracyMeters: accuracy, now: t0.add(at));

  bool near() => detector.update(offsetMeters: 10, accuracyMeters: 10, now: t0);

  test('one bad fix does not trigger a reroute', () {
    expect(far(), isFalse);
  });

  test('three far fixes in a row trigger a reroute', () {
    expect(far(), isFalse);
    expect(far(), isFalse);
    expect(far(), isTrue);
  });

  test('a fix back on the route starts counting again', () {
    far();
    far();
    near();

    expect(far(), isFalse);
    expect(far(), isFalse);
    expect(far(), isTrue);
  });

  test('inaccurate or unknown-accuracy fixes are ignored', () {
    far();
    far();

    expect(far(accuracy: 120), isFalse);
    expect(
      detector.update(offsetMeters: 80, accuracyMeters: null, now: t0),
      isFalse,
    );
    // They did not reset the count either.
    expect(far(), isTrue);
  });

  test('cooldown: no second reroute within 30 s', () {
    far();
    far();
    expect(far(), isTrue);

    far(at: const Duration(seconds: 10));
    far(at: const Duration(seconds: 11));
    expect(far(at: const Duration(seconds: 12)), isFalse);

    // Still off the route when the cooldown ends: reroute right away.
    expect(far(at: const Duration(seconds: 31)), isTrue);
  });
}
