import 'package:dio/dio.dart';
import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/network/failure_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

final _request = RequestOptions(path: '/products');

DioException _error(DioExceptionType type, {Response<dynamic>? response}) =>
    DioException(requestOptions: _request, type: type, response: response);

Response<dynamic> _response(int status, {Object? body}) =>
    Response<dynamic>(requestOptions: _request, statusCode: status, data: body);

void main() {
  group('connectivity versus reachability', () {
    test('FR-059: a connection error while offline is a connectivity failure', () {
      final failure = mapDioException(
        _error(DioExceptionType.connectionError),
        hasConnectivity: false,
      );
      expect(failure, isA<NoConnectivity>());
    });

    test('FR-059: the same error while online is a service failure', () {
      // Identical socket error, opposite diagnosis. This is the distinction FR-059 exists
      // for: one is the user's to fix, the other is not.
      final failure = mapDioException(
        _error(DioExceptionType.connectionError),
        hasConnectivity: true,
      );
      expect(failure, isA<ServiceUnreachable>());
    });

    test('FR-059: a timeout while offline reads as offline, not as a slow shop', () {
      final failure = mapDioException(
        _error(DioExceptionType.receiveTimeout),
        hasConnectivity: false,
      );
      expect(failure, isA<NoConnectivity>(),
          reason: 'telling someone the shop is slow when their wifi is off sends them to '
              'the wrong fix');
    });

    test('FR-059: a timeout while online is flagged as a timeout', () {
      final failure = mapDioException(
        _error(DioExceptionType.sendTimeout),
        hasConnectivity: true,
      );
      expect(failure, isA<ServiceUnreachable>());
      expect((failure as ServiceUnreachable).timedOut, isTrue);
    });
  });

  group('service responses', () {
    test('FR-059: an error response becomes a service error carrying its status', () {
      final failure = mapDioException(
        _error(DioExceptionType.badResponse, response: _response(404)),
        hasConnectivity: true,
      );
      expect(failure, isA<ServiceError>());
      expect((failure as ServiceError).status, 404);
    });

    test('FR-060: a problem document detail is surfaced to the user', () {
      final failure = mapDioException(
        _error(
          DioExceptionType.badResponse,
          response: _response(402, body: <String, Object?>{
            'title': 'That card was declined',
            'detail': 'That card was declined. Try another.',
            'retryable': true,
          }),
        ),
        hasConnectivity: true,
      ) as ServiceError;

      expect(failure.detail, 'That card was declined. Try another.');
      expect(failure.isRetryable, isTrue);
    });

    test('FR-060: a non-JSON error body is not rendered to the user', () {
      // A proxy's HTML error page must never reach the UI (Principle IV).
      final failure = mapDioException(
        _error(
          DioExceptionType.badResponse,
          response: _response(502, body: '<html><body>Bad Gateway</body></html>'),
        ),
        hasConnectivity: true,
      ) as ServiceError;

      expect(failure.detail, isNull);
      expect(failure.isRetryable, isTrue, reason: '5xx is worth retrying');
    });

    test('FR-060: an empty detail is treated as absent rather than shown blank', () {
      final failure = mapDioException(
        _error(
          DioExceptionType.badResponse,
          response: _response(400, body: <String, Object?>{'detail': '   '}),
        ),
        hasConnectivity: true,
      ) as ServiceError;
      expect(failure.detail, isNull);
    });

    test('FR-060: a badResponse with no response at all is retryable, not a dead end', () {
      // Dio reports some transport failures as badResponse with response == null. Mapping
      // that to status 0 made it non-retryable, so the user saw an error with no way forward.
      final failure = mapDioException(
        _error(DioExceptionType.badResponse),
        hasConnectivity: true,
      );
      expect(failure, isA<ServiceUnreachable>());
      expect(failure.isRetryable, isTrue);
    });

    test('FR-060: a 4xx without a retryable flag offers no dead retry', () {
      final failure = mapDioException(
        _error(DioExceptionType.badResponse, response: _response(404)),
        hasConnectivity: true,
      );
      expect(failure.isRetryable, isFalse);
    });
  });

  group('totality', () {
    test('FR-059: every DioExceptionType maps to a failure, none fall through', () {
      for (final type in DioExceptionType.values) {
        for (final online in <bool>[true, false]) {
          final failure = mapDioException(
            _error(type, response: _response(500)),
            hasConnectivity: online,
          );
          expect(failure, isA<AppFailure>(), reason: '$type (online: $online)');
        }
      }
    });

    test('a non-Dio error still becomes a typed failure rather than escaping', () {
      expect(mapUnknownError(StateError('boom')), isA<ServiceError>());
      expect(mapUnknownError(StateError('boom')).isRetryable, isTrue);
    });
  });
}
