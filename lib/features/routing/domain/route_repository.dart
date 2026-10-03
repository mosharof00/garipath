import 'package:garipath/core/util/cancel_signal.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:latlong2/latlong.dart';

/// Thrown when a route request was cancelled on purpose (a newer request
/// replaced it, or the screen closed). Not a [RouteFailure]: the user
/// should never see a message for it.
class RouteRequestCancelled implements Exception {
  const RouteRequestCancelled();

  @override
  String toString() => 'RouteRequestCancelled';
}

/// Gets a driving route between two points.
abstract interface class RouteRepository {
  /// Throws a `RouteFailure` when the route can't be fetched, or
  /// [RouteRequestCancelled] after [cancelSignal] is cancelled.
  Future<RouteModel> fetchRoute({
    required LatLng start,
    required LatLng destination,
    CancelSignal? cancelSignal,
  });
}
