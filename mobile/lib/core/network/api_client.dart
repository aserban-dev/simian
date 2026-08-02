/// The HTTP client.
///
/// One place where a request acquires its base URL, its credential, and its failure mapping —
/// so no feature ever builds a raw request and no feature ever sees a [DioException].
library;

import 'package:dio/dio.dart';

import '../config/app_environment.dart';
import '../errors/app_failure.dart';
import 'failure_mapper.dart';

/// Supplies the current Firebase ID token, or null when signed out.
///
/// An interface rather than a direct Firebase call so the client is testable without a
/// Firebase project, and so token refresh stays the auth feature's concern (FR-015).
typedef TokenProvider = Future<String?> Function();

/// Forces a genuinely new ID token, discarding the cached one.
///
/// Separate from [TokenProvider] because the two have different costs: the cached read happens
/// on every request, the forced refresh only after a rejection. Null when there is no credential
/// to renew — signed-out catalogue browsing, for instance.
typedef TokenRefresher = Future<String?> Function();

/// Reports whether the device currently has a usable connection.
///
/// Needed at failure-mapping time: without it, "offline" and "backend down" are the same
/// socket error, and FR-059 requires them to be told apart.
typedef ConnectivityProbe = bool Function();

class ApiException implements Exception {
  const ApiException(this.failure);
  final AppFailure failure;

  @override
  String toString() => 'ApiException(${failure.runtimeType})';
}

class ApiClient {
  ApiClient({
    required Dio dio,
    required TokenProvider tokenProvider,
    required ConnectivityProbe hasConnectivity,
    TokenRefresher? refreshToken,
  })  : _dio = dio,
        _hasConnectivity = hasConnectivity,
        _refreshToken = refreshToken {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          // A retry after renewal carries the token that renewal produced; anything else fetches
          // per request rather than caching here, because the Firebase SDK refreshes on its own
          // schedule and a token cached by us would be the stale one (FR-015).
          final String? token = _renewedToken ?? await tokenProvider();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  factory ApiClient.forEnvironment({
    required AppEnvironment environment,
    required TokenProvider tokenProvider,
    required ConnectivityProbe hasConnectivity,
    TokenRefresher? refreshToken,
    Dio? dio,
  }) {
    final client = dio ?? Dio();
    client.options
      ..baseUrl = environment.apiBaseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 15)
      // Non-2xx is handled by the failure mapper, not by Dio throwing a bare exception with
      // no diagnosis attached.
      ..headers['Accept'] = 'application/json';
    return ApiClient(
      dio: client,
      tokenProvider: tokenProvider,
      hasConnectivity: hasConnectivity,
      refreshToken: refreshToken,
    );
  }

  final Dio _dio;
  final ConnectivityProbe _hasConnectivity;
  final TokenRefresher? _refreshToken;

  /// Set only for the duration of a post-renewal retry. See [_withRenewal].
  String? _renewedToken;

  /// GETs [path] and decodes a JSON object.
  ///
  /// Throws [ApiException] carrying a typed [AppFailure] — never a [DioException], so callers
  /// cannot accidentally surface a transport error to the UI (Principle IV).
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final Response<dynamic> response = await _send(
      () => _dio.get<dynamic>(path, queryParameters: _pruned(query)),
    );
    final dynamic data = response.data;
    if (data is Map<String, dynamic>) return data;
    // A 200 whose body is not an object means the contract and the server disagree.
    throw ApiException(
      ServiceError(status: response.statusCode ?? 200, detail: null, retryable: false),
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
  }) async {
    final Response<dynamic> response = await _send(() => _dio.post<dynamic>(path, data: body));
    final dynamic data = response.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// PATCHes [path]. Used by the profile update that carries the name learned at sign-up.
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
  }) async {
    final Response<dynamic> response = await _send(() => _dio.patch<dynamic>(path, data: body));
    final dynamic data = response.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// Runs [send], renewing the credential once if the server rejects it, and maps every failure
  /// to a typed [AppFailure] on the way out.
  Future<Response<dynamic>> _send(Future<Response<dynamic>> Function() send) async {
    try {
      return await _withRenewal(send);
    } on DioException catch (error) {
      throw ApiException(mapDioException(error, hasConnectivity: _hasConnectivity()));
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      throw ApiException(mapUnknownError(error));
    }
  }

  /// FR-015 — "renew expired credentials without user-visible interruption".
  ///
  /// A 401 is treated as "this token is stale", not as "this user is signed out": the token is
  /// force-refreshed and the request replayed once. Exactly once — a revoked credential returns
  /// 401 no matter how fresh the token is, and retrying that on a loop would hang the action it
  /// is supposed to rescue.
  Future<Response<dynamic>> _withRenewal(Future<Response<dynamic>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      final TokenRefresher? refresh = _refreshToken;
      if (refresh == null || error.response?.statusCode != 401) rethrow;

      final String? renewed = await refresh();
      if (renewed == null || renewed.isEmpty) rethrow;

      _renewedToken = renewed;
      try {
        return await send();
      } finally {
        _renewedToken = null;
      }
    }
  }

  /// Drops null values so an unset filter is absent rather than sent as `?min_price=null`.
  static Map<String, dynamic>? _pruned(Map<String, dynamic>? query) {
    if (query == null) return null;
    final pruned = <String, dynamic>{
      for (final MapEntry<String, dynamic> e in query.entries)
        if (e.value != null) e.key: e.value,
    };
    return pruned.isEmpty ? null : pruned;
  }
}
