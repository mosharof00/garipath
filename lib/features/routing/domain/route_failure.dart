/// Every way getting a route can fail.
///
/// `sealed`, so the UI's `switch` must handle every case. The UI picks the
/// text from the type; [message] is only for logs.
sealed class RouteFailure implements Exception {
  const RouteFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server found no drivable road between the two points.
class RouteNoRoute extends RouteFailure {
  const RouteNoRoute([String? message]) : super(message ?? 'No route found');
}

/// No internet, DNS failure, connection refused.
class RouteNetworkFailure extends RouteFailure {
  const RouteNetworkFailure([String? message])
    : super(message ?? 'Network connection failed');
}

/// The server didn't answer in time.
class RouteTimeout extends RouteFailure {
  const RouteTimeout([String? message])
    : super(message ?? 'Routing server timed out');
}

/// HTTP 429: we sent too many requests.
class RouteRateLimited extends RouteFailure {
  const RouteRateLimited([String? message])
    : super(message ?? 'Routing server rate limit reached');
}

/// HTTP 5xx or another unexpected status.
class RouteServerError extends RouteFailure {
  const RouteServerError({this.statusCode, String? message})
    : super(message ?? 'Routing server error');

  final int? statusCode;
}

/// The answer arrived but didn't have the shape or values we expect.
class RouteInvalidResponse extends RouteFailure {
  const RouteInvalidResponse([String? message])
    : super(message ?? 'Invalid routing response');
}
