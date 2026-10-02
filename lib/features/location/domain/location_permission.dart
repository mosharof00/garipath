enum LocationPermissionStatus {
  /// Never asked yet. Requesting will show the system dialog.
  notDetermined,

  /// The user said no, but we may ask again.
  denied,

  /// The system won't show the dialog anymore. Only Settings can fix it.
  deniedForever,

  /// Allowed (precise or approximate, see [LocationPermission.isPrecise]).
  granted,
}

/// The current permission state as reported by the native side.
class LocationPermission {
  const LocationPermission({required this.status, this.isPrecise = false});

  final LocationPermissionStatus status;

  /// True only when precise (fine) location is granted.
  final bool isPrecise;

  bool get isGranted => status == LocationPermissionStatus.granted;

  @override
  String toString() => 'LocationPermission($status, precise: $isPrecise)';
}
