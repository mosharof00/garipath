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
    camera.recenter(_carA);
    await tester.pump();

    camera.followTo(_carB);
    await tester.pump();

    expect(camera.following.value, isTrue);
    expect(center().latitude, closeTo(_carB.latitude, 1e-6));
  });

  testWidgets('dragging the map stops following', (tester) async {
    await pumpMap(tester);
    camera.recenter(_carA);
    await tester.pump();

    await tester.drag(find.byType(FlutterMap), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(camera.following.value, isFalse);

    // While not following, the car moving doesn't move the camera.
    final before = center();
    camera.followTo(_carB);
    await tester.pump();
    expect(center(), before);
  });

  testWidgets('recenter follows again and zooms to at least 16', (
    tester,
  ) async {
    await pumpMap(tester);
    camera.onPositionChanged(hasGesture: true);
    expect(camera.following.value, isFalse);

    camera.recenter(_carA);
    await tester.pump();

    expect(camera.following.value, isTrue);
    expect(center().latitude, closeTo(_carA.latitude, 1e-6));
    expect(camera.mapController.camera.zoom, MapCameraController.followZoom);
  });

  testWidgets('showing my location stops following', (tester) async {
    await pumpMap(tester);
    camera.recenter(_carA);

    camera.showPoint(_dhaka);

    expect(camera.following.value, isFalse);
  });

  test('a move requested before the map is ready waits for it', () {
    camera.recenter(_carA); // no map yet: must not throw

    expect(camera.following.value, isTrue);
  });
}
