import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/location/domain/location_permission.dart';

/// Everything the app needs from the device's location system.
///
/// The rest of the app depends only on this interface, never on platform
/// channels. Every method throws a `LocationException` subtype on failure.
abstract interface class LocationService {
  /// Current permission state. Never shows a dialog.
  Future<LocationPermission> checkPermission();

  /// Shows the system permission dialog when the platform allows it.
  Future<LocationPermission> requestPermission();

  /// Whether the device location switch is on.
  Future<bool> isLocationServiceEnabled();

  /// A single fresh position. Does not ask for permission by itself.
  Future<LocationFix> getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
  });

  /// Continuous updates. Errors arrive as `LocationException`s and do not end
  /// the stream. Cancelling the subscription stops the native updates.
  Stream<LocationFix> locationUpdates({
    Duration interval = const Duration(seconds: 2),
    double minDistanceMeters = 5,
  });

  /// Opens this app's page in the system Settings.
  Future<bool> openAppSettings();

  /// Opens the device location settings.
  Future<bool> openLocationSettings();
}
