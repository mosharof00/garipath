import CoreLocation
import Flutter

/// Streams location updates to Dart while Dart is listening.
///
/// Dart listen -> `onListen` starts updates. Dart cancel -> `onCancel` stops
/// them. Problems are sent as `FlutterError` events, the same codes Android
/// uses.
final class LocationStreamHandler: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {

  private static let defaultMinDistanceMeters = 5.0

  private let manager = CLLocationManager()
  private var events: FlutterEventSink?

  override init() {
    super.init()
    manager.delegate = self
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    // Never keep two registrations alive.
    stopUpdates()

    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      break
    case .notDetermined:
      return FlutterError(
        code: LocationErrorCodes.permissionDenied, message: "Permission not granted yet.",
        details: nil)
    default:
      return FlutterError(
        code: LocationErrorCodes.permissionDeniedForever,
        message: "Location is denied for this app.", details: nil)
    }

    let args = arguments as? [String: Any]
    let minDistance =
      (args?[LocationArgs.minDistanceMeters] as? NSNumber)?.doubleValue
      ?? Self.defaultMinDistanceMeters

    events = eventSink
    manager.distanceFilter = minDistance
    manager.desiredAccuracy =
      manager.accuracyAuthorization == .fullAccuracy
      ? kCLLocationAccuracyBest : kCLLocationAccuracyReduced
    manager.startUpdatingLocation()
    NSLog("GariPathLocation: updates STARTED (min \(minDistance)m)")

    // If services are off, say so; updates resume by themselves once on.
    checkLocationServicesEnabled { [weak self] enabled in
      if !enabled { self?.sendServicesDisabled() }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopUpdates()
    return nil
  }

  /// Safe to call any number of times.
  func stopUpdates() {
    guard events != nil else { return }
    manager.stopUpdatingLocation()
    events = nil
    NSLog("GariPathLocation: updates STOPPED")
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    events?(location.toChannelMap(isPrecise: manager.accuracyAuthorization == .fullAccuracy))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard events != nil else { return }
    // "Unknown" is temporary (no fix yet); iOS keeps trying.
    if (error as? CLError)?.code == .denied {
      checkLocationServicesEnabled { [weak self] enabled in
        if enabled {
          self?.events?(FlutterError(
            code: LocationErrorCodes.permissionDeniedForever,
            message: "Location was turned off for this app.", details: nil))
          self?.stopUpdates()
        } else {
          self?.sendServicesDisabled()
        }
      }
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard events != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways, .notDetermined:
      break
    default:
      checkLocationServicesEnabled { [weak self] enabled in
        if enabled {
          self?.events?(FlutterError(
            code: LocationErrorCodes.permissionDeniedForever,
            message: "Location was turned off for this app.", details: nil))
          self?.stopUpdates()
        } else {
          self?.sendServicesDisabled()
        }
      }
    }
  }

  private func sendServicesDisabled() {
    events?(FlutterError(
      code: LocationErrorCodes.servicesDisabled, message: "Location Services are off.",
      details: nil))
  }
}
