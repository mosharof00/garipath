import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:garipath/features/location/domain/location_fix.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:garipath/features/routing/presentation/route_controller.dart';
import 'package:garipath/presentation/widgets/route_summary_card.dart';
import 'package:latlong2/latlong.dart';

import '../fakes/fake_route_repository.dart';
import '../fakes/fake_simulation_clock.dart';

void main() {
  late RouteController controller;
  late NavigationController navigation;

  setUp(() {
    // Created directly (not Get.put), so the test sets the state by hand.
    controller = RouteController(FakeRouteRepository(), Rxn<LocationFix>());
    navigation = NavigationController(
      controller.route,
      FakeSimulationClock(),
      baseSpeedMps: 10,
    );
  });

  Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RouteSummaryCard(controller: controller, navigation: navigation),
      ),
    ),
  );

  void showFailure(RouteFailure failure) {
    controller.failure.value = failure;
    controller.status.value = RouteStatus.error;
  }

  testWidgets('idle shows the long-press hint', (tester) async {
    await pumpCard(tester);

    expect(
      find.text('Long-press on the map to choose a destination.'),
      findsOneWidget,
    );
  });

  testWidgets('ready shows OSRM distance and time', (tester) async {
    controller.route.value = const RouteModel(
      points: [LatLng(23.76, 90.43), LatLng(23.75, 90.42)],
      distanceMeters: 4444.5,
      durationSeconds: 350.5,
    );
    controller.status.value = RouteStatus.ready;
    await pumpCard(tester);

    expect(find.text('4.4 km · 6 min'), findsOneWidget);
  });

  testWidgets('slow loading says so', (tester) async {
    controller.status.value = RouteStatus.loadingSlow;
    await pumpCard(tester);

    expect(find.text('Still finding a route…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('network failure offers Retry', (tester) async {
    showFailure(const RouteNetworkFailure());
    await pumpCard(tester);

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('no route has no Retry (retrying would not help)', (
    tester,
  ) async {
    showFailure(const RouteNoRoute());
    await pumpCard(tester);

    expect(find.textContaining('No drivable route'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('waiting for start offers "Pick start"', (tester) async {
    controller.status.value = RouteStatus.waitingForStart;
    await pumpCard(tester);

    await tester.tap(find.text('Pick start'));
    await tester.pump();

    expect(controller.pickingStart.value, isTrue);
    expect(
      find.text('Long-press on the map to set the start point.'),
      findsOneWidget,
    );
  });
}
