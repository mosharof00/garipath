import 'dart:async';

import 'package:garipath/features/location/domain/location_exception.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/location/domain/location_permission.dart';
import 'package:garipath/features/location/domain/location_service.dart';

final sampleFix = LocationFix(
  latitude: 23.7625,
  longitude: 90.4368,
  timestamp: DateTime(2026, 10, 2, 12),
  accuracyMeters: 12,
);

/// A [LocationService] the test fully controls. Set the fields, then check
/// the counters to see what the controller called.
class FakeLocationService implements LocationService {
  /// What [checkPermission] returns.
  LocationPermission permission = const LocationPermission(
    status: LocationPermissionStatus.notDetermined,
  );

  /// What [requestPermission] returns (it also becomes the new [permission]).
  LocationPermission permissionAfterRequest = const LocationPermission(
    status: LocationPermissionStatus.granted,
    isPrecise: true,
  );

  /// [getCurrentLocation] throws this if set, otherwise returns [currentFix].
  LocationException? currentLocationError;
  LocationFix currentFix = sampleFix;

  int requestCount = 0;
  int getCurrentLocationCount = 0;
  int openAppSettingsCount = 0;
  int openLocationSettingsCount = 0;
  int listenCount = 0;
  int cancelCount = 0;

  late final StreamController<LocationFix> _updates =
      StreamController<LocationFix>.broadcast(
        onListen: () => listenCount++,
        onCancel: () => cancelCount++,
      );

  bool get isStreaming => _updates.hasListener;

  void emitFix(LocationFix fix) => _updates.add(fix);
  void emitError(LocationException error) => _updates.addError(error);

  Future<void> dispose() => _updates.close();

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationFix> getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    getCurrentLocationCount++;
    final error = currentLocationError;
    if (error != null) throw error;
    return currentFix;
  }

  @override
  Stream<LocationFix> locationUpdates({
    Duration interval = const Duration(seconds: 2),
    double minDistanceMeters = 5,
  }) => _updates.stream;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCount++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCount++;
    return true;
  }
}
