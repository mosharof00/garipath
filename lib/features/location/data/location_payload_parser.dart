import 'package:garipath/features/location/data/location_channel_contract.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/location/domain/location_permission.dart';

/// Turns raw channel values into typed models.
///
/// Native code is trusted but still validated: a bad value returns null
/// instead of crashing, and the caller turns that into a typed error.
abstract final class LocationPayloadParser {
  /// Returns null if [raw] is not a valid location map.
  static LocationFix? parseFix(Object? raw) {
    if (raw is! Map) return null;

    final latitude = _finiteDouble(raw[LocationKeys.latitude]);
    final longitude = _finiteDouble(raw[LocationKeys.longitude]);
    final timestampMs = raw[LocationKeys.timestamp];

    if (latitude == null || longitude == null || timestampMs is! int) {
      return null;
    }
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;

    final isPrecise = raw[LocationKeys.isPrecise];

    return LocationFix(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      accuracyMeters: _finiteDouble(raw[LocationKeys.accuracy]),
      bearingDegrees: _finiteDouble(raw[LocationKeys.bearing]),
      speedMps: _finiteDouble(raw[LocationKeys.speed]),
      isPrecise: isPrecise is bool ? isPrecise : true,
    );
  }

  /// Returns null if [raw] is not a valid permission map.
  static LocationPermission? parsePermission(Object? raw) {
    if (raw is! Map) return null;

    final status = switch (raw[LocationKeys.status]) {
      PermissionStatusValues.notDetermined =>
        LocationPermissionStatus.notDetermined,
      PermissionStatusValues.denied => LocationPermissionStatus.denied,
      PermissionStatusValues.deniedForever =>
        LocationPermissionStatus.deniedForever,
      PermissionStatusValues.granted => LocationPermissionStatus.granted,
      _ => null,
    };
    if (status == null) return null;

    final isPrecise = raw[LocationKeys.isPrecise];
    return LocationPermission(
      status: status,
      isPrecise: isPrecise is bool && isPrecise,
    );
  }

  /// Accepts int or double, rejects NaN, infinity and anything else.
  static double? _finiteDouble(Object? value) {
    if (value is! num) return null;
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }
}
