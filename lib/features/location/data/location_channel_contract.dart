/// The contract between Dart and the native location code.
///
/// Kotlin (and later Swift) must use exactly these names, keys and codes.
/// Nothing here is Android-specific, so an iOS implementation can be added
/// without changing any Dart code.
library;

abstract final class LocationChannels {
  /// Request/response calls (permission, one-shot location, settings).
  static const method = 'com.mosharof.garipath/location';

  /// Continuous location updates.
  static const events = 'com.mosharof.garipath/location_updates';
}

abstract final class LocationMethods {
  /// Returns a permission map. Never shows a dialog.
  static const checkPermission = 'checkPermission';

  /// Shows the system dialog if possible. Returns a permission map.
  static const requestPermission = 'requestPermission';

  /// Returns a bool: is the device location switch on.
  static const isLocationServiceEnabled = 'isLocationServiceEnabled';

  /// Args: [LocationArgs.timeoutMs]. Returns a location map. Never prompts.
  static const getCurrentLocation = 'getCurrentLocation';

  /// Opens this app's page in system Settings. Returns a bool.
  static const openAppSettings = 'openAppSettings';

  /// Opens the device location settings. Returns a bool.
  static const openLocationSettings = 'openLocationSettings';
}

abstract final class LocationArgs {
  static const timeoutMs = 'timeoutMs';
  static const intervalMs = 'intervalMs';
  static const minDistanceMeters = 'minDistanceMeters';
}

/// Keys of the maps sent from native code to Dart.
abstract final class LocationKeys {
  // Location map
  static const latitude = 'lat';
  static const longitude = 'lng';
  static const accuracy = 'accuracy';
  static const bearing = 'bearing';
  static const speed = 'speed';
  static const timestamp = 'timestamp';
  static const isPrecise = 'isPrecise';

  // Permission map (also uses isPrecise)
  static const status = 'status';
}

/// Values of [LocationKeys.status].
abstract final class PermissionStatusValues {
  static const notDetermined = 'notDetermined';
  static const denied = 'denied';
  static const deniedForever = 'deniedForever';
  static const granted = 'granted';
}

/// `PlatformException.code` values sent by native code.
abstract final class LocationErrorCodes {
  static const permissionDenied = 'PERMISSION_DENIED';
  static const permissionDeniedForever = 'PERMISSION_DENIED_FOREVER';
  static const servicesDisabled = 'SERVICES_DISABLED';
  static const timeout = 'TIMEOUT';
  static const unavailable = 'LOCATION_UNAVAILABLE';
  static const requestInProgress = 'REQUEST_IN_PROGRESS';
  static const activityUnavailable = 'ACTIVITY_UNAVAILABLE';
  static const notSupported = 'NOT_SUPPORTED';
  static const invalidArgument = 'INVALID_ARGUMENT';
  static const unknown = 'UNKNOWN';
}
