import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers requests from a table, so the tests exercise the real Dio pipeline — interceptors
/// included — without a network or a server.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
  dio.httpClientAdapter = adapter;
  return dio;
}

ApiClient _client(
  _StubAdapter adapter, {
  String? token,
  bool online = true,
}) =>
    ApiClient(
      dio: _dioWith(adapter),
      tokenProvider: () async => token,
      hasConnectivity: () => online,
    );

void main() {
  group('credentials', () {
    test('a token is attached as a bearer header on every request', () {
      final adapter = _StubAdapter(
        (_) => ResponseBody.fromString('{"items":[]}', 200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            }),
      );

      return _client(adapter, token: 'id-token-123').getJson('/products').then((_) {
        expect(adapter.seen.single.headers['Authorization'], 'Bearer id-token-123');
      });
    });

    test('a signed-out request carries no Authorization header at all', () async {
      // FR-010: catalogue reads are public. An empty bearer header is not the same as none,
      // and some gateways reject it.
      final adapter = _StubAdapter(
        (_) => ResponseBody.fromString('{"items":[]}', 200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            }),
      );

      await _client(adapter, token: null).getJson('/products');
      expect(adapter.seen.single.headers.containsKey('Authorization'), isFalse);
    });

    test('FR-015: the token is fetched per request, not cached by the client', () async {
      var calls = 0;
      final adapter = _StubAdapter(
        (_) => ResponseBody.fromString('{}', 200, headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        }),
      );
      final client = ApiClient(
        dio: _dioWith(adapter),
        tokenProvider: () async {
          calls++;
          return 'token-$calls';
        },
        hasConnectivity: () => true,
      );

      await client.getJson('/products');
      await client.getJson('/products');

      expect(calls, 2, reason: 'a token cached here would be the stale one after a refresh');
      expect(adapter.seen.last.headers['Authorization'], 'Bearer token-2');
    });
  });

  group('query parameters', () {
    test('unset filters are omitted rather than sent as null', () async {
      final adapter = _StubAdapter(
        (_) => ResponseBody.fromString('{"items":[]}', 200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            }),
      );

      await _client(adapter).getJson('/products', query: <String, dynamic>{
        'category': 'shoes',
        'min_price': null,
        'max_price': 2500,
      });

      final params = adapter.seen.single.queryParameters;
      expect(params.containsKey('min_price'), isFalse);
      expect(params['category'], 'shoes');
      expect(params['max_price'], 2500);
    });
  });

  group('failures never escape untyped', () {
    test('FR-059: an error response arrives as a typed ServiceError, not a DioException',
        () async {
      final adapter = _StubAdapter(
        (_) => ResponseBody.fromString(
          '{"detail":"We couldn\'t find that product.","retryable":false}',
          404,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['application/problem+json'],
          },
        ),
      );

      await expectLater(
        _client(adapter).getJson('/products/missing'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.failure,
            'failure',
            isA<ServiceError>().having((ServiceError f) => f.status, 'status', 404),
          ),
        ),
      );
    });

    test('FR-059: a transport error while offline arrives as NoConnectivity', () async {
      final adapter = _StubAdapter((RequestOptions options) {
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });

      await expectLater(
        _client(adapter, online: false).getJson('/products'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.failure, 'failure', isA<NoConnectivity>()),
        ),
      );
    });

    test('FR-060: the problem detail survives the round trip to the UI layer', () async {
      final adapter = _StubAdapter(
        (_) => ResponseBody.fromString(
          '{"detail":"That card was declined. Try another.","retryable":true}',
          402,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['application/problem+json'],
          },
        ),
      );

      try {
        await _client(adapter).postJson('/orders', body: <String, dynamic>{});
        fail('expected an ApiException');
      } on ApiException catch (e) {
        final failure = e.failure as ServiceError;
        expect(failure.detail, 'That card was declined. Try another.');
        expect(failure.isRetryable, isTrue);
      }
    });

    test('a 200 whose body is not an object is a contract violation, not a crash', () async {
      final adapter = _StubAdapter(
        (_) => ResponseBody.fromString('[1,2,3]', 200, headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        }),
      );

      await expectLater(
        _client(adapter).getJson('/products'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
