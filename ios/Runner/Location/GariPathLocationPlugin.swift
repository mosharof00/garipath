import CoreLocation
import Flutter
import UIKit

/// iOS side of the location channels. Same contract as the Android plugin,
/// so the Dart code doesn't know which platform it's talking to.
///
/// iOS differences, mapped to the shared contract:
/// - iOS shows the permission dialog only once. After "Don't Allow" the app
///   can never ask again, so `denied` is reported as `deniedForever`.
/// - iOS also reports `denied` when Location Services are off for the whole
///   device. That case is reported as SERVICES_DISABLED instead.
/// - iOS has no public link to the Location Services screen, so
///   openLocationSettings opens the app's own Settings page.
final class GariPathLocationPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = GariPathLocationPlugin()
    let methods = FlutterMethodChannel(
      name: LocationChannels.method, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: methods)

    let events = FlutterEventChannel(
      name: LocationChannels.events, binaryMessenger: registrar.messenger())
    events.setStreamHandler(plugin.streamHandler)
    registrar.publish(plugin)
  }

  /// Purpose key in Info.plist (NSLocationTemporaryUsageDescriptionDictionary).
  private static let fullAccuracyPurposeKey = "PreciseTripStart"

  /// Cached fixes younger than this are returned right away.
  private static let maxCachedAge: TimeInterval = 30
  /// On timeout, a fix younger than this is still better than nothing.
  private static let maxFallbackAge: TimeInterval = 60

  /// Used for permission and one-shot requests. The stream has its own.
  private let manager = CLLocationManager()
  private let streamHandler = LocationStreamHandler()

  private var pendingPermission: FlutterResult?
  private var pendingLocation: [FlutterResult] = []
  private var locationTimeout: DispatchWorkItem?

  override init() {
    super.init()
    manager.delegate = self
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    streamHandler.stopUpdates()
    locationTimeout?.cancel()
  }

  // MARK: - Method calls

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case LocationMethods.checkPermission:
      replyWithPermission(result)
    case LocationMethods.requestPermission:
      requestPermission(result)
    case LocationMethods.isLocationServiceEnabled:
      checkLocationServicesEnabled { result($0) }
    case LocationMethods.getCurrentLocation:
      let args = call.arguments as? [String: Any]
      guard let timeoutMs = args?[LocationArgs.timeoutMs] as? NSNumber else {
        result(FlutterError(
          code: LocationErrorCodes.invalidArgument, message: "timeoutMs is required", details: nil))
        return
      }
      getCurrentLocation(timeout: timeoutMs.doubleValue / 1000, result: result)
    case LocationMethods.openAppSettings, LocationMethods.openLocationSettings:
      openAppSettings(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Permission

  private var isPrecise: Bool { manager.accuracyAuthorization == .fullAccuracy }

  private func replyWithPermission(_ result: @escaping FlutterResult) {
    switch manager.authorizationStatus {
    case .notDetermined:
      result(permissionMap("notDetermined"))
    case .authorizedWhenInUse, .authorizedAlways:
      result(permissionMap("granted"))
    case .denied, .restricted:
      checkLocationServicesEnabled { enabled in
        if enabled {
          result(self.permissionMap("deniedForever"))
        } else {
          result(self.servicesDisabledError())
        }
      }
    @unknown default:
      result(permissionMap("deniedForever"))
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    switch manager.authorizationStatus {
    case .notDetermined:
      if pendingPermission != nil {
        result(FlutterError(
          code: LocationErrorCodes.requestInProgress,
          message: "A permission request is already showing.", details: nil))
        return
      }
      checkLocationServicesEnabled { enabled in
        // With services off, iOS shows no dialog and never calls back.
        guard enabled else {
          result(self.servicesDisabledError())
          return
        }
        self.pendingPermission = result
        self.manager.requestWhenInUseAuthorization()
      }
    case .authorizedWhenInUse, .authorizedAlways:
      if isPrecise {
        result(permissionMap("granted"))
      } else {
        // "Use precise location": ask for full accuracy for this session.
        manager.requestTemporaryFullAccuracyAuthorization(
          withPurposeKey: Self.fullAccuracyPurposeKey
        ) { _ in
          result(self.permissionMap("granted"))
        }
      }
    default:
      replyWithPermission(result)
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    // Also called once when the manager is created: only a real answer
    // completes a pending request.
    guard manager.authorizationStatus != .notDetermined,
      let result = pendingPermission
    else { return }
    pendingPermission = nil
    replyWithPermission(result)
  }

  private func permissionMap(_ status: String) -> [String: Any] {
    ["status": status, "isPrecise": isPrecise]
  }

  // MARK: - One-shot location

  private func getCurrentLocation(timeout: TimeInterval, result: @escaping FlutterResult) {
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      break
    case .notDetermined:
      result(FlutterError(
        code: LocationErrorCodes.permissionDenied, message: "Permission not granted yet.",
        details: nil))
      return
    default:
      replyWithPermissionError(result)
      return
    }

    checkLocationServicesEnabled { enabled in
      guard enabled else {
        result(self.servicesDisabledError())
        return
      }
      if let cached = self.manager.location,
        -cached.timestamp.timeIntervalSinceNow < Self.maxCachedAge
      {
        result(cached.toChannelMap(isPrecise: self.isPrecise))
        return
      }
      self.pendingLocation.append(result)
      // One request serves everyone waiting.
      if self.pendingLocation.count == 1 {
        self.startOneShot(timeout: timeout)
      }
    }
  }

  private func startOneShot(timeout: TimeInterval) {
    manager.desiredAccuracy = isPrecise ? kCLLocationAccuracyBest : kCLLocationAccuracyReduced
    manager.requestLocation()

    let watchdog = DispatchWorkItem { [weak self] in
      guard let self else { return }
      if let last = self.manager.location,
        -last.timestamp.timeIntervalSinceNow < Self.maxFallbackAge
      {
        self.finishOneShot(with: last.toChannelMap(isPrecise: self.isPrecise))
      } else {
        self.finishOneShot(with: FlutterError(
          code: LocationErrorCodes.timeout, message: "No location fix in time.", details: nil))
      }
    }
    locationTimeout = watchdog
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: watchdog)
  }

  /// Answers every waiting caller exactly once.
  private func finishOneShot(with value: Any) {
    locationTimeout?.cancel()
    locationTimeout = nil
    let waiting = pendingLocation
    pendingLocation = []
    waiting.forEach { $0(value) }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard !pendingLocation.isEmpty, let location = locations.last else { return }
    finishOneShot(with: location.toChannelMap(isPrecise: isPrecise))
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard !pendingLocation.isEmpty else { return }
    if (error as? CLError)?.code == .denied {
      finishOneShot(with: FlutterError(
        code: LocationErrorCodes.permissionDeniedForever, message: error.localizedDescription,
        details: nil))
    } else {
      finishOneShot(with: FlutterError(
        code: LocationErrorCodes.unavailable, message: error.localizedDescription, details: nil))
    }
  }

  // MARK: - Helpers

  private func replyWithPermissionError(_ result: @escaping FlutterResult) {
    checkLocationServicesEnabled { enabled in
      if enabled {
        result(FlutterError(
          code: LocationErrorCodes.permissionDeniedForever,
          message: "Location is denied for this app.", details: nil))
      } else {
        result(self.servicesDisabledError())
      }
    }
  }

  private func servicesDisabledError() -> FlutterError {
    FlutterError(
      code: LocationErrorCodes.servicesDisabled, message: "Location Services are off.",
      details: nil)
  }

  private func openAppSettings(_ result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(url) { opened in result(opened) }
  }
}
