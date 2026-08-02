/// Transport errors → the [AppFailure] taxonomy.
///
/// This is where FR-059 is actually decided. Every network error the app can meet passes
/// through here and comes out as exactly one of four kinds, so the UI never has to guess and
/// never falls through to "something went wrong".
///
/// Pure and synchronous on purpose — no Dio interceptor, no I/O — so the whole decision table
/// is unit-testable.
library;

import 'package:dio/dio.dart';

import '../errors/app_failure.dart';

/// Maps a [DioException] to a failure.
///
/// [hasConnectivity] comes from the connectivity listener. It is the only way to tell
/// "the device has no network" from "the backend did not answer", which FR-059 requires be
/// distinguished — the two produce identical socket errors otherwise.
AppFailure mapDioException(DioException error, {required bool hasConnectivity}) {
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return hasConnectivity
          ? ServiceUnreachable(cause: error)
          : NoConnectivity(cause: error);

    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      // A timeout with no connectivity is still, from the user's side, being offline —
      // telling them the shop is slow when their wifi is off sends them to the wrong fix.
      return hasConnectivity
          ? ServiceUnreachable(cause: error, timedOut: true)
          : NoConnectivity(cause: error);

    case DioExceptionType.badCertificate:
      // Not retryable and not the user's to fix, but it is a service problem, not a
      // connectivity one.
      return ServiceError(
        status: 495,
        detail: "We couldn't verify a secure connection to the shop.",
        cause: error,
      );

    case DioExceptionType.cancel:
      // A cancelled request is usually the user navigating away. Nothing to report, but the
      // taxonomy is total, so it maps to a non-retryable service error the UI can ignore.
      return ServiceError(status: 499, detail: null, cause: error);

    case DioExceptionType.badResponse:
      return _fromResponse(error);
  }
}

AppFailure _fromResponse(DioException error) {
  final response = error.response;

  // A "bad response" with no response at all means we never heard back — a transport failure
  // wearing the wrong type. Mapping it to ServiceError(status: 0) made it non-retryable, which
  // left the user with an error and no way forward: exactly the dead end FR-060 forbids.
  if (response?.statusCode == null) {
    return ServiceUnreachable(cause: error);
  }

  return ServiceError(
    status: response!.statusCode!,
    detail: _problemDetail(response.data),
    retryable: _retryableFromProblem(response.data),
    cause: error,
  );
}

/// Reads `detail` from an RFC 9457 problem document.
///
/// The backend guarantees `detail` is safe to show a user (Principle IV). Anything else —
/// an HTML error page from a proxy, a bare string, a truncated body — yields null, and the
/// UI falls back to its own copy rather than rendering whatever arrived.
String? _problemDetail(Object? body) {
  if (body is! Map) return null;
  final detail = body['detail'];
  return detail is String && detail.trim().isNotEmpty ? detail : null;
}

bool _retryableFromProblem(Object? body) {
  if (body is! Map) return false;
  return body['retryable'] == true;
}

/// Maps anything non-Dio that escapes the network layer.
///
/// Exists so callers can be exhaustive without catching bare [Object]: an unexpected error
/// still becomes a typed failure with a retry, rather than an unhandled exception reaching
/// the widget tree.
AppFailure mapUnknownError(Object error) =>
    ServiceError(status: 0, detail: null, retryable: true, cause: error);
