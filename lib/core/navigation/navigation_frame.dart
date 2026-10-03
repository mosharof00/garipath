import 'package:latlong2/latlong.dart';

/// Everything the UI needs to draw one moment of the trip.
class NavigationFrame {
  const NavigationFrame({
    required this.position,
    required this.headingDegrees,
    required this.distanceMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.progress,
  });

  /// Where the car is.
  final LatLng position;

  /// Which way the car points, in degrees [0, 360). 0 = north.
  final double headingDegrees;

  /// Distance driven from the start.
  final double distanceMeters;

  /// Distance left to the destination.
  final double remainingMeters;

  /// Time left at the current simulated speed (reacts to 1x/2x/5x).
  final double remainingSeconds;

  /// 0 at the start, 1 at the destination.
  final double progress;

  /// False if any number is NaN or infinite. Such a frame is never shown.
  bool get isFinite =>
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      headingDegrees.isFinite &&
      distanceMeters.isFinite &&
      remainingMeters.isFinite &&
      remainingSeconds.isFinite &&
      progress.isFinite;
}
