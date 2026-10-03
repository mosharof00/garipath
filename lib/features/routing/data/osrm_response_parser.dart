import 'package:garipath/core/geo/polyline_codec.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:latlong2/latlong.dart';

/// Turns a decoded OSRM JSON body into a [RouteModel].
///
/// Never trusts the server: every field is type-checked and validated.
/// Problems are thrown as [RouteFailure]s, never as a crash.
abstract final class OsrmResponseParser {
  /// Throws [RouteNoRoute] when OSRM says there is no road between the
  /// points, and [RouteInvalidResponse] for anything malformed.
  static RouteModel parse(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const RouteInvalidResponse('Body is not a JSON object');
    }

    final code = json['code'];
    if (code == 'NoRoute' || code == 'NoSegment') {
      throw RouteNoRoute('OSRM code $code');
    }
    if (code != 'Ok') {
      throw RouteInvalidResponse('Unexpected OSRM code: $code');
    }

    final routes = json['routes'];
    if (routes is! List<Object?>) {
      throw const RouteInvalidResponse('Missing routes list');
    }
    if (routes.isEmpty) {
      throw const RouteNoRoute('OSRM returned no routes');
    }
    final route = routes.first;
    if (route is! Map<String, Object?>) {
      throw const RouteInvalidResponse('Route is not a JSON object');
    }

    final distance = _readAmount(route, 'distance');
    final duration = _readAmount(route, 'duration');

    final geometry = route['geometry'];
    if (geometry is! String) {
      throw const RouteInvalidResponse('Missing route geometry');
    }
    final List<LatLng> points;
    try {
      points = PolylineCodec.decode(geometry);
    } on FormatException catch (e) {
      throw RouteInvalidResponse('Bad polyline: ${e.message}');
    }
    if (points.length < 2) {
      throw const RouteInvalidResponse('Route has fewer than 2 points');
    }

    return RouteModel(
      points: points,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }

  /// A JSON number that must be finite and not negative.
  static double _readAmount(Map<String, Object?> route, String key) {
    final value = route[key];
    if (value is! num || !value.isFinite || value < 0) {
      throw RouteInvalidResponse('Invalid route $key: $value');
    }
    return value.toDouble();
  }
}
