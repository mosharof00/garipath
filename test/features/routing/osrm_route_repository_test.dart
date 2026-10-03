import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/core/util/cancel_signal.dart';
import 'package:garipath/features/routing/data/osrm_route_repository.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';
import 'package:garipath/features/routing/domain/route_repository.dart';
import 'package:latlong2/latlong.dart';

/// Replaces dio's network layer. Each test decides what "the server" does.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(String body, int status) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _okJson =
    '{"code":"Ok","routes":[{"geometry":"_p~iF~ps|U_ulLnnqC_mqNvxq`@",'
    '"distance":1500.5,"duration":180.2}]}';

void main() {
  const start = LatLng(23.7625, 90.4368);
  const destination = LatLng(23.75, 90.425);

  late FakeHttpAdapter adapter;

  /// A repository whose dio uses [respond] instead of the network.
  OsrmRouteRepository repositoryWith(
    Future<ResponseBody> Function(RequestOptions options) respond,
  ) {
    adapter = FakeHttpAdapter(respond);
    final dio = OsrmRouteRepository.createDio(applicationId: 'test.app')
      ..httpClientAdapter = adapter;
    return OsrmRouteRepository(dio, baseUrl: 'https://osrm.test');
  }

  Future<void> expectFailure<T extends Object>(OsrmRouteRepository repository) {
    return expectLater(
      repository.fetchRoute(start: start, destination: destination),
      throwsA(isA<T>()),
    );
  }

  test('Ok response -> route', () async {
    final repository = repositoryWith((_) async => jsonBody(_okJson, 200));

    final route = await repository.fetchRoute(
      start: start,
      destination: destination,
    );

    expect(route.distanceMeters, 1500.5);
    expect(route.durationSeconds, 180.2);
    expect(route.points, hasLength(3));
  });

  test('sends lng,lat in the URL and a User-Agent header', () async {
    final repository = repositoryWith((_) async => jsonBody(_okJson, 200));

    await repository.fetchRoute(start: start, destination: destination);

    final request = adapter.lastRequest!;
    expect(
      request.uri.toString(),
      startsWith(
        'https://osrm.test/route/v1/driving/'
        '90.436800,23.762500;90.425000,23.750000',
      ),
    );
    expect(request.headers['User-Agent'], 'GariPath (test.app)');
  });

  test('NoRoute with HTTP 400 -> RouteNoRoute', () async {
    final repository = repositoryWith(
      (_) async => jsonBody('{"code":"NoRoute","routes":[]}', 400),
    );

    await expectFailure<RouteNoRoute>(repository);
  });

  test('HTTP 429 -> RouteRateLimited', () async {
    final repository = repositoryWith(
      (_) async => jsonBody('{"message":"Too Many Requests"}', 429),
    );

    await expectFailure<RouteRateLimited>(repository);
  });

  test('HTTP 500 -> RouteServerError with the status', () async {
    final repository = repositoryWith((_) async => jsonBody('{}', 503));

    await expectLater(
      repository.fetchRoute(start: start, destination: destination),
      throwsA(
        isA<RouteServerError>().having((e) => e.statusCode, 'status', 503),
      ),
    );
  });

  test('other unexpected status (404) -> RouteServerError', () async {
    final repository = repositoryWith((_) async => jsonBody('{}', 404));

    await expectFailure<RouteServerError>(repository);
  });

  test('receive timeout -> RouteTimeout', () async {
    final repository = repositoryWith(
      (options) => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 12),
        requestOptions: options,
      ),
    );

    await expectFailure<RouteTimeout>(repository);
  });

  test('connect timeout -> RouteTimeout', () async {
    final repository = repositoryWith(
      (options) => throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 5),
        requestOptions: options,
      ),
    );

    await expectFailure<RouteTimeout>(repository);
  });

  test('connection error -> RouteNetworkFailure', () async {
    final repository = repositoryWith(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
      ),
    );

    await expectFailure<RouteNetworkFailure>(repository);
  });

  test('raw SocketException (no internet) -> RouteNetworkFailure', () async {
    final repository = repositoryWith(
      (_) => throw const SocketException('Network is unreachable'),
    );

    await expectFailure<RouteNetworkFailure>(repository);
  });

  test('body that is not JSON -> RouteInvalidResponse', () async {
    final repository = repositoryWith(
      (_) async => jsonBody('<html>Bad Gateway</html>', 200),
    );

    await expectFailure<RouteInvalidResponse>(repository);
  });

  test('plain text content type is still decoded', () async {
    final repository = repositoryWith(
      (_) async => ResponseBody.fromString(_okJson, 200),
    );

    final route = await repository.fetchRoute(
      start: start,
      destination: destination,
    );

    expect(route.distanceMeters, 1500.5);
  });

  test('cancelling -> RouteRequestCancelled, not a failure', () async {
    final neverAnswers = Completer<ResponseBody>();
    final repository = repositoryWith((_) => neverAnswers.future);
    final signal = CancelSignal();

    final request = repository.fetchRoute(
      start: start,
      destination: destination,
      cancelSignal: signal,
    );
    signal.cancel();

    await expectLater(request, throwsA(isA<RouteRequestCancelled>()));
  });
}
