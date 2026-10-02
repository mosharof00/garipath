import 'package:latlong2/latlong.dart';

enum AppFlavor { dev, prod }

/// Everything that differs between the dev and prod builds.
///
/// The app reads settings like the routing server only from here, so pointing
/// a flavor at another server is a one-line change in its config file.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.applicationId,
    required this.osrmBaseUrl,
    required this.showDevBanner,
    this.simulationSpeedMps = 13.9,
    this.locationTimeout = const Duration(seconds: 15),
    this.defaultMapCenter = const LatLng(23.8103, 90.4125),
  });

  final AppFlavor flavor;
  final String appName;

  /// Android application id. Also sent to the OSM tile server as the user agent.
  final String applicationId;

  /// Base URL of the OSRM routing server, without a trailing slash.
  final String osrmBaseUrl;

  final bool showDevBanner;

  /// Speed of the simulated car at 1x (13.9 m/s is about 50 km/h).
  final double simulationSpeedMps;

  /// How long to wait for the first GPS fix before giving up.
  final Duration locationTimeout;

  /// Where the map starts before the user's location is known (Dhaka).
  final LatLng defaultMapCenter;
}
