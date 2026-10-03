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

  /// Never zoom in further than this when fitting, so a very short route
  /// doesn't end up at street-sign level.
  static const maxFitZoom = 17.0;

  final mapController = MapController();

  bool _mapReady = false;
  VoidCallback? _pendingMove;

  /// Pass to `MapOptions.onMapReady`.
  void onMapReady() {
    _mapReady = true;
    final pending = _pendingMove;
    _pendingMove = null;
    pending?.call();
  }

  /// Centres on [point], zooming in to at least [locationZoom].
  void showPoint(LatLng point) {
    _runWhenReady(() {
      final zoom = mapController.camera.zoom < locationZoom
          ? locationZoom
          : mapController.camera.zoom;
      mapController.move(point, zoom);
    });
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
