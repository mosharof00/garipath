import 'package:latlong2/latlong.dart';

/// Builds OSRM route request URLs.
///
/// OSRM wants coordinates as **longitude,latitude**: the opposite of the
/// lat, lng order used everywhere else in the app. Keeping that in this one
/// place means it can only be wrong in one place, and a test guards it.
abstract final class OsrmUrlBuilder {
  static const profile = 'driving';

  /// For example:
  /// `https://router.project-osrm.org/route/v1/driving/90.412500,23.810300;91.783200,22.356900?overview=full&...`
  static String route({
    required String baseUrl,
    required LatLng start,
    required LatLng destination,
  }) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final coordinates = '${_coordinate(start)};${_coordinate(destination)}';

    return '$base/route/v1/$profile/$coordinates'
        '?overview=full' // the whole road shape, not a simplified one
        '&geometries=polyline' // encoded polyline, precision 5
        '&alternatives=false'
        '&steps=false'; // no turn-by-turn instructions needed
  }

  /// "lng,lat" with 6 decimals (about 10 cm). toStringAsFixed never uses
  /// scientific notation like 1e-7 and always uses "." as the separator.
  static String _coordinate(LatLng point) =>
      '${point.longitude.toStringAsFixed(6)},'
      '${point.latitude.toStringAsFixed(6)}';
}
