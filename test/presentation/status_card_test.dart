import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/features/location/domain/location_exception.dart';
import 'package:garipath/features/location/presentation/location_controller.dart';
import 'package:garipath/presentation/widgets/status_card.dart';

import '../fakes/fake_location_service.dart';

void main() {
  late FakeLocationService service;
  late LocationController controller;

  setUp(() {
    service = FakeLocationService();
    // Created directly (not Get.put), so onInit doesn't run: the test sets
    // the state by hand.
    controller = LocationController(service);
  });

  tearDown(() => service.dispose());

  Future<void> pumpCard(WidgetTester tester, {VoidCallback? onPickStart}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusCard(
            controller: controller,
            onPickStartOnMap: onPickStart,
          ),
        ),
      ),
    );
  }

  void showError(LocationException error) {
    controller.error.value = error;
    controller.status.value = LocationStatus.error;
  }

  testWidgets('needsPermission: "Use my location" asks for permission', (
    tester,
  ) async {
    controller.status.value = LocationStatus.needsPermission;
    await pumpCard(tester);

    expect(
      find.text('GariPath uses your location as the trip start.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Use my location'));
    await tester.pump();

    expect(service.requestCount, 1);
  });

  testWidgets('acquiring shows a spinner', (tester) async {
    controller.status.value = LocationStatus.acquiring;
    await pumpCard(tester);

    expect(find.text('Finding your location…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ready with precise location shows nothing', (tester) async {
    controller.status.value = LocationStatus.ready;
    await pumpCard(tester);

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('ready with approximate location offers precise', (tester) async {
    controller.status.value = LocationStatus.ready;
    controller.isPrecise.value = false;
    await pumpCard(tester);

    expect(find.text('Use precise location'), findsOneWidget);
  });

  testWidgets('blocked: "Open Settings" opens app settings', (tester) async {
    showError(const LocationPermissionPermanentlyDenied());
    await pumpCard(tester);

    expect(find.text('Location is blocked for GariPath.'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    await tester.pump();

    expect(service.openAppSettingsCount, 1);
  });

  testWidgets('services off: opens location settings', (tester) async {
    showError(const LocationServicesDisabled());
    await pumpCard(tester);

    await tester.tap(find.text('Open Location Settings'));
    await tester.pump();

    expect(service.openLocationSettingsCount, 1);
  });

  testWidgets('timeout offers Retry', (tester) async {
    showError(const LocationTimeout());
    await pumpCard(tester);

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('not supported has no retry button', (tester) async {
    showError(const LocationNotSupported());
    await pumpCard(tester);

    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('"Pick start on map" shows only when a callback is given', (
    tester,
  ) async {
    showError(const LocationPermissionDenied());
    await pumpCard(tester);
    expect(find.text('Pick start on map'), findsNothing);

    var picked = false;
    await pumpCard(tester, onPickStart: () => picked = true);
    await tester.tap(find.text('Pick start on map'));

    expect(picked, isTrue);
  });
}
