import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/features/location/data/location_error_mapper.dart';
import 'package:garipath/features/location/domain/location_exception.dart';

void main() {
  group('fromPlatformException', () {
    final expectedTypes = <String, Type>{
      'PERMISSION_DENIED': LocationPermissionDenied,
      'PERMISSION_DENIED_FOREVER': LocationPermissionPermanentlyDenied,
      'SERVICES_DISABLED': LocationServicesDisabled,
      'TIMEOUT': LocationTimeout,
      'LOCATION_UNAVAILABLE': LocationUnavailable,
      'NOT_SUPPORTED': LocationNotSupported,
      'REQUEST_IN_PROGRESS': LocationRequestInProgress,
      'ACTIVITY_UNAVAILABLE': LocationActivityUnavailable,
    };

    expectedTypes.forEach((code, type) {
      test('maps $code to $type', () {
        final result = LocationErrorMapper.fromPlatformException(
          PlatformException(code: code),
        );
        expect(result.runtimeType, type);
      });
    });

    test('keeps the native message when there is one', () {
      final result = LocationErrorMapper.fromPlatformException(
        PlatformException(code: 'TIMEOUT', message: 'No fix after 15000 ms'),
      );
      expect(result.message, 'No fix after 15000 ms');
    });

    test('uses a default message when native sends none', () {
      final result = LocationErrorMapper.fromPlatformException(
        PlatformException(code: 'SERVICES_DISABLED'),
      );
      expect(result.message, 'Location services are disabled');
    });

    test('maps an unknown code to LocationUnknownError and keeps the code', () {
      final result = LocationErrorMapper.fromPlatformException(
        PlatformException(code: 'SOMETHING_NEW', message: 'boom'),
      );

      expect(result, isA<LocationUnknownError>());
      expect((result as LocationUnknownError).code, 'SOMETHING_NEW');
      expect(result.message, 'boom');
    });
  });

  group('map', () {
    test('maps MissingPluginException to LocationNotSupported', () {
      final result = LocationErrorMapper.map(MissingPluginException());
      expect(result, isA<LocationNotSupported>());
    });

    test('returns a LocationException unchanged', () {
      const original = LocationTimeout();
      expect(LocationErrorMapper.map(original), same(original));
    });

    test('wraps any other error in LocationUnknownError', () {
      final result = LocationErrorMapper.map(StateError('unexpected'));
      expect(result, isA<LocationUnknownError>());
    });
  });
}
