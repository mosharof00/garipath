import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/geo/polyline_codec.dart';

void main() {
  test("Google's reference example", () {
    // From Google's "Encoded Polyline Algorithm Format" documentation.
    final points = PolylineCodec.decode('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 1e-9));
    expect(points[0].longitude, closeTo(-120.2, 1e-9));
    expect(points[1].latitude, closeTo(40.7, 1e-9));
    expect(points[1].longitude, closeTo(-120.95, 1e-9));
    expect(points[2].latitude, closeTo(43.252, 1e-9));
    expect(points[2].longitude, closeTo(-126.453, 1e-9));
  });

  test('a single point in Dhaka', () {
    // 23.8103, 90.4125 encoded with precision 5.
    final points = PolylineCodec.decode('kmipCcuyfP');

    expect(points, hasLength(1));
    expect(points[0].latitude, closeTo(23.8103, 1e-9));
    expect(points[0].longitude, closeTo(90.4125, 1e-9));
  });

  test('empty text gives no points', () {
    expect(PolylineCodec.decode(''), isEmpty);
  });

  test('repeated points decode as repeated (dedupe happens later)', () {
    // Same point twice: the second one is a zero difference "??".
    final points = PolylineCodec.decode('_p~iF~ps|U??');

    expect(points, hasLength(2));
    expect(points[1], points[0]);
  });

  test('precision 6 divides by 1e6', () {
    // 38.5, -120.2 at precision 6.
    final points = PolylineCodec.decode('_izlhA~rlgdF', precision: 6);

    expect(points.single.latitude, closeTo(38.5, 1e-9));
    expect(points.single.longitude, closeTo(-120.2, 1e-9));
  });

  group('broken input throws FormatException', () {
    test('cut off in the middle of a number', () {
      // "_p~iF~ps|" is missing the last chunk of the longitude.
      expect(
        () => PolylineCodec.decode('_p~iF~ps|'),
        throwsA(isA<FormatException>()),
      );
    });

    test('latitude with no longitude', () {
      expect(
        () => PolylineCodec.decode('_p~iF'),
        throwsA(isA<FormatException>()),
      );
    });

    test('character below "?" (code 63)', () {
      expect(
        () => PolylineCodec.decode('_p~iF ps|U'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a number that never ends', () {
      expect(
        () => PolylineCodec.decode('~' * 20),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('a long route decodes every point', () {
    // 1,000 steps of +0.00001 lat ("A") and 0 lng ("?").
    final encoded = '_p~iF~ps|U${'A?' * 1000}';

    final points = PolylineCodec.decode(encoded);

    expect(points, hasLength(1001));
    expect(points.last.latitude, closeTo(38.5 + 0.01, 1e-9));
    expect(points.last.longitude, closeTo(-120.2, 1e-9));
  });
}
