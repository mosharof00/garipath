import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/features/location/data/location_payload_parser.dart';
import 'package:garipath/features/location/domain/location_permission.dart';

void main() {
  group('parseFix', () {
    Map<String, Object?> validMap() => {
      'lat': 23.8103,
      'lng': 90.4125,
      'accuracy': 12.5,
      'bearing': 90.0,
      'speed': 3.2,
      'timestamp': 1759400000000,
      'isPrecise': true,
    };

    test('parses a complete location map', () {
      final fix = LocationPayloadParser.parseFix(validMap())!;

      expect(fix.latitude, 23.8103);
      expect(fix.longitude, 90.4125);
      expect(fix.accuracyMeters, 12.5);
      expect(fix.bearingDegrees, 90.0);
      expect(fix.speedMps, 3.2);
      expect(fix.timestamp.millisecondsSinceEpoch, 1759400000000);
      expect(fix.isPrecise, isTrue);
    });

    test('accepts ints for coordinates and leaves optional values null', () {
      final fix = LocationPayloadParser.parseFix({
        'lat': 23,
        'lng': 90,
        'timestamp': 1759400000000,
      })!;

      expect(fix.latitude, 23.0);
      expect(fix.accuracyMeters, isNull);
      expect(fix.bearingDegrees, isNull);
      expect(fix.speedMps, isNull);
      expect(fix.isPrecise, isTrue);
    });

    test('reads approximate location', () {
      final fix = LocationPayloadParser.parseFix(
        validMap()..['isPrecise'] = false,
      )!;
      expect(fix.isPrecise, isFalse);
    });

    test('rejects values that are not a map', () {
      expect(LocationPayloadParser.parseFix(null), isNull);
      expect(LocationPayloadParser.parseFix('23.8,90.4'), isNull);
      expect(LocationPayloadParser.parseFix([23.8, 90.4]), isNull);
    });

    test('rejects missing or wrongly typed required keys', () {
      expect(LocationPayloadParser.parseFix(validMap()..remove('lat')), isNull);
      expect(LocationPayloadParser.parseFix(validMap()..remove('lng')), isNull);
      expect(
        LocationPayloadParser.parseFix(validMap()..remove('timestamp')),
        isNull,
      );
      expect(
        LocationPayloadParser.parseFix(validMap()..['lat'] = '23.8'),
        isNull,
      );
    });

    test('rejects NaN and infinite coordinates', () {
      expect(
        LocationPayloadParser.parseFix(validMap()..['lat'] = double.nan),
        isNull,
      );
      expect(
        LocationPayloadParser.parseFix(validMap()..['lng'] = double.infinity),
        isNull,
      );
    });

    test('rejects coordinates outside the valid range', () {
      expect(LocationPayloadParser.parseFix(validMap()..['lat'] = 91), isNull);
      expect(
        LocationPayloadParser.parseFix(validMap()..['lng'] = -181),
        isNull,
      );
    });

    test('drops a NaN optional value instead of rejecting the fix', () {
      final fix = LocationPayloadParser.parseFix(
        validMap()..['bearing'] = double.nan,
      )!;
      expect(fix.bearingDegrees, isNull);
    });
  });

  group('parsePermission', () {
    test('parses every status', () {
      const expected = {
        'notDetermined': LocationPermissionStatus.notDetermined,
        'denied': LocationPermissionStatus.denied,
        'deniedForever': LocationPermissionStatus.deniedForever,
        'granted': LocationPermissionStatus.granted,
      };

      expected.forEach((raw, status) {
        final permission = LocationPayloadParser.parsePermission({
          'status': raw,
        });
        expect(permission?.status, status, reason: raw);
      });
    });

    test('reads precise and approximate grants', () {
      final precise = LocationPayloadParser.parsePermission({
        'status': 'granted',
        'isPrecise': true,
      })!;
      final approximate = LocationPayloadParser.parsePermission({
        'status': 'granted',
        'isPrecise': false,
      })!;

      expect(precise.isGranted, isTrue);
      expect(precise.isPrecise, isTrue);
      expect(approximate.isGranted, isTrue);
      expect(approximate.isPrecise, isFalse);
    });

    test('rejects unknown status values and non-maps', () {
      expect(
        LocationPayloadParser.parsePermission({'status': 'maybe'}),
        isNull,
      );
      expect(LocationPayloadParser.parsePermission({}), isNull);
      expect(LocationPayloadParser.parsePermission('granted'), isNull);
    });
  });
}
