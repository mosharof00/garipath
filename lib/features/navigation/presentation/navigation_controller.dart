import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:garipath/core/geo/route_geometry.dart';
import 'package:garipath/core/logging/app_logger.dart';
import 'package:garipath/core/navigation/navigation_frame.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:garipath/features/navigation/domain/simulation_clock.dart';
import 'package:garipath/features/routing/domain/route_model.dart';

/// Plays the car along the current route.
///
/// The [RouteAnimator] does the maths; this class connects it to the clock
/// and to the UI:
/// - [frame] changes every screen frame. Only the car layer listens to it.
/// - [hud] changes at most every [hudInterval]. The text (remaining
///   distance and time) listens to it, so text isn't rebuilt 60 times a
///   second.
class NavigationController extends GetxController with WidgetsBindingObserver {
  NavigationController(
    this._route,
    this._clock, {
    required this.baseSpeedMps,
    this.hudInterval = const Duration(milliseconds: 200),
  });

  final Rxn<RouteModel> _route;
  final SimulationClock _clock;
  final double baseSpeedMps;
  final Duration hudInterval;

  final playback = PlaybackState.idle.obs;
  final multiplier = 1.obs;
  final frame = Rxn<NavigationFrame>();
  final hud = Rxn<NavigationFrame>();

  RouteAnimator? _animator;
  Worker? _routeWorker;
  Duration _sinceHudUpdate = Duration.zero;

  /// True when *we* paused because the app went to the background, so we
  /// resume on return. A pause the user chose is never undone by us.
  bool _autoPaused = false;

  bool get hasRoute => _animator != null;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _routeWorker = ever(_route, _onRouteChanged);
    _onRouteChanged(_route.value);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeWorker?.dispose();
    _clock.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (playback.value == PlaybackState.playing) {
          appLogger.i('App in background: pausing the simulation');
          _autoPaused = true;
          pause();
        }
      case AppLifecycleState.resumed:
        if (_autoPaused) {
          appLogger.i('App back: resuming the simulation');
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

  void start() {
    final animator = _animator;
    if (animator == null) return;
    animator.start();
    _afterControl();
  }

  void pause() {
    _animator?.pause();
    _afterControl();
  }

  void resume() {
    _animator?.resume();
    _afterControl();
  }

  void reset() {
    _autoPaused = false;
    _animator?.reset();
    _afterControl();
  }

  /// 1x, 2x or 5x. Kept when a new route arrives.
  void setMultiplier(int value) {
    multiplier.value = value;
    _animator?.setMultiplier(value);
    _publish(updateHud: true);
  }

  /// A new route (or no route) replaces the old animation completely.
  void _onRouteChanged(RouteModel? route) {
    _clock.stop();
    _autoPaused = false;
    _animator = route == null ? null : _createAnimator(route);
    _afterControl();
  }

  RouteAnimator? _createAnimator(RouteModel route) {
    try {
      final geometry = RouteGeometry.fromPoints(route.points);
      return RouteAnimator(geometry, baseSpeedMps: baseSpeedMps)
        ..setMultiplier(multiplier.value);
    } on ArgumentError catch (error) {
      appLogger.w('Route cannot be animated: $error');
      return null;
    }
  }

  /// Runs the clock only while playing, and publishes the new state.
  void _afterControl() {
    final state = _animator?.state ?? PlaybackState.idle;
    playback.value = state;
    if (state == PlaybackState.playing) {
      _clock.start(_onTick);
    } else {
      _clock.stop();
    }
    _publish(updateHud: true);
  }

  void _onTick(Duration dt) {
    final animator = _animator;
    if (animator == null) return;

    animator.tick(dt);
    _sinceHudUpdate += dt;
    final finished = animator.state == PlaybackState.finished;
    _publish(updateHud: finished || _sinceHudUpdate >= hudInterval);

    if (finished) {
      appLogger.i('Simulation finished');
      _clock.stop();
      playback.value = PlaybackState.finished;
    }
  }

  void _publish({required bool updateHud}) {
    final current = _animator?.frame;
    frame.value = current;
    if (updateHud) {
      hud.value = current;
      _sinceHudUpdate = Duration.zero;
    }
  }
}
