/// Transparent credential renewal (T067, FR-015).
///
/// "Renew expired credentials without user-visible interruption" means the *action* succeeds —
/// so a 401 has to become a refresh and a retry inside the client, not a failure the UI has to
/// interpret. What is asserted here is that the retry happens exactly once, carries the new
/// token, and gives up cleanly rather than looping.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final ResponseBody Function(RequestOptions options, int callIndex) respond;
  final List<RequestOptions> seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final int index = seen.length;
    seen.add(options);
    return respond(options, index);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

/// 401 on the first attempt, 200 on every attempt after it — an expired token, then a good one.
_StubAdapter _expiredThenValid() => _StubAdapter(
      (RequestOptions _, int call) =>
          call == 0 ? _json('{"detail":"expired"}', 401) : _json('{"ok":true}', 200),
    );

void main() {
  group('FR-015: a stale token is renewed and the action still succeeds', () {
    test('a 401 triggers a forced refresh and one retry', () async {
      final adapter = _expiredThenValid();
      var refreshes = 0;
      final client = ApiClient(
        dio: _dio(adapter),
        tokenProvider: () async => 'stale',
        refreshToken: () async {
          refreshes++;
          return 'fresh';
        },
        hasConnectivity: () => true,
      );

      final Map<String, dynamic> body = await client.getJson('/me');

      expect(body['ok'], isTrue, reason: 'the action must succeed, not surface the 401');
      expect(refreshes, 1);
      expect(adapter.seen, hasLength(2));
    });

    test('the retry carries the refreshed token, not the stale one', () async {
      final adapter = _expiredThenValid();
      final client = ApiClient(
        dio: _dio(adapter),
        tokenProvider: () async => 'stale',
        refreshToken: () async => 'fresh',
        hasConnectivity: () => true,
      );

      await client.getJson('/me');

      expect(adapter.seen.first.headers['Authorization'], 'Bearer stale');
      expect(adapter.seen.last.headers['Authorization'], 'Bearer fresh');
    });

    test('a write is renewed the same way as a read', () async {
      final adapter = _expiredThenValid();
      final client = ApiClient(
        dio: _dio(adapter),
        tokenProvider: () async => 'stale',
        refreshToken: () async => 'fresh',
        hasConnectivity: () => true,
      );

      await client.patchJson('/me', body: <String, dynamic>{'display_name': 'Sam'});

      expect(adapter.seen, hasLength(2));
      expect(adapter.seen.last.headers['Authorization'], 'Bearer fresh');
    });
  });

  group('the renewal gives up cleanly', () {
    test('a second 401 is surfaced rather than retried again', () async {
      // Without this the client would loop forever against a genuinely revoked credential.
      final adapter = _StubAdapter((RequestOptions _, int __) => _json('{"detail":"no"}', 401));
      final client = ApiClient(
        dio: _dio(adapter),
        tokenProvider: () async => 'stale',
        refreshToken: () async => 'fresh',
        hasConnectivity: () => true,
      );

      await expectLater(
        client.getJson('/me'),
        throwsA(isA<ApiException>().having(
          (ApiException e) => (e.failure as ServiceError).status,
          'status',
          401,
        )),
      );
      expect(adapter.seen, hasLength(2), reason: 'one retry, not a loop');
    });

    test('a refresh that yields nothing surfaces the original 401 without retrying', () async {
      final adapter = _StubAdapter((RequestOptions _, int __) => _json('{"detail":"no"}', 401));
      final client = ApiClient(
        dio: _dio(adapter),
        tokenProvider: () async => 'stale',
        refreshToken: () async => null,
        hasConnectivity: () => true,
      );

      await expectLater(client.getJson('/me'), throwsA(isA<ApiException>()));
      expect(adapter.seen, hasLength(1));
    });

    test('with no refresher configured the 401 is surfaced unchanged', () async {
      // Signed-out catalogue browsing has no credential to renew.
      final adapter = _StubAdapter((RequestOptions _, int __) => _json('{"detail":"no"}', 401));
      final client = ApiClient(
        dio: _dio(adapter),
        tokenProvider: () async => null,
        hasConnectivity: () => true,
      );

      await expectLater(client.getJson('/me'), throwsA(isA<ApiException>()));
      expect(adapter.seen, hasLength(1));
    });

    test('a non-401 failure is never retried', () async {
      var calls = 0;
      final adapter = _StubAdapter((RequestOptions _, int __) {
        calls++;
        return _json('{"detail":"gone"}', 404);
      });
      final client = ApiClient(
        dio: _dio(adapter),
        tokenProvider: () async => 'good',
        refreshToken: () async => 'fresh',
        hasConnectivity: () => true,
      );

      await expectLater(client.getJson('/me'), throwsA(isA<ApiException>()));
      expect(calls, 1);
    });

    test('an offline 401 retry does not mask the connectivity failure', () async {
      final adapter = _StubAdapter((RequestOptions options, int _) {
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });
      final client = ApiClient(
        dio: _dio(adapter),
        tokenProvider: () async => 'stale',
        refreshToken: () async => 'fresh',
        hasConnectivity: () => false,
      );

      await expectLater(
        client.getJson('/me'),
        throwsA(isA<ApiException>().having((ApiException e) => e.failure, 'f', isA<NoConnectivity>())),
      );
    });
  });
}

Dio _dio(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}
