import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/features/routing/data/osrm_response_parser.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';

/// Reads a JSON file from test/fixtures.
Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync());

/// A minimal valid OSRM body that tests can break one field at a time.
Map<String, Object?> okBody({
  Object? code = 'Ok',
  Object? geometry = '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
  Object? distance = 1000.0,
  Object? duration = 120.0,
}) => {
  'code': code,
  'routes': [
    {'geometry': geometry, 'distance': distance, 'duration': duration},
  ],
};

void main() {
  group('real OSRM responses', () {
    test('Ok response for a route in Dhaka', () {
      final route = OsrmResponseParser.parse(fixture('osrm_ok.json'));

      expect(route.distanceMeters, 4444.5);
      expect(route.durationSeconds, 350.5);
      expect(route.points.length, greaterThan(2));
      // The route starts and ends near the requested points (lat, lng order).
      expect(route.points.first.latitude, closeTo(23.7625, 0.01));
      expect(route.points.first.longitude, closeTo(90.4368, 0.01));
      expect(route.points.last.latitude, closeTo(23.75, 0.01));
      expect(route.points.last.longitude, closeTo(90.425, 0.01));
    });

    test('NoRoute -> RouteNoRoute', () {
      expect(
        () => OsrmResponseParser.parse(fixture('osrm_no_route.json')),
        throwsA(isA<RouteNoRoute>()),
      );
    });

    test('NoSegment -> RouteNoRoute', () {
      expect(
        () => OsrmResponseParser.parse(fixture('osrm_no_segment.json')),
        throwsA(isA<RouteNoRoute>()),
      );
    });
  });

  test('a valid minimal body parses', () {
    final route = OsrmResponseParser.parse(okBody());

    expect(route.points, hasLength(3));
    expect(route.distanceMeters, 1000);
  });

  test('integer distance and duration are accepted', () {
    final route = OsrmResponseParser.parse(
      okBody(distance: 1000, duration: 60),
    );

    expect(route.durationSeconds, 60.0);
  });

  test('Ok with an empty routes list -> RouteNoRoute', () {
    expect(
      () => OsrmResponseParser.parse({'code': 'Ok', 'routes': <Object?>[]}),
      throwsA(isA<RouteNoRoute>()),
    );
  });

  group('malformed responses -> RouteInvalidResponse', () {
    void expectInvalid(Object? body) {
      expect(
        () => OsrmResponseParser.parse(body),
        throwsA(isA<RouteInvalidResponse>()),
      );
    }

    test('not a JSON object', () {
      expectInvalid(null);
      expectInvalid('Ok');
      expectInvalid(<Object?>[]);
    });

    test('unknown code', () => expectInvalid(okBody(code: 'InvalidQuery')));

    test('missing or wrong-typed routes', () {
      expectInvalid({'code': 'Ok'});
      expectInvalid({'code': 'Ok', 'routes': 'nope'});
      expectInvalid({
        'code': 'Ok',
        'routes': ['nope'],
      });
    });

    test('bad distance', () {
      expectInvalid(okBody(distance: null));
      expectInvalid(okBody(distance: '1000'));
      expectInvalid(okBody(distance: -1));
      expectInvalid(okBody(distance: double.nan));
      expectInvalid(okBody(distance: double.infinity));
    });

    test('bad duration', () => expectInvalid(okBody(duration: null)));

    test('missing geometry', () => expectInvalid(okBody(geometry: null)));

    test('broken polyline', () => expectInvalid(okBody(geometry: '_p~iF')));

    test('fewer than 2 points', () {
      expectInvalid(okBody(geometry: ''));
      expectInvalid(okBody(geometry: '_p~iF~ps|U'));
    });
  });
}
