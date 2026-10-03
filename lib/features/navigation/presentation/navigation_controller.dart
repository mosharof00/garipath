import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:garipath/core/logging/app_logger.dart';
import 'package:garipath/core/navigation/live_tracker.dart';
import 'package:garipath/core/navigation/navigation_frame.dart';
import 'package:garipath/core/navigation/off_route_detector.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/navigation/domain/simulation_clock.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:latlong2/latlong.dart';

enum DriveMode {
  /// The car drives the route by itself at a simulated speed.
  simulated,

  /// The car follows the device's real GPS position.
  live,
}

/// Moves the car along the current route, simulated or live.
///
/// The maths lives in pure classes ([RouteAnimator], [LiveTracker]); this
/// class connects them to the clock, the location fixes and the UI:
/// - [frame] changes every screen frame. Only the car layer listens to it.
/// - [hud] changes at most every [hudInterval]. The text (remaining
///   distance and time) listens to it, so text isn't rebuilt 60 times a
///   second.
class NavigationController extends GetxController with WidgetsBindingObserver {
  NavigationController(
    this._route,
    this._clock, {
    required this.baseSpeedMps,
    Rxn<LocationFix>? locationFix,
    this.onRerouteNeeded,
    OffRouteDetector? offRouteDetector,
    DateTime Function()? now,
    this.hudInterval = const Duration(milliseconds: 200),
  }) : _locationFix = locationFix ?? Rxn<LocationFix>(),
       _offRoute = offRouteDetector ?? OffRouteDetector(),
       _now = now ?? DateTime.now;

  final Rxn<RouteModel> _route;
  final SimulationClock _clock;
  final Rxn<LocationFix> _locationFix;
  final OffRouteDetector _offRoute;
  final DateTime Function() _now;
  final double baseSpeedMps;
  final Duration hudInterval;

  /// Live mode only: called when the device has left the route.
  final VoidCallback? onRerouteNeeded;

  final mode = DriveMode.simulated.obs;
  final playback = PlaybackState.idle.obs;
  final multiplier = 1.obs;
  final frame = Rxn<NavigationFrame>();
  final hud = Rxn<NavigationFrame>();

  RouteModel? _currentRoute;
  RouteGeometry? _geometry;
  RouteAnimator? _animator;

  LiveTracker? _live;
  NavigationFrame? _liveFrame;
  PlaybackState _liveState = PlaybackState.idle;

  /// Set when we asked for a reroute: the next route starts live again
  /// by itself instead of waiting for Start.
  bool _resumeLiveAfterReroute = false;

  final _workers = <Worker>[];
  Duration _sinceHudUpdate = Duration.zero;

  /// True when *we* paused because the app went to the background, so we
  /// resume on return. A pause the user chose is never undone by us.
  bool _autoPaused = false;

  bool get hasRoute => _animator != null;

  /// Live mode needs a device location.
  bool get canUseLive => _locationFix.value != null;

  bool get _isLive => mode.value == DriveMode.live;

  PlaybackState get _state =>
      _isLive ? _liveState : (_animator?.state ?? PlaybackState.idle);

  /// In live mode, the car waits at the route start until the first fix.
  NavigationFrame? get _currentFrame =>
      _isLive ? (_liveFrame ?? _animator?.frame) : _animator?.frame;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _workers
      ..add(ever(_route, _onRouteChanged))
      ..add(ever(_locationFix, _onFix));
    _onRouteChanged(_route.value);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final worker in _workers) {
      worker.dispose();
    }
    _clock.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (playback.value == PlaybackState.playing) {
          appLogger.i('App in background: pausing navigation');
          _autoPaused = true;
          pause();
        }
      case AppLifecycleState.resumed:
        if (_autoPaused) {
          appLogger.i('App back: resuming navigation');
          _autoPaused = false;
          resume(); // the clock restarts from zero, so the car doesn't jump
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // `inactive` also fires for the notification shade and system
        // dialogs, where the app is still visible. Keep playing.
        break;
    }
  }

  /// Sim or Live. Switching stops the current trip.
  void setMode(DriveMode value) {
    if (mode.value == value) return;
    if (value == DriveMode.live && !canUseLive) return;
    mode.value = value;
    reset();
  }

  void start() {
    final geometry = _geometry;
    final route = _currentRoute;
    if (geometry == null || route == null) return;

    if (_isLive) {
      final fix = _locationFix.value;
      if (fix == null) return;
      _live = LiveTracker(geometry, secondsPerMeter: _secondsPerMeter(route));
      _offRoute.resetCount();
      _liveState = PlaybackState.playing;
      _feed(fix);
    } else {
      _animator?.start();
    }
    _afterControl();
  }

  void pause() {
    if (_isLive) {
      if (_liveState == PlaybackState.playing) {
        _liveState = PlaybackState.paused;
      }
    } else {
      _animator?.pause();
    }
    _afterControl();
  }

  void resume() {
    if (_isLive) {
      if (_liveState == PlaybackState.paused) {
        _liveState = PlaybackState.playing;
        final fix = _locationFix.value;
        if (fix != null) _feed(fix);
      }
    } else {
      _animator?.resume();
    }
    _afterControl();
  }

  void reset() {
    _autoPaused = false;
    _resumeLiveAfterReroute = false;
    _clearLive();
    _animator?.reset();
    _afterControl();
  }

  /// 1x, 2x or 5x (simulated mode). Kept when a new route arrives.
  void setMultiplier(int value) {
    multiplier.value = value;
    _animator?.setMultiplier(value);
    _publish(updateHud: true);
  }

  /// A new route (or no route) replaces the old trip completely.
  void _onRouteChanged(RouteModel? route) {
    _clock.stop();
    _autoPaused = false;
    _clearLive();
    _currentRoute = route;
    _geometry = route == null ? null : _createGeometry(route);
    final geometry = _geometry;
    _animator = geometry == null
        ? null
        : (RouteAnimator(geometry, baseSpeedMps: baseSpeedMps)
            ..setMultiplier(multiplier.value));

    if (route != null && _resumeLiveAfterReroute && _isLive) {
      _resumeLiveAfterReroute = false;
      appLogger.i('New route after reroute: continuing live');
      start();
      return;
    }
    _afterControl();
  }

  RouteGeometry? _createGeometry(RouteModel route) {
    try {
      return RouteGeometry.fromPoints(route.points);
    } on ArgumentError catch (error) {
      appLogger.w('Route cannot be animated: $error');
      return null;
    }
  }

  void _onFix(LocationFix? fix) {
    if (fix == null || !_isLive || _liveState != PlaybackState.playing) return;
    _feed(fix);
  }

  /// Gives a fix to the live tracker and checks whether we left the route.
  void _feed(LocationFix fix) {
    final live = _live;
    if (live == null) return;

    final projection = live.onFix(
      LatLng(fix.latitude, fix.longitude),
      bearingDegrees: fix.bearingDegrees,
      speedMps: fix.speedMps,
    );

    final leftRoute = _offRoute.update(
      offsetMeters: projection.offsetMeters,
      accuracyMeters: fix.accuracyMeters,
      now: _now(),
    );
    if (leftRoute && onRerouteNeeded != null) {
      appLogger.i(
        'Off route by ${projection.offsetMeters.round()} m: rerouting',
      );
      _resumeLiveAfterReroute = true;
      onRerouteNeeded!();
    }
  }

  /// Seconds per metre at the route's own pace (OSRM duration / distance).
  double _secondsPerMeter(RouteModel route) {
    if (route.distanceMeters > 0 && route.durationSeconds > 0) {
      return route.durationSeconds / route.distanceMeters;
    }
    return 1 / baseSpeedMps;
  }

  void _clearLive() {
    _live = null;
    _liveFrame = null;
    _liveState = PlaybackState.idle;
  }

  /// Runs the clock only while playing, and publishes the new state.
  void _afterControl() {
    final state = _state;
    playback.value = state;
    if (state == PlaybackState.playing) {
      _clock.start(_onTick);
    } else {
      _clock.stop();
    }
    _publish(updateHud: true);
  }

  void _onTick(Duration dt) {
    final bool finished;
    if (_isLive) {
      final live = _live;
      if (live == null) return;
      _liveFrame = live.tick(dt) ?? _liveFrame;
      finished = live.arrived;
    } else {
      final animator = _animator;
      if (animator == null) return;
      animator.tick(dt);
      finished = animator.state == PlaybackState.finished;
    }

    _sinceHudUpdate += dt;
    _publish(updateHud: finished || _sinceHudUpdate >= hudInterval);

    if (finished) {
      appLogger.i(_isLive ? 'Arrived (live)' : 'Simulation finished');
      _clock.stop();
      if (_isLive) _liveState = PlaybackState.finished;
      playback.value = PlaybackState.finished;
    }
  }

  void _publish({required bool updateHud}) {
    final current = _currentFrame;
    frame.value = current;
    if (updateHud) {
      hud.value = current;
      _sinceHudUpdate = Duration.zero;
    }
  }
}
