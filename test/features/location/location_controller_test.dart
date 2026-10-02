import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:garipath/features/location/domain/location_exception.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/location/domain/location_permission.dart';
import 'package:garipath/features/location/presentation/location_controller.dart';

import '../../fakes/fake_location_service.dart';

const _granted = LocationPermission(
  status: LocationPermissionStatus.granted,
  isPrecise: true,
);
const _denied = LocationPermission(status: LocationPermissionStatus.denied);
const _deniedForever = LocationPermission(
  status: LocationPermissionStatus.deniedForever,
);

/// Lets all pending async work (fake futures, stream events) finish.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationService service;

  /// Registers the controller like the binding does, which runs onInit.
  Future<LocationController> startController() async {
    final controller = Get.put(LocationController(service));
    await settle();
    return controller;
  }

  setUp(() {
    Get.testMode = true;
    service = FakeLocationService();
  });

  tearDown(() async {
    Get.reset();
    await service.dispose();
  });

  group('on start (no prompt)', () {
    test('not asked yet -> needsPermission, dialog not shown', () async {
      final controller = await startController();

      expect(controller.status.value, LocationStatus.needsPermission);
      expect(service.requestCount, 0);
    });

    test('denied before -> needsPermission', () async {
      service.permission = _denied;
      final controller = await startController();

      expect(controller.status.value, LocationStatus.needsPermission);
    });

    test('blocked -> error deniedForever', () async {
      service.permission = _deniedForever;
      final controller = await startController();

      expect(controller.status.value, LocationStatus.error);
      expect(
        controller.error.value,
        isA<LocationPermissionPermanentlyDenied>(),
      );
    });

    test('already granted -> locates and streams without a dialog', () async {
      service.permission = _granted;
      final controller = await startController();

      expect(controller.status.value, LocationStatus.ready);
      expect(controller.fix.value, sampleFix);
      expect(service.requestCount, 0);
      expect(service.isStreaming, isTrue);
    });

    test('not supported platform -> error notSupported', () async {
      service.permission = _granted;
      service.currentLocationError = const LocationNotSupported();
      final controller = await startController();

      expect(controller.error.value, isA<LocationNotSupported>());
    });
  });

  group('requestAndLocate', () {
    test('granted -> ready with fix and live updates', () async {
      final controller = await startController();

      await controller.requestAndLocate();

      expect(service.requestCount, 1);
      expect(controller.status.value, LocationStatus.ready);
      expect(controller.fix.value, sampleFix);
      expect(controller.isPrecise.value, isTrue);
      expect(service.isStreaming, isTrue);
    });

    test('denied -> error denied', () async {
      service.permissionAfterRequest = _denied;
      final controller = await startController();

      await controller.requestAndLocate();

      expect(controller.status.value, LocationStatus.error);
      expect(controller.error.value, isA<LocationPermissionDenied>());
      expect(service.getCurrentLocationCount, 0);
    });

    test('denied forever -> error deniedForever', () async {
      service.permissionAfterRequest = _deniedForever;
      final controller = await startController();

      await controller.requestAndLocate();

      expect(
        controller.error.value,
        isA<LocationPermissionPermanentlyDenied>(),
      );
    });

    test('services off -> error servicesDisabled', () async {
      service.currentLocationError = const LocationServicesDisabled();
      final controller = await startController();

      await controller.requestAndLocate();

      expect(controller.error.value, isA<LocationServicesDisabled>());
      expect(service.isStreaming, isFalse);
    });

    test('timeout -> error timeout, retry recovers', () async {
      service.currentLocationError = const LocationTimeout();
      final controller = await startController();

      await controller.requestAndLocate();
      expect(controller.error.value, isA<LocationTimeout>());

      service.currentLocationError = null;
      await controller.retry();
      expect(controller.status.value, LocationStatus.ready);
      expect(controller.error.value, isNull);
    });

    test('approximate permission -> isPrecise false', () async {
      service.currentFix = LocationFix(
        latitude: 23.76,
        longitude: 90.43,
        timestamp: DateTime(2026),
        isPrecise: false,
      );
      final controller = await startController();

      await controller.requestAndLocate();

      expect(controller.isPrecise.value, isFalse);
    });

    test('a second tap while the dialog is open is ignored', () async {
      final controller = await startController();

      final first = controller.requestAndLocate();
      final second = controller.requestAndLocate();
      await Future.wait([first, second]);

      expect(service.requestCount, 1);
    });
  });

  group('live updates', () {
    test('a new fix replaces the old one', () async {
      service.permission = _granted;
      final controller = await startController();
      final moved = LocationFix(
        latitude: 23.8,
        longitude: 90.4,
        timestamp: DateTime(2026, 10, 2, 12, 1),
      );

      service.emitFix(moved);
      await settle();

      expect(controller.fix.value, moved);
    });

    test('services turned off -> error, keeps listening, recovers', () async {
      service.permission = _granted;
      final controller = await startController();

      service.emitError(const LocationServicesDisabled());
      await settle();
      expect(controller.error.value, isA<LocationServicesDisabled>());
      expect(service.isStreaming, isTrue);

      service.emitFix(sampleFix);
      await settle();
      expect(controller.status.value, LocationStatus.ready);
    });

    test('permission lost -> error and stream stopped', () async {
      service.permission = _granted;
      final controller = await startController();

      service.emitError(const LocationPermissionDenied());
      await settle();

      expect(controller.error.value, isA<LocationPermissionDenied>());
      expect(service.isStreaming, isFalse);
    });
  });

  group('settings', () {
    test('services off opens location settings', () async {
      service.currentLocationError = const LocationServicesDisabled();
      final controller = await startController();
      await controller.requestAndLocate();

      await controller.openSettings();

      expect(service.openLocationSettingsCount, 1);
      expect(service.openAppSettingsCount, 0);
    });

    test('blocked permission opens app settings', () async {
      service.permission = _deniedForever;
      final controller = await startController();

      await controller.openSettings();

      expect(service.openAppSettingsCount, 1);
    });
  });

  group('app lifecycle', () {
    test('going to background stops updates, coming back restarts', () async {
      service.permission = _granted;
      final controller = await startController();
      expect(service.isStreaming, isTrue);

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(service.isStreaming, isTrue, reason: 'inactive must not stop');

      controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();
      expect(service.isStreaming, isFalse);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(service.isStreaming, isTrue);
      expect(service.listenCount, 2);
    });

    test('back from Settings with permission granted -> ready', () async {
      service.permission = _deniedForever;
      final controller = await startController();
      expect(controller.status.value, LocationStatus.error);

      service.permission = _granted; // user enabled it in Settings
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();

      expect(controller.status.value, LocationStatus.ready);
      expect(service.requestCount, 0);
    });

    test('resume right after denying keeps the denied card', () async {
      service.permissionAfterRequest = _denied;
      final controller = await startController();
      await controller.requestAndLocate();

      // Closing the system dialog resumes the app.
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();

      expect(controller.error.value, isA<LocationPermissionDenied>());
    });

    test('a fix arriving while in background does not start updates', () async {
      final controller = await startController();
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);

      await controller.requestAndLocate();

      expect(controller.status.value, LocationStatus.ready);
      expect(service.isStreaming, isFalse);
    });

    test('closing the screen stops updates and ignores later events', () async {
      service.permission = _granted;
      final controller = await startController();

      await Get.delete<LocationController>();
      await settle();
      expect(service.isStreaming, isFalse);
      expect(service.cancelCount, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(service.isStreaming, isFalse);
    });
  });
}
