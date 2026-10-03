import 'dart:async';

import 'package:get/get.dart';
import 'package:garipath/core/geo/geo_math.dart';
import 'package:garipath/core/logging/app_logger.dart';
import 'package:garipath/core/util/cancel_signal.dart';
import 'package:garipath/core/util/debouncer.dart';
import 'package:garipath/core/util/min_interval_gate.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:garipath/features/routing/domain/route_repository.dart';
import 'package:latlong2/latlong.dart';

enum RouteStatus {
  /// No destination yet.
  idle,

  /// A destination is set, but there's no start point (no location yet and
  /// no manual start).
  waitingForStart,

  /// Request in progress.
  loading,

  /// Request in progress for more than a few seconds.
  loadingSlow,

  /// [RouteController.route] is ready.
  ready,

  /// Something failed. See [RouteController.failure].
  error,
}

/// Turns destination taps into routes, without flooding the server.
///
/// Three layers keep requests under control:
/// 1. Debounce: rapid long-presses -> only the last one is requested.
/// 2. Gate: two requests never start less than 1.1 s apart.
/// 3. Request id: a late answer to an old request is ignored, so the map
///    always shows the route for the latest destination.
class RouteController extends GetxController {
  RouteController(
    this._repository,
    this._locationFix, {
    Duration debounceDelay = const Duration(milliseconds: 500),
    Duration minRequestInterval = const Duration(milliseconds: 1100),
    this.slowHintDelay = const Duration(seconds: 3),
    this.rateLimitRetryDelay = const Duration(seconds: 2),
    this.maxFixAge = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _debouncer = Debouncer(debounceDelay),
       _gate = MinIntervalGate(minRequestInterval, now: now);

  /// Closer than this, there's no point in routing.
  static const minRouteDistanceMeters = 15.0;

  /// A new destination this close to the last routed one (with the same
  /// start) is treated as the same request.
  static const sameDestinationMeters = 10.0;

  final RouteRepository _repository;
  final Rxn<LocationFix> _locationFix;
  final DateTime Function() _now;
  final Debouncer _debouncer;
  final MinIntervalGate _gate;
  final Duration slowHintDelay;
  final Duration rateLimitRetryDelay;

  /// An older device location is not trusted as the trip start.
  final Duration maxFixAge;

  final status = RouteStatus.idle.obs;
  final destination = Rxn<LatLng>();
  final manualStart = Rxn<LatLng>();
  final route = Rxn<RouteModel>();
  final failure = Rxn<RouteFailure>();

  /// True after "Pick start on map": the next long-press sets the start.
  final pickingStart = false.obs;

  /// Increases with every request. Only the newest one may change state.
  int _latestRequestId = 0;
  CancelSignal? _inFlight;
  Timer? _slowHintTimer;
  Timer? _retryTimer;
  Worker? _fixWorker;

  /// Start and destination of the route currently shown (for dedupe).
  LatLng? _routedStart;
  LatLng? _routedDestination;

  /// Manual start if the user chose one, otherwise a recent device location.
  LatLng? get start {
    final manual = manualStart.value;
    if (manual != null) return manual;

    final fix = _locationFix.value;
    if (fix == null || fix.age(_now()) > maxFixAge) return null;
    return LatLng(fix.latitude, fix.longitude);
  }

  @override
  void onInit() {
    super.onInit();
    // The first location fix can unblock a destination chosen earlier.
    // Later fixes don't re-route: the route starts where the trip started.
    _fixWorker = ever(_locationFix, (_) {
      if (status.value == RouteStatus.waitingForStart) _scheduleFetch();
    });
  }

  @override
  void onClose() {
    _fixWorker?.dispose();
    _debouncer.cancel();
    _slowHintTimer?.cancel();
    _retryTimer?.cancel();
    _inFlight?.cancel();
    super.onClose();
  }

  /// Long-press on the map.
  void onMapLongPress(LatLng point) {
    if (pickingStart.value) {
      pickingStart.value = false;
      manualStart.value = point;
      if (destination.value != null) _scheduleFetch();
      return;
    }
    // The marker moves right away; the request waits for the debounce.
    destination.value = point;
    _scheduleFetch();
  }

  /// "Pick start on map": the next long-press sets the start point.
  void startPickingStart() => pickingStart.value = true;

  void cancelPickingStart() => pickingStart.value = false;

  /// Go back to using the device location as the start.
  void clearManualStart() {
    if (manualStart.value == null) return;
    manualStart.value = null;
    if (destination.value != null) _scheduleFetch();
  }

  /// "Retry" button: request again now, even for the same points.
  void retry() {
    _debouncer.cancel();
    unawaited(_fetch(force: true));
  }

  /// Remove the destination and the route.
  void clear() {
    _debouncer.cancel();
    _retryTimer?.cancel();
    _cancelInFlight();
    _latestRequestId++;
    destination.value = null;
    route.value = null;
    failure.value = null;
    _routedStart = null;
    _routedDestination = null;
    status.value = RouteStatus.idle;
  }

  void _scheduleFetch() {
    _retryTimer?.cancel();
    _debouncer.run(() => unawaited(_fetch()));
  }

  Future<void> _fetch({bool force = false, bool isAutoRetry = false}) async {
    if (isClosed) return;
    final to = destination.value;
    if (to == null) return;

    final from = start;
    if (from == null) {
      _cancelInFlight();
      route.value = null;
      status.value = RouteStatus.waitingForStart;
      return;
    }

    if (GeoMath.distanceMeters(from, to) < minRouteDistanceMeters) {
      _cancelInFlight();
      route.value = null;
      _fail(const RouteDestinationTooClose());
      return;
    }

    if (!force && _isAlreadyRouted(from, to)) return;

    final requestId = ++_latestRequestId;
    _cancelInFlight();
    final signal = CancelSignal();
    _inFlight = signal;

    route.value = null;
    failure.value = null;
    status.value = RouteStatus.loading;
    _startSlowHintTimer();

    // Respect the server's rate limit.
    final wait = _gate.waitTime;
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
      if (_isStale(requestId)) return;
    }
    _gate.markStarted();

    try {
      final result = await _repository.fetchRoute(
        start: from,
        destination: to,
        cancelSignal: signal,
      );
      if (_isStale(requestId)) return;

      route.value = result;
      _routedStart = from;
      _routedDestination = to;
      status.value = RouteStatus.ready;
    } on RouteRequestCancelled {
      return; // replaced by a newer request on purpose
    } on RouteFailure catch (error) {
      if (_isStale(requestId)) return;
      _fail(error);
      if (error is RouteRateLimited && !isAutoRetry) {
        _retryTimer = Timer(
          rateLimitRetryDelay,
          () => unawaited(_fetch(force: true, isAutoRetry: true)),
        );
      }
    } finally {
      if (requestId == _latestRequestId) {
        _slowHintTimer?.cancel();
        if (identical(_inFlight, signal)) _inFlight = null;
      }
    }
  }

  /// True if this answer belongs to an old request or the screen is gone.
  bool _isStale(int requestId) => isClosed || requestId != _latestRequestId;

  bool _isAlreadyRouted(LatLng from, LatLng to) {
    final routedStart = _routedStart;
    final routedDestination = _routedDestination;
    if (route.value == null ||
        routedStart == null ||
        routedDestination == null) {
      return false;
    }
    return routedStart == from &&
        GeoMath.distanceMeters(routedDestination, to) < sameDestinationMeters;
  }

  void _startSlowHintTimer() {
    _slowHintTimer?.cancel();
    _slowHintTimer = Timer(slowHintDelay, () {
      if (!isClosed && status.value == RouteStatus.loading) {
        status.value = RouteStatus.loadingSlow;
      }
    });
  }

  void _cancelInFlight() {
    _inFlight?.cancel();
    _inFlight = null;
    _slowHintTimer?.cancel();
  }

  void _fail(RouteFailure error) {
    appLogger.w('Route state -> error: $error');
    failure.value = error;
    status.value = RouteStatus.error;
  }
}
