import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/geo/geo_math.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:latlong2/latlong.dart';

const _speed = 10.0; // m/s, easy to calculate with
const _frame = Duration(milliseconds: 100); // = 1 m at 1x

// About 1.1 km due north, then about 1 km due east.
const _start = LatLng(23.75, 90.40);
const _corner = LatLng(23.76, 90.40);
const _end = LatLng(23.76, 90.41);

RouteAnimator _animator(List<LatLng> points) =>
    RouteAnimator(RouteGeometry.fromPoints(points), baseSpeedMps: _speed);

void _tickTimes(RouteAnimator animator, int count, [Duration dt = _frame]) {
  for (var i = 0; i < count; i++) {
    animator.tick(dt);
  }
}

void main() {
  group('before start', () {
    test('idle at the start, pointing along the route', () {
      final animator = _animator([_start, _corner]);

      expect(animator.state, PlaybackState.idle);
      expect(animator.frame.position, _start);
      expect(animator.frame.headingDegrees, closeTo(0, 0.01)); // north
      expect(animator.frame.progress, 0);
    });

    test('ticks do nothing while idle', () {
      final animator = _animator([_start, _corner]);

      _tickTimes(animator, 10);

      expect(animator.frame.distanceMeters, 0);
    });

    test('speed must be positive', () {
      final geometry = RouteGeometry.fromPoints([_start, _corner]);

      expect(
        () => RouteAnimator(geometry, baseSpeedMps: 0),
        throwsArgumentError,
      );
    });
  });

  group('playing', () {
    test('moves speed x time metres', () {
      final animator = _animator([_start, _corner])..start();

      _tickTimes(animator, 50); // 5 s

      expect(animator.state, PlaybackState.playing);
      expect(animator.frame.distanceMeters, closeTo(50, 1e-9));
    });

    test('remaining distance and time', () {
      final animator = _animator([_start, _corner])..start();
      final total = animator.geometry.totalMeters;

      _tickTimes(animator, 100); // 100 m

      expect(animator.frame.remainingMeters, closeTo(total - 100, 1e-6));
      expect(
        animator.frame.remainingSeconds,
        closeTo((total - 100) / _speed, 1e-6),
      );
      expect(animator.frame.progress, closeTo(100 / total, 1e-9));
    });

    test('finishes exactly at the destination', () {
      final animator = _animator([_start, _corner, _end])..start();

      _tickTimes(animator, 5000);

      expect(animator.state, PlaybackState.finished);
      expect(animator.frame.position, _end);
      expect(animator.frame.remainingMeters, 0);
      expect(animator.frame.remainingSeconds, 0);
      expect(animator.frame.progress, 1);
    });

    test('progress never goes backwards and finishes once', () {
      final animator = _animator([_start, _corner, _end])..start();
      var lastProgress = 0.0;
      var finishedCount = 0;
      var wasFinished = false;

      for (var i = 0; i < 3000; i++) {
        final frame = animator.tick(_frame);
        expect(frame.progress, greaterThanOrEqualTo(lastProgress));
        lastProgress = frame.progress;

        final isFinished = animator.state == PlaybackState.finished;
        if (isFinished && !wasFinished) finishedCount++;
        wasFinished = isFinished;
      }

      expect(finishedCount, 1);
    });

    test('a huge dt is clamped to 0.1 s', () {
      final animator = _animator([_start, _corner])..start();

      animator.tick(const Duration(seconds: 30));

      expect(animator.frame.distanceMeters, closeTo(_speed * 0.1, 1e-9));
    });

    test('heading turns from north to east after the corner', () {
      final animator = _animator([_start, _corner, _end])..start();

      _tickTimes(animator, 1300); // well past the corner (~1112 m)

      expect(animator.frame.headingDegrees, closeTo(90, 1));
    });
  });

  group('controls', () {
    test('pause stops, resume continues from the same place', () {
      final animator = _animator([_start, _corner])..start();
      _tickTimes(animator, 10);

      animator.pause();
      _tickTimes(animator, 10);
      expect(animator.state, PlaybackState.paused);
      expect(animator.frame.distanceMeters, closeTo(10, 1e-9));

      animator.resume();
      _tickTimes(animator, 10);
      expect(animator.frame.distanceMeters, closeTo(20, 1e-9));
    });

    test('reset goes back to the start, idle', () {
      final animator = _animator([_start, _corner])..start();
      _tickTimes(animator, 10);

      animator.reset();

      expect(animator.state, PlaybackState.idle);
      expect(animator.frame.distanceMeters, 0);
      expect(animator.frame.position, _start);
    });

    test('start after finished plays again from the start', () {
      final animator = _animator([_start, _corner])..start();
      _tickTimes(animator, 5000);
      expect(animator.state, PlaybackState.finished);

      animator.start();

      expect(animator.state, PlaybackState.playing);
      expect(animator.frame.distanceMeters, 0);
    });

    test('start while paused does not restart', () {
      final animator = _animator([_start, _corner])..start();
      _tickTimes(animator, 10);
      animator.pause();

      animator.start();

      expect(animator.state, PlaybackState.paused);
      expect(animator.frame.distanceMeters, closeTo(10, 1e-9));
    });
  });

  group('multiplier', () {
    test('changing speed mid-run: no jump, then 5x per tick', () {
      final animator = _animator([_start, _corner])..start();
      _tickTimes(animator, 10);
      final before = animator.frame.distanceMeters;

      animator.setMultiplier(5);
      expect(animator.frame.distanceMeters, before);

      animator.tick(_frame);
      expect(animator.frame.distanceMeters - before, closeTo(5, 1e-9));
    });

    test('remaining time follows the multiplier', () {
      final animator = _animator([_start, _corner]);
      final atOneX = animator.frame.remainingSeconds;

      animator.setMultiplier(2);

      expect(animator.frame.remainingSeconds, closeTo(atOneX / 2, 1e-9));
    });

    test('multiplier must be positive', () {
      final animator = _animator([_start, _corner]);

      expect(() => animator.setMultiplier(0), throwsArgumentError);
    });
  });

  group('degenerate routes', () {
    test('a single point finishes immediately, no NaN', () {
      final animator = _animator([_start])..start();

      expect(animator.state, PlaybackState.finished);
      expect(animator.frame.isFinite, isTrue);
      expect(animator.frame.position, _start);
      expect(animator.frame.progress, 1);
    });

    test('two identical points behave like one point', () {
      final animator = _animator([_start, _start])..start();

      expect(animator.state, PlaybackState.finished);
      expect(animator.frame.isFinite, isTrue);
    });
  });

  test('the car stays on the route line', () {
    final animator = _animator([_start, _corner])..start();

    _tickTimes(animator, 400);

    final position = animator.frame.position;
    expect(position.longitude, closeTo(_start.longitude, 1e-9));
    expect(
      GeoMath.distanceMeters(_start, position),
      closeTo(animator.frame.distanceMeters, 0.5),
    );
  });
}
