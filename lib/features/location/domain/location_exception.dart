/// Every way getting the location can fail.
///
/// The class is `sealed`, so a `switch` over it must handle every case. The
/// compiler tells us if the UI forgets one. The UI decides what text to show
/// from the type; [message] is only for logs.
sealed class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The user said no, but we may ask again.
class LocationPermissionDenied extends LocationException {
  const LocationPermissionDenied([String? message])
    : super(message ?? 'Location permission denied');
}

/// The system won't show the dialog anymore. Only Settings can fix it.
class LocationPermissionPermanentlyDenied extends LocationException {
  const LocationPermissionPermanentlyDenied([String? message])
    : super(message ?? 'Location permission permanently denied');
}

/// The device location switch is off.
class LocationServicesDisabled extends LocationException {
  const LocationServicesDisabled([String? message])
    : super(message ?? 'Location services are disabled');
}

/// No position arrived in time.
class LocationTimeout extends LocationException {
  const LocationTimeout([String? message])
    : super(message ?? 'Timed out waiting for a location');
}

/// The platform answered but had no position to give (not a timeout).
class LocationUnavailable extends LocationException {
  const LocationUnavailable([String? message])
    : super(message ?? 'Location is unavailable');
}

/// This platform has no native location implementation.
class LocationNotSupported extends LocationException {
  const LocationNotSupported([String? message])
    : super(message ?? 'Location is not supported on this platform');
}

/// A permission request is already showing.
class LocationRequestInProgress extends LocationException {
  const LocationRequestInProgress([String? message])
    : super(message ?? 'A permission request is already in progress');
}

/// The native side needed a visible screen (Activity) and had none.
class LocationActivityUnavailable extends LocationException {
  const LocationActivityUnavailable([String? message])
    : super(message ?? 'No foreground activity to show the request');
}

/// Anything we didn't expect. [code] keeps the original native code for logs.
class LocationUnknownError extends LocationException {
  const LocationUnknownError(super.message, {this.code});

  final String? code;
}
