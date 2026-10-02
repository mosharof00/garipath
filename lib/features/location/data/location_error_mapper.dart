import 'package:flutter/services.dart';
import 'package:garipath/features/location/data/location_channel_contract.dart';
import 'package:garipath/features/location/domain/location_exception.dart';

/// Converts errors coming out of the platform channel into [LocationException]s,
/// so the rest of the app never sees PlatformException or raw strings.
abstract final class LocationErrorMapper {
  static LocationException map(Object error) {
    if (error is LocationException) return error;

    // No native handler registered for the channel (e.g. iOS before the Swift
    // code exists). This is what makes "not supported" work without any
    // platform checks in Dart.
    if (error is MissingPluginException) return const LocationNotSupported();

    if (error is PlatformException) return fromPlatformException(error);

    return LocationUnknownError(error.toString());
  }

  static LocationException fromPlatformException(PlatformException error) {
    final message = error.message;

    return switch (error.code) {
      LocationErrorCodes.permissionDenied => LocationPermissionDenied(message),
      LocationErrorCodes.permissionDeniedForever =>
        LocationPermissionPermanentlyDenied(message),
      LocationErrorCodes.servicesDisabled => LocationServicesDisabled(message),
      LocationErrorCodes.timeout => LocationTimeout(message),
      LocationErrorCodes.unavailable => LocationUnavailable(message),
      LocationErrorCodes.notSupported => LocationNotSupported(message),
      LocationErrorCodes.requestInProgress => LocationRequestInProgress(
        message,
      ),
      LocationErrorCodes.activityUnavailable => LocationActivityUnavailable(
        message,
      ),
      _ => LocationUnknownError(
        message ?? 'Unexpected location error',
        code: error.code,
      ),
    };
  }
}
