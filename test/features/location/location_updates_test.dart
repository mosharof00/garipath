import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/features/location/data/location_channel_contract.dart';
import 'package:garipath/features/location/data/method_channel_location_service.dart';
import 'package:garipath/features/location/domain/location_exception.dart';
import 'package:garipath/features/location/domain/location_fix.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannel = EventChannel(LocationChannels.events);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelLocationService service;
  late MockStreamHandlerEventSink nativeSink;
  late List<Object?> listenArguments;
  late int cancelCount;

  Map<String, Object?> fixMap(double lat) => {
    'lat': lat,
    'lng': 90.41,
    'timestamp': 1759400000000,
  };

  setUp(() {
    service = MethodChannelLocationService();
    listenArguments = [];
    cancelCount = 0;

    // Fake native stream handler: we keep its sink so each test can push
    // events, and we count how often Dart cancels.
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          listenArguments.add(arguments);
          nativeSink = events;
        },
        onCancel: (_) => cancelCount++,
      ),
    );
  });

  tearDown(() => messenger.setMockStreamHandler(eventChannel, null));

  test('sends interval and distance to native on listen', () async {
    final subscription = service
        .locationUpdates(
          interval: const Duration(seconds: 1),
          minDistanceMeters: 3,
        )
        .listen((_) {});
    await pumpEventQueue();

    expect(listenArguments.single, {
      'intervalMs': 1000,
      'minDistanceMeters': 3.0,
    });
    await subscription.cancel();
  });

  test('emits parsed location fixes', () async {
    final fixes = <LocationFix>[];
    final subscription = service.locationUpdates().listen(fixes.add);
    await pumpEventQueue();

    nativeSink.success(fixMap(23.80));
    nativeSink.success(fixMap(23.81));
    await pumpEventQueue();

    expect(fixes.map((f) => f.latitude), [23.80, 23.81]);
    await subscription.cancel();
  });

  test('a native error arrives typed and the stream keeps going', () async {
    final fixes = <LocationFix>[];
    final errors = <Object>[];
    final subscription = service.locationUpdates().listen(
      fixes.add,
      onError: errors.add,
    );
    await pumpEventQueue();

    nativeSink.error(code: 'SERVICES_DISABLED');
    nativeSink.success(fixMap(23.81)); // user turned location back on
    await pumpEventQueue();

    expect(errors.single, isA<LocationServicesDisabled>());
    expect(fixes.single.latitude, 23.81);
    await subscription.cancel();
  });

  test('invalid data becomes an error event instead of a crash', () async {
    final errors = <Object>[];
    final subscription = service.locationUpdates().listen(
      (_) {},
      onError: errors.add,
    );
    await pumpEventQueue();

    nativeSink.success({'lat': 'not a number'});
    await pumpEventQueue();

    expect(errors.single, isA<LocationUnknownError>());
    await subscription.cancel();
  });

  test('cancelling the subscription tells native to stop', () async {
    final subscription = service.locationUpdates().listen((_) {});
    await pumpEventQueue();
    expect(cancelCount, 0);

    await subscription.cancel();
    await pumpEventQueue();

    expect(cancelCount, 1);
  });
}
