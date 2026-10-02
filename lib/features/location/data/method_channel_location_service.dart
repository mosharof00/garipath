import 'dart:async';

import 'package:flutter/services.dart';
import 'package:garipath/features/location/data/location_channel_contract.dart';
import 'package:garipath/features/location/data/location_error_mapper.dart';
import 'package:garipath/features/location/data/location_payload_parser.dart';
import 'package:garipath/features/location/domain/location_exception.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/location/domain/location_permission.dart';
import 'package:garipath/features/location/domain/location_service.dart';

/// [LocationService] backed by our own native code (Kotlin, later Swift).
///
/// This is the only class in the app that talks to the location channels.
class MethodChannelLocationService implements LocationService {
  MethodChannelLocationService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    this.safetyMargin = const Duration(seconds: 3),
  }) : _methods = methodChannel ?? const MethodChannel(LocationChannels.method),
       _events = eventChannel ?? const EventChannel(LocationChannels.events);

  final MethodChannel _methods;
  final EventChannel _events;

  /// Extra time on top of the native timeout before Dart gives up on its own,
  /// so a native bug can never leave the UI waiting forever.
  final Duration safetyMargin;

  @override
  Future<LocationPermission> checkPermission() async {
    final raw = await _invoke(LocationMethods.checkPermission);
    return _parsePermission(raw);
  }

  @override
  Future<LocationPermission> requestPermission() async {
    final raw = await _invoke(LocationMethods.requestPermission);
    return _parsePermission(raw);
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    final raw = await _invoke(LocationMethods.isLocationServiceEnabled);
    return raw == true;
  }

  @override
  Future<LocationFix> getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final raw =
        await _invoke(LocationMethods.getCurrentLocation, {
          LocationArgs.timeoutMs: timeout.inMilliseconds,
        }).timeout(
          timeout + safetyMargin,
          onTimeout: () => throw const LocationTimeout(),
        );

    final fix = LocationPayloadParser.parseFix(raw);
    if (fix == null) throw _badPayload('location');
    return fix;
  }

  @override
  Stream<LocationFix> locationUpdates({
    Duration interval = const Duration(seconds: 2),
    double minDistanceMeters = 5,
  }) {
    final arguments = {
      LocationArgs.intervalMs: interval.inMilliseconds,
      LocationArgs.minDistanceMeters: minDistanceMeters,
    };

    // A transformer (not an async* loop) so that an error event is passed on
    // as a typed error while the stream keeps running. The native side can
    // report "services off" and later continue sending fixes.
    return _events
        .receiveBroadcastStream(arguments)
        .transform(
          StreamTransformer<dynamic, LocationFix>.fromHandlers(
            handleData: (raw, sink) {
              final fix = LocationPayloadParser.parseFix(raw);
              if (fix == null) {
                sink.addError(_badPayload('location'));
              } else {
                sink.add(fix);
              }
            },
            handleError: (error, stackTrace, sink) {
              sink.addError(LocationErrorMapper.map(error), stackTrace);
            },
          ),
        );
  }

  @override
  Future<bool> openAppSettings() async {
    final raw = await _invoke(LocationMethods.openAppSettings);
    return raw == true;
  }

  @override
  Future<bool> openLocationSettings() async {
    final raw = await _invoke(LocationMethods.openLocationSettings);
    return raw == true;
  }

  /// Calls a native method and converts any failure to a LocationException.
  Future<Object?> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _methods.invokeMethod<Object?>(method, arguments);
    } on Exception catch (error) {
      throw LocationErrorMapper.map(error);
    }
  }

  LocationPermission _parsePermission(Object? raw) {
    final permission = LocationPayloadParser.parsePermission(raw);
    if (permission == null) throw _badPayload('permission');
    return permission;
  }

  LocationUnknownError _badPayload(String what) => LocationUnknownError(
    'Invalid $what data from native code',
    code: 'BAD_PAYLOAD',
  );
}
