import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/util/formatters.dart';

void main() {
  group('distance', () {
    test('below 1 km shows whole metres', () {
      expect(Formatters.distance(0), '0 m');
      expect(Formatters.distance(12.4), '12 m');
      expect(Formatters.distance(999), '999 m');
    });

    test('1 km boundary', () {
      expect(Formatters.distance(999.4), '999 m');
      expect(Formatters.distance(999.6), '1.0 km', reason: 'never "1000 m"');
      expect(Formatters.distance(1000), '1.0 km');
    });

    test('kilometres with one decimal below 100 km', () {
      expect(Formatters.distance(1250), '1.3 km');
      expect(Formatters.distance(12400), '12.4 km');
      expect(Formatters.distance(99940), '99.9 km');
    });

    test('whole kilometres from 100 km', () {
      expect(Formatters.distance(100000), '100 km');
      expect(Formatters.distance(213400), '213 km');
    });

    test('invalid values show "--"', () {
      expect(Formatters.distance(double.nan), '--');
      expect(Formatters.distance(double.infinity), '--');
      expect(Formatters.distance(-1), '--');
    });
  });

  group('duration', () {
    test('below a minute shows seconds', () {
      expect(Formatters.duration(0), '0 s');
      expect(Formatters.duration(45), '45 s');
      expect(Formatters.duration(59), '59 s');
    });

    test('minute boundary', () {
      expect(Formatters.duration(59.4), '59 s');
      expect(Formatters.duration(59.6), '1 min');
      expect(Formatters.duration(60), '1 min');
    });

    test('minutes, rounded', () {
      expect(Formatters.duration(89), '1 min');
      expect(Formatters.duration(90), '2 min');
      expect(Formatters.duration(23 * 60), '23 min');
    });

    test('hour boundary', () {
      expect(Formatters.duration(3569), '59 min');
      expect(Formatters.duration(3599), '1 h', reason: 'never "60 min"');
      expect(Formatters.duration(3600), '1 h');
    });

    test('hours and minutes', () {
      expect(Formatters.duration(3600 + 5 * 60), '1 h 5 min');
      expect(Formatters.duration(2 * 3600 + 59 * 60), '2 h 59 min');
    });

    test('invalid values show "--"', () {
      expect(Formatters.duration(double.nan), '--');
      expect(Formatters.duration(double.negativeInfinity), '--');
      expect(Formatters.duration(-5), '--');
    });
  });
}
