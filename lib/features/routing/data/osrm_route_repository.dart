import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:garipath/core/logging/app_logger.dart';
import 'package:garipath/core/util/cancel_signal.dart';
import 'package:garipath/features/routing/data/osrm_response_parser.dart';
import 'package:garipath/features/routing/data/osrm_url_builder.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';
import 'package:garipath/features/routing/domain/route_model.dart';
import 'package:garipath/features/routing/domain/route_repository.dart';
import 'package:latlong2/latlong.dart';

/// [RouteRepository] backed by an OSRM server over HTTP.
class OsrmRouteRepository implements RouteRepository {
  OsrmRouteRepository(this._dio, {required this.baseUrl});

  final Dio _dio;
  final String baseUrl;

  /// A [Dio] with sensible timeouts and a polite User-Agent for the public
  /// demo server.
  static Dio createDio({required String applicationId}) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 12),
        headers: {'User-Agent': 'GariPath ($applicationId)'},
      ),
    );
  }

  @override
  Future<RouteModel> fetchRoute({
    required LatLng start,
    required LatLng destination,
    CancelSignal? cancelSignal,
  }) async {
    final url = OsrmUrlBuilder.route(
      baseUrl: baseUrl,
      start: start,
      destination: destination,
    );

    final cancelToken = CancelToken();
    if (cancelSignal != null) {
      unawaited(cancelSignal.whenCancelled.then((_) => cancelToken.cancel()));
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<Object?>(
        url,
        cancelToken: cancelToken,
        // Read every status ourselves: OSRM sends NoRoute with HTTP 400 and
        // a normal JSON body.
        options: Options(validateStatus: (_) => true),
      );
      final route = _routeFrom(response);
      appLogger.i('Route in ${stopwatch.elapsedMilliseconds}ms: $route');
      return route;
    } on DioException catch (e) {
      final error = _mapDioException(e);
      if (error is RouteFailure) appLogger.w('Route request failed: $error');
      throw error;
    } on RouteFailure catch (e) {
      appLogger.w('Route request failed: $e');
      rethrow;
    }
  }

  RouteModel _routeFrom(Response<Object?> response) {
    final status = response.statusCode ?? 0;
    if (status == 429) throw const RouteRateLimited();
    if (status >= 500) throw RouteServerError(statusCode: status);
    if (status != 200 && status != 400) {
      throw RouteServerError(
        statusCode: status,
        message: 'Unexpected HTTP $status',
      );
    }
    return OsrmResponseParser.parse(_json(response.data));
  }

  /// dio decodes JSON when the server says it's JSON. If it didn't, the
  /// body arrives as text and we decode it here.
  Object? _json(Object? data) {
    if (data is! String) return data;
    try {
      return jsonDecode(data);
    } on FormatException {
      throw const RouteInvalidResponse('Body is not valid JSON');
    }
  }

  /// Turns dio's error into a [RouteFailure], or [RouteRequestCancelled].
  Exception _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.cancel:
        return const RouteRequestCancelled();
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return RouteTimeout('Timed out (${e.type.name})');
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return RouteNetworkFailure('${e.type.name}: ${e.message}');
      case DioExceptionType.badResponse:
        return RouteServerError(statusCode: e.response?.statusCode);
      case DioExceptionType.unknown:
        if (e.error is FormatException) {
          return const RouteInvalidResponse('Body is not valid JSON');
        }
        // Usually a SocketException (no internet) that dio didn't classify.
        return RouteNetworkFailure('${e.error}');
    }
  }
}
