/// One position reported by the device.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracyMeters,
    this.bearingDegrees,
    this.speedMps,
    this.isPrecise = true,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  /// Horizontal accuracy radius in metres, if the platform reported it.
  final double? accuracyMeters;

  /// Direction of travel (0 = north, clockwise), if the platform reported it.
  final double? bearingDegrees;

  /// Speed in metres per second, if the platform reported it.
  final double? speedMps;

  /// False when the user granted only approximate location.
  final bool isPrecise;

  /// How old this fix is compared to [now].
  Duration age(DateTime now) => now.difference(timestamp);

  @override
  String toString() =>
      'LocationFix($latitude, $longitude, ±${accuracyMeters ?? '?'} m, '
      'precise: $isPrecise)';
}
