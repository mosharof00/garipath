import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

/// Owns the map's [MapController] and every camera move.
///
/// Moving the camera before the map has been laid out throws, so moves
/// requested too early are kept and run in [onMapReady].
class MapCameraController extends GetxController {
  static const locationZoom = 15.0;

  /// Zoom used when the camera starts following the car, unless the user
  /// is already closer.
  static const followZoom = 16.0;

  /// Never zoom in further than this when fitting, so a very short route
  /// doesn't end up at street-sign level.
  static const maxFitZoom = 17.0;

  final mapController = MapController();

  /// True while the camera keeps the car in the centre. Turned off as soon
  /// as the user drags or zooms the map; turned on again by [recenter].
  final following = true.obs;

  bool _mapReady = false;
  VoidCallback? _pendingMove;

  /// Pass to `MapOptions.onMapReady`.
  void onMapReady() {
    _mapReady = true;
    final pending = _pendingMove;
    _pendingMove = null;
    pending?.call();
  }

  /// Call from `MapOptions.onPositionChanged`. Only a finger on the map
  /// stops following; our own camera moves report `hasGesture == false`.
  void onPositionChanged({required bool hasGesture}) {
    if (hasGesture && following.value) following.value = false;
  }

  /// Centres on [point], zooming in to at least [locationZoom]. The user
  /// asked to look somewhere else, so the camera stops following the car.
  void showPoint(LatLng point) {
    following.value = false;
    _runWhenReady(() => _moveTo(point, minZoom: locationZoom));
  }

  /// Keeps the car centred, at the user's current zoom. Does nothing while
  /// the user is looking around (not [following]).
  void followTo(LatLng point) {
    if (!following.value || !_mapReady) return;
    mapController.move(point, mapController.camera.zoom);
  }

  /// "Recenter" button, or playback started: follow the car again.
  void recenter(LatLng point) {
    following.value = true;
    _runWhenReady(() => _moveTo(point, minZoom: followZoom));
  }

  /// Fits the whole route on screen. [padding] keeps it clear of the cards
  /// drawn over the map.
  void fitRoute(List<LatLng> points, EdgeInsets padding) {
    if (points.isEmpty) return;
    _runWhenReady(() {
      // A one-point "route" has no size to fit: just centre on it.
      if (points.length < 2) {
        mapController.move(points.first, maxFitZoom);
        return;
      }
      mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: padding,
          maxZoom: maxFitZoom,
        ),
      );
    });
  }

  void _moveTo(LatLng point, {required double minZoom}) {
    final zoom = mapController.camera.zoom;
    mapController.move(point, zoom < minZoom ? minZoom : zoom);
  }

  void _runWhenReady(VoidCallback move) {
    if (_mapReady) {
      move();
    } else {
      _pendingMove = move; // only the latest request matters
    }
  }

  @override
  void onClose() {
    mapController.dispose();
    super.onClose();
  }
}
