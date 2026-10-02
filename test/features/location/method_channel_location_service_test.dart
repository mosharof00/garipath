import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/features/location/data/location_channel_contract.dart';
import 'package:garipath/features/location/data/method_channel_location_service.dart';
import 'package:garipath/features/location/domain/location_exception.dart';
import 'package:garipath/features/location/domain/location_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(LocationChannels.method);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelLocationService service;
  late List<MethodCall> calls;

  /// Makes the fake native side answer every call with [handler].
  void fakeNative(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(() {
    calls = [];
    service = MethodChannelLocationService(
      safetyMargin: const Duration(milliseconds: 50),
    );
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('permission', () {
    test('checkPermission calls native and parses the result', () async {
      fakeNative((_) async => {'status': 'granted', 'isPrecise': true});

      final permission = await service.checkPermission();

      expect(calls.single.method, 'checkPermission');
      expect(permission.status, LocationPermissionStatus.granted);
      expect(permission.isPrecise, isTrue);
    });

    test('requestPermission returns denied forever', () async {
      fakeNative((_) async => {'status': 'deniedForever'});

      final permission = await service.requestPermission();

      expect(calls.single.method, 'requestPermission');
      expect(permission.status, LocationPermissionStatus.deniedForever);
    });

    test('a request already in progress becomes a typed error', () {
      fakeNative((_) async {
        throw PlatformException(code: 'REQUEST_IN_PROGRESS');
      });

      expect(
        service.requestPermission(),
        throwsA(isA<LocationRequestInProgress>()),
      );
    });

    test('invalid permission data becomes LocationUnknownError', () {
      fakeNative((_) async => {'status': 'maybe'});

      expect(
        service.checkPermission(),
        throwsA(
          isA<LocationUnknownError>().having(
            (e) => e.code,
            'code',
            'BAD_PAYLOAD',
          ),
        ),
      );
    });
  });

  group('getCurrentLocation', () {
    test('sends the timeout and parses the fix', () async {
      fakeNative(
        (_) async => {'lat': 23.81, 'lng': 90.41, 'timestamp': 1759400000000},
      );

      final fix = await service.getCurrentLocation(
        timeout: const Duration(seconds: 15),
      );

      expect(calls.single.method, 'getCurrentLocation');
      expect(calls.single.arguments, {'timeoutMs': 15000});
      expect(fix.latitude, 23.81);
      expect(fix.longitude, 90.41);
    });

    test('maps native TIMEOUT to LocationTimeout', () {
      fakeNative((_) async {
        throw PlatformException(code: 'TIMEOUT');
      });

      expect(service.getCurrentLocation(), throwsA(isA<LocationTimeout>()));
    });

    test('maps native SERVICES_DISABLED to LocationServicesDisabled', () {
      fakeNative((_) async {
        throw PlatformException(code: 'SERVICES_DISABLED');
      });

      expect(
        service.getCurrentLocation(),
        throwsA(isA<LocationServicesDisabled>()),
      );
    });

    test('gives up on its own if native never answers', () {
      final neverAnswers = Completer<Object?>();
      fakeNative((_) => neverAnswers.future);

      expect(
        service.getCurrentLocation(timeout: const Duration(milliseconds: 10)),
        throwsA(isA<LocationTimeout>()),
      );
    });

    test('invalid location data becomes LocationUnknownError', () {
      fakeNative((_) async => {'lat': double.nan, 'lng': 90.0});

      expect(
        service.getCurrentLocation(),
        throwsA(isA<LocationUnknownError>()),
      );
    });
  });

  group('services and settings', () {
    test('isLocationServiceEnabled returns the native bool', () async {
      fakeNative((_) async => false);
      expect(await service.isLocationServiceEnabled(), isFalse);

      fakeNative((_) async => true);
      expect(await service.isLocationServiceEnabled(), isTrue);
    });

    test('openAppSettings and openLocationSettings call native', () async {
      fakeNative((_) async => true);

      expect(await service.openAppSettings(), isTrue);
      expect(await service.openLocationSettings(), isTrue);
      expect(calls.map((c) => c.method), [
        'openAppSettings',
        'openLocationSettings',
      ]);
    });
  });

  group('platform without native code', () {
    test('every call reports LocationNotSupported instead of crashing', () {
      // No mock handler: this is exactly what happens on iOS before the Swift
      // implementation exists (MissingPluginException).
      expect(service.checkPermission(), throwsA(isA<LocationNotSupported>()));
      expect(
        service.getCurrentLocation(),
        throwsA(isA<LocationNotSupported>()),
      );
      expect(
        service.isLocationServiceEnabled(),
        throwsA(isA<LocationNotSupported>()),
      );
    });
  });
}
