import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:garipath/features/navigation/presentation/map_camera_controller.dart';
import 'package:latlong2/latlong.dart';

const _dhaka = LatLng(23.8103, 90.4125);
const _carA = LatLng(23.7600, 90.4000);
const _carB = LatLng(23.7650, 90.4050);

void main() {
  late MapCameraController camera;

  setUp(() {
    Get.testMode = true;
    camera = Get.put(MapCameraController());
  });

  tearDown(Get.reset);

  /// A real FlutterMap (no tiles) driven by the camera controller.
  Future<void> pumpMap(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          mapController: camera.mapController,
          options: MapOptions(
            initialCenter: _dhaka,
            initialZoom: 13,
            onMapReady: camera.onMapReady,
            onPositionChanged: (_, hasGesture) =>
                camera.onPositionChanged(hasGesture: hasGesture),
          ),
          children: const [],
        ),
      ),
    );
    await tester.pump();
  }

  LatLng center() => camera.mapController.camera.center;

  testWidgets('our own moves never stop following', (tester) async {
    await pumpMap(tester);
    camera.recenter(_carA, 0);
    await tester.pump();

    camera.followTo(_carB, 0);
    await tester.pump();

    expect(camera.following.value, isTrue);
    expect(center().latitude, closeTo(_carB.latitude, 1e-6));
  });

  testWidgets('dragging the map stops following', (tester) async {
    await pumpMap(tester);
    camera.recenter(_carA, 0);
    await tester.pump();

    await tester.drag(find.byType(FlutterMap), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(camera.following.value, isFalse);

    // While not following, the car moving doesn't move the camera.
    final before = center();
    camera.followTo(_carB, 0);
    await tester.pump();
    expect(center(), before);
  });

  testWidgets('recenter follows again and zooms to at least 16', (
    tester,
  ) async {
    await pumpMap(tester);
    camera.onPositionChanged(hasGesture: true);
    expect(camera.following.value, isFalse);

    camera.recenter(_carA, 0);
    await tester.pump();

    expect(camera.following.value, isTrue);
    expect(center().latitude, closeTo(_carA.latitude, 1e-6));
    expect(camera.mapController.camera.zoom, MapCameraController.followZoom);
  });

  testWidgets('showing my location stops following', (tester) async {
    await pumpMap(tester);
    camera.recenter(_carA, 0);

    camera.showPoint(_dhaka);

    expect(camera.following.value, isFalse);
  });

  testWidgets('following turns the map so the car points up', (tester) async {
    await pumpMap(tester);
    camera.recenter(_carA, 90); // car heading east
    await tester.pump();
    expect(camera.mapController.camera.rotation, closeTo(-90, 1e-9));

    camera.followTo(_carB, 135);
    await tester.pump();
    expect(camera.mapController.camera.rotation, closeTo(-135, 1e-9));
  });

  testWidgets('after a drag the map keeps its angle until Recenter', (
    tester,
  ) async {
    await pumpMap(tester);
    camera.recenter(_carA, 90);
    await tester.pump();
    camera.onPositionChanged(hasGesture: true);

    camera.followTo(_carB, 180);
    await tester.pump();
    expect(camera.mapController.camera.rotation, closeTo(-90, 1e-9));

    camera.recenter(_carB, 180);
    await tester.pump();
    expect(camera.mapController.camera.rotation, closeTo(-180, 1e-9));
  });

  testWidgets('my location, route fit and reset turn the map north up', (
    tester,
  ) async {
    await pumpMap(tester);

    camera.recenter(_carA, 90);
    camera.showPoint(_dhaka);
    await tester.pump();
    expect(camera.mapController.camera.rotation, 0);

    camera.recenter(_carA, 90);
    camera.fitRoute(const [_carA, _carB], EdgeInsets.zero);
    await tester.pump();
    expect(camera.mapController.camera.rotation, 0);

    camera.recenter(_carA, 90);
    camera.resetNorth();
    await tester.pump();
    expect(camera.mapController.camera.rotation, 0);
  });

  test('a move requested before the map is ready waits for it', () {
    camera.recenter(_carA, 0); // no map yet: must not throw

    expect(camera.following.value, isTrue);
  });
}
