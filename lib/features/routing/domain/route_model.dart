import 'package:latlong2/latlong.dart';

/// A driving route returned by the routing server.
class RouteModel {
  const RouteModel({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// The road path from start to destination, in lat, lng order.
  final List<LatLng> points;

  /// Total driving distance according to the server.
  final double distanceMeters;

  /// The server's real-world travel time estimate (shown on the route card).
  final double durationSeconds;

  @override
  String toString() =>
      'RouteModel(${points.length} points, ${distanceMeters.round()} m, '
      '${durationSeconds.round()} s)';
}
