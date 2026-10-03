import CoreLocation
import Flutter

/// Must match lib/features/location/data/location_channel_contract.dart.
enum LocationChannels {
  static let method = "com.mosharof.garipath/location"
  static let events = "com.mosharof.garipath/location_updates"
}

enum LocationMethods {
  static let checkPermission = "checkPermission"
  static let requestPermission = "requestPermission"
  static let isLocationServiceEnabled = "isLocationServiceEnabled"
  static let getCurrentLocation = "getCurrentLocation"
  static let openAppSettings = "openAppSettings"
  static let openLocationSettings = "openLocationSettings"
}

enum LocationArgs {
  static let timeoutMs = "timeoutMs"
  static let minDistanceMeters = "minDistanceMeters"
}

enum LocationErrorCodes {
  static let permissionDenied = "PERMISSION_DENIED"
  static let permissionDeniedForever = "PERMISSION_DENIED_FOREVER"
  static let servicesDisabled = "SERVICES_DISABLED"
  static let timeout = "TIMEOUT"
  static let unavailable = "LOCATION_UNAVAILABLE"
  static let requestInProgress = "REQUEST_IN_PROGRESS"
  static let invalidArgument = "INVALID_ARGUMENT"
}

extension CLLocation {
  /// The map Dart's LocationPayloadParser expects.
  func toChannelMap(isPrecise: Bool) -> [String: Any] {
    var map: [String: Any] = [
      "lat": coordinate.latitude,
      "lng": coordinate.longitude,
      "accuracy": horizontalAccuracy,
      "timestamp": Int(timestamp.timeIntervalSince1970 * 1000),
      "isPrecise": isPrecise,
    ]
    // CoreLocation uses negative values for "unknown".
    if course >= 0 { map["bearing"] = course }
    if speed >= 0 { map["speed"] = speed }
    return map
  }
}

/// Location services can only be checked off the main thread without a
/// warning, so the answer comes back through a callback on the main thread.
func checkLocationServicesEnabled(_ completion: @escaping (Bool) -> Void) {
  DispatchQueue.global(qos: .userInitiated).async {
    let enabled = CLLocationManager.locationServicesEnabled()
    DispatchQueue.main.async { completion(enabled) }
  }
}
