import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:garipath/presentation/widgets/navigation_controls.dart';
import 'package:latlong2/latlong.dart';

import '../fakes/fake_simulation_clock.dart';

const _route = RouteModel(
  points: [LatLng(23.75, 90.40), LatLng(23.76, 90.40)], // ~1.1 km
  distanceMeters: 1112,
  durationSeconds: 120,
);

void main() {
  late FakeSimulationClock clock;
  late NavigationController controller;

  setUp(() {
    Get.testMode = true;
    clock = FakeSimulationClock();
    controller = Get.put(
      NavigationController(Rxn<RouteModel>(_route), clock, baseSpeedMps: 10),
    );
  });

  tearDown(Get.reset);

  Future<void> pumpControls(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NavigationControls(controller: controller)),
    ),
  );

  testWidgets('idle: Start, Reset disabled, no stats', (tester) async {
    await pumpControls(tester);

    expect(find.text('Start'), findsOneWidget);
    expect(find.textContaining('Remaining'), findsNothing);
    final reset = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.restart_alt),
    );
    expect(reset.onPressed, isNull);
  });

  testWidgets('Start -> Pause -> Resume', (tester) async {
    await pumpControls(tester);

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(controller.playback.value, PlaybackState.playing);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.textContaining('Remaining'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(controller.playback.value, PlaybackState.playing);
  });

  testWidgets('speed selector changes the multiplier', (tester) async {
    await pumpControls(tester);

    await tester.tap(find.text('5x'));
    await tester.pump();

    expect(controller.multiplier.value, 5);
  });

  testWidgets('at the end: Arrived and Restart', (tester) async {
    await pumpControls(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();

    clock.tickTimes(2000);
    await tester.pump();

    expect(find.text('Arrived'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
  });
}
