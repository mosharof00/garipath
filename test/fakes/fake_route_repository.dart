import 'dart:async';

import 'package:garipath/core/util/cancel_signal.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:garipath/features/routing/domain/route_repository.dart';
import 'package:latlong2/latlong.dart';

/// One request the controller made. The test answers it whenever it wants,
/// which makes "late" and "out of order" answers easy to simulate.
class FakeRouteRequest {
  FakeRouteRequest(this.start, this.destination, this.cancelSignal);

  final LatLng start;
  final LatLng destination;
  final CancelSignal? cancelSignal;
  final _completer = Completer<RouteModel>();

  Future<RouteModel> get future => _completer.future;
  bool get isAnswered => _completer.isCompleted;
  bool get wasCancelled => cancelSignal?.isCancelled ?? false;

  void succeed(RouteModel route) {
    if (!isAnswered) _completer.complete(route);
  }

  void fail(RouteFailure failure) {
    if (!isAnswered) _completer.completeError(failure);
  }
}

class FakeRouteRepository implements RouteRepository {
  /// When true, cancelling a request answers it with [RouteRequestCancelled]
  /// like the real repository. Set to false to test the request-id guard on
  /// its own.
  bool honorCancel = true;

  final requests = <FakeRouteRequest>[];

  FakeRouteRequest get last => requests.last;

  @override
  Future<RouteModel> fetchRoute({
    required LatLng start,
    required LatLng destination,
    CancelSignal? cancelSignal,
  }) {
    final request = FakeRouteRequest(start, destination, cancelSignal);
    requests.add(request);
    if (honorCancel && cancelSignal != null) {
      unawaited(
        cancelSignal.whenCancelled.then((_) {
          if (!request.isAnswered) {
            request._completer.completeError(const RouteRequestCancelled());
          }
        }),
      );
    }
    return request.future;
  }
}

/// A simple route from [start] to [destination] for tests.
RouteModel fakeRoute(
  LatLng start,
  LatLng destination, {
  double meters = 1000,
}) => RouteModel(
  points: [start, destination],
  distanceMeters: meters,
  durationSeconds: meters / 10,
);
