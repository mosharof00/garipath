import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:garipath/core/logging/app_logger.dart';
import 'package:garipath/features/location/domain/location_exception.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/location/domain/location_permission.dart';
import 'package:garipath/features/location/domain/location_service.dart';

/// What the location part of the screen is doing right now.
enum LocationStatus {
  /// Nothing checked yet.
  idle,

  /// Not granted yet. The screen offers "Use my location".
  needsPermission,

  /// The system permission dialog is showing.
  requesting,

  /// Permission is fine, waiting for the first fix.
  acquiring,

  /// We have a fix and live updates are running.
  ready,

  /// Something failed. See [LocationController.error] for what.
  error,
}

/// Turns [LocationService] calls into simple screen state.
///
/// Rules:
/// - Never shows the permission dialog by itself. Only [requestAndLocate],
///   called from a user tap, does that.
/// - Live updates run only while the app is visible.
class LocationController extends GetxController with WidgetsBindingObserver {
  LocationController(
    this._service, {
    this.locationTimeout = const Duration(seconds: 15),
  });

  final LocationService _service;
  final Duration locationTimeout;

  final status = LocationStatus.idle.obs;
  final fix = Rxn<LocationFix>();
  final error = Rxn<LocationException>();
  final isPrecise = true.obs;

  StreamSubscription<LocationFix>? _updates;

  /// True while the permission dialog is open. The dialog itself causes
  /// lifecycle changes, which must not trigger a re-check.
  bool _requesting = false;

  /// True while the app is not visible. A fix that arrives late must not
  /// start updates in the background.
  bool _inBackground = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(checkWithoutPrompt());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopUpdates();
    super.onClose();
  }

  /// Checks permission silently. If it's already granted, gets the location;
  /// otherwise waits for the user to tap "Use my location".
  Future<void> checkWithoutPrompt() async {
    try {
      final permission = await _service.checkPermission();
      if (isClosed) return;

      switch (permission.status) {
        case LocationPermissionStatus.granted:
          await _locate();
        case LocationPermissionStatus.deniedForever:
          _fail(const LocationPermissionPermanentlyDenied());
        case LocationPermissionStatus.notDetermined:
        case LocationPermissionStatus.denied:
          status.value = LocationStatus.needsPermission;
      }
    } on LocationException catch (e) {
      _fail(e);
    }
  }

  /// Called from a user tap: asks for permission, then gets the location.
  Future<void> requestAndLocate() async {
    if (_requesting) return;
    _requesting = true;
    status.value = LocationStatus.requesting;
    error.value = null;

    try {
      final permission = await _service.requestPermission();
      if (isClosed) return;

      switch (permission.status) {
        case LocationPermissionStatus.granted:
          await _locate();
        case LocationPermissionStatus.deniedForever:
          _fail(const LocationPermissionPermanentlyDenied());
        case LocationPermissionStatus.notDetermined:
        case LocationPermissionStatus.denied:
          _fail(const LocationPermissionDenied());
      }
    } on LocationException catch (e) {
      _fail(e);
    } finally {
      _requesting = false;
    }
  }

  /// "Try again" / "Retry" button.
  Future<void> retry() => requestAndLocate();

  /// Opens the Settings screen that fixes the current error.
  Future<void> openSettings() async {
    try {
      if (error.value is LocationServicesDisabled) {
        await _service.openLocationSettings();
      } else {
        await _service.openAppSettings();
      }
    } on LocationException catch (e) {
      appLogger.w('Could not open settings: $e');
    }
    // When the user comes back, didChangeAppLifecycleState re-checks.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _inBackground = false;
        _onResumed();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // No location updates while the app is not visible.
        _inBackground = true;
        _stopUpdates();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // `inactive` also fires for the permission dialog and the
        // notification shade, so it must not stop anything.
        break;
    }
  }

  void _onResumed() {
    if (_requesting || isClosed) return;

    switch (status.value) {
      case LocationStatus.ready:
        _startUpdates();
      case LocationStatus.needsPermission:
      case LocationStatus.error:
        // The user may have fixed it in Settings while we were away.
        unawaited(_recheckAfterResume());
      case LocationStatus.idle:
      case LocationStatus.requesting:
      case LocationStatus.acquiring:
        break;
    }
  }

  /// Only moves the state forward. Closing the permission dialog also
  /// "resumes" the app, and that must not replace the "denied" card with
  /// the first "Use my location" card again.
  Future<void> _recheckAfterResume() async {
    try {
      final permission = await _service.checkPermission();
      if (isClosed) return;

      if (permission.isGranted) {
        await _locate();
      } else if (permission.status == LocationPermissionStatus.deniedForever) {
        _fail(const LocationPermissionPermanentlyDenied());
      }
    } on LocationException catch (e) {
      _fail(e);
    }
  }

  Future<void> _locate() async {
    status.value = LocationStatus.acquiring;
    error.value = null;
    try {
      final newFix = await _service.getCurrentLocation(
        timeout: locationTimeout,
      );
      if (isClosed) return;
      _applyFix(newFix);
      _startUpdates();
    } on LocationException catch (e) {
      _fail(e);
    }
  }

  void _startUpdates() {
    if (_updates != null || _inBackground || isClosed) return;
    _updates = _service.locationUpdates().listen(
      _applyFix,
      onError: (Object e) {
        if (e is! LocationException) return;
        // Services off: show the card but keep listening. Fixes come back
        // on their own when the user turns location on again.
        // Permission lost: stop, nothing will arrive anymore.
        if (e is! LocationServicesDisabled) _stopUpdates();
        _fail(e);
      },
    );
  }

  void _stopUpdates() {
    final cancelling = _updates?.cancel();
    _updates = null;
    if (cancelling != null) unawaited(cancelling);
  }

  void _applyFix(LocationFix newFix) {
    if (isClosed) return;
    fix.value = newFix;
    isPrecise.value = newFix.isPrecise;
    error.value = null;
    status.value = LocationStatus.ready;
  }

  void _fail(LocationException e) {
    if (isClosed) return;
    appLogger.w('Location state -> error: $e');
    error.value = e;
    status.value = LocationStatus.error;
  }
}
