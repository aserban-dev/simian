import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:dupermarket/core/cache/cache_policy.dart';
import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:dupermarket/features/catalogue/data/catalogue_repository.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

Map<String, Object?> _categoriesBody(List<String> slugs) => <String, Object?>{
      'items': <Object?>[
        for (int i = 0; i < slugs.length; i++)
          <String, Object?>{
            'id': 'id-${slugs[i]}',
            'slug': slugs[i],
            'name': slugs[i].toUpperCase(),
            'sort_order': i,
            'children': <Object?>[],
          },
      ],
    };

Map<String, Object?> _productsBody(List<String> ids, {String? nextCursor}) => <String, Object?>{
      'items': <Object?>[
        for (final String id in ids)
          <String, Object?>{
            'id': id,
            'title': 'Product $id',
            'price': <String, Object?>{'amount_minor': 1999, 'currency': 'EUR'},
            'thumbnail_url': 'https://cdn/$id.webp',
            'thumbnail_alt': 'Product $id',
            'rating_average': 4.5,
            'rating_count': 10,
            'stock_status': 'in_stock',
          },
      ],
      'next_cursor': nextCursor,
      'currency': 'EUR',
      'currency_fallback': false,
    };

void main() {
  late CacheDatabase cache;
  DateTime now = DateTime.utc(2026, 8, 2, 12);

  setUp(() {
    cache = CacheDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 8, 2, 12);
  });
  tearDown(() async => cache.close());

  CatalogueRepository repo(_StubAdapter adapter, {CachePolicy? policy}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'))
      ..httpClientAdapter = adapter;
    return CatalogueRepository(
      api: ApiClient(
        dio: dio,
        tokenProvider: () async => null,
        hasConnectivity: () => true,
      ),
      cache: cache,
      now: () => now,
      policy: policy ?? CachePolicy.catalogue,
    );
  }

  group('FR-057: cache then network', () {
    test('a cold cache emits once, after the fetch', () async {
      final adapter = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes'])));

      final List<Snapshot<List<Category>>> emissions =
          await repo(adapter).watchCategories().toList();

      expect(emissions, hasLength(1));
      expect(emissions.single.isFromCache, isFalse);
      expect(emissions.single.data.single.slug, 'shoes');
    });

    test('a warm but stale cache emits twice: cached first, then fresh', () async {
      final adapter = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes'])));
      await repo(adapter).watchCategories().toList(); // warm it

      // Move past the TTL so a refresh is due.
      now = now.add(const Duration(hours: 2));
      final adapter2 = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes', 'bags'])));
      final List<Snapshot<List<Category>>> emissions =
          await repo(adapter2).watchCategories().toList();

      expect(emissions, hasLength(2), reason: 'this double emission IS the requirement');
      expect(emissions.first.isFromCache, isTrue);
      expect(emissions.first.data, hasLength(1));
      expect(emissions.last.isFromCache, isFalse);
      expect(emissions.last.data, hasLength(2));
    });

    test('FR-058: a fresh cache does not touch the network at all', () async {
      final adapter = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes'])));
      await repo(adapter).watchCategories().toList();

      now = now.add(const Duration(minutes: 5)); // well inside the hour
      final adapter2 = _StubAdapter((_) => _json(_categoriesBody(<String>['nope'])));
      final List<Snapshot<List<Category>>> emissions =
          await repo(adapter2).watchCategories().toList();

      expect(adapter2.seen, isEmpty, reason: 'a fresh cache means no request');
      expect(emissions.single.data.single.slug, 'shoes');
    });

    test('FR-058: pull-to-refresh fetches even when the cache is fresh', () async {
      final adapter = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes'])));
      await repo(adapter).watchCategories().toList();

      now = now.add(const Duration(minutes: 1));
      final adapter2 = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes', 'bags'])));
      final List<Snapshot<List<Category>>> emissions =
          await repo(adapter2).watchCategories(userRequested: true).toList();

      expect(adapter2.seen, hasLength(1));
      expect(emissions.last.data, hasLength(2));
    });
  });

  group('FR-057: failure while cached content exists', () {
    test('a failed refresh still shows cached content, flagged as stale', () async {
      final adapter = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes'])));
      await repo(adapter).watchCategories().toList();

      now = now.add(const Duration(hours: 2));
      final failing = _StubAdapter((RequestOptions o) {
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      });

      final List<Snapshot<List<Category>>> emissions =
          await repo(failing).watchCategories().toList();

      expect(emissions, hasLength(2));
      expect(emissions.last.data.single.slug, 'shoes',
          reason: 'replacing usable content with an error screen is the FR-057 failure');
      expect(emissions.last.isStale, isTrue);
      expect(emissions.last.failure, isA<ServiceUnreachable>());
    });

    test('a failure with nothing cached surfaces as an error', () async {
      final failing = _StubAdapter((RequestOptions o) {
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      });

      // No cache to fall back on, so the failure IS the screen.
      await expectLater(
        repo(failing).watchCategories().toList(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('cache writes', () {
    test('a category removed upstream disappears from the cache', () async {
      final adapter = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes', 'bags'])));
      await repo(adapter).watchCategories().toList();

      now = now.add(const Duration(hours: 2));
      final adapter2 = _StubAdapter((_) => _json(_categoriesBody(<String>['shoes'])));
      final List<Snapshot<List<Category>>> emissions =
          await repo(adapter2).watchCategories().toList();

      expect(emissions.last.data.map((Category c) => c.slug), <String>['shoes'],
          reason: 'a per-row upsert would leave the removed category behind forever');
    });

    test('FR-002: a cached product page keeps the order the server sent', () async {
      final adapter = _StubAdapter((_) => _json(_productsBody(<String>['c', 'a', 'b'])));
      final CatalogueRepository r = repo(adapter);

      await r.fetchProducts(categorySlug: 'shoes');
      final List<ProductSummary> cached = await r.cachedProductsFor('shoes');

      expect(cached.map((ProductSummary p) => p.id), <String>['c', 'a', 'b']);
    });

    test('only the first unfiltered page of a category is cached', () async {
      // Caching every filter/sort/cursor combination would grow without bound.
      final adapter = _StubAdapter((_) => _json(_productsBody(<String>['a'])));
      final CatalogueRepository r = repo(adapter);

      await r.fetchProducts(categorySlug: 'shoes', query: 'boot');
      expect(await r.cachedProductsFor('shoes'), isEmpty);

      await r.fetchProducts(categorySlug: 'shoes', cursor: 'abc');
      expect(await r.cachedProductsFor('shoes'), isEmpty);

      await r.fetchProducts(categorySlug: 'shoes');
      expect(await r.cachedProductsFor('shoes'), hasLength(1));
    });
  });

  group('paging and filters on the wire', () {
    test('FR-004, FR-005: filters and sort are sent as query parameters', () async {
      final adapter = _StubAdapter((_) => _json(_productsBody(<String>[])));

      await repo(adapter).fetchProducts(
        categorySlug: 'shoes',
        minPriceMinor: 500,
        maxPriceMinor: 2500,
        minRating: 4,
        sort: ProductSort.priceAsc,
      );

      final Map<String, dynamic> params = adapter.seen.single.queryParameters;
      expect(params['category'], 'shoes');
      expect(params['min_price'], 500);
      expect(params['max_price'], 2500);
      expect(params['min_rating'], 4);
      expect(params['sort'], 'price_asc');
    });

    test('FR-002: the cursor from a page is what the next request sends', () async {
      final adapter = _StubAdapter(
        (_) => _json(_productsBody(<String>['a'], nextCursor: 'cursor-1')),
      );
      final CatalogueRepository r = repo(adapter);

      final ProductPage first = await r.fetchProducts(categorySlug: 'shoes');
      expect(first.hasMore, isTrue);

      await r.fetchProducts(categorySlug: 'shoes', cursor: first.nextCursor);
      expect(adapter.seen.last.queryParameters['cursor'], 'cursor-1');
    });

    test('FR-002: a null next_cursor means the last page', () async {
      final adapter = _StubAdapter((_) => _json(_productsBody(<String>['a'])));
      final ProductPage page = await repo(adapter).fetchProducts(categorySlug: 'shoes');
      expect(page.hasMore, isFalse);
    });
  });

  group('decoding degrades rather than throws', () {
    test('FR-061: a product with no image decodes to an empty thumbnail', () async {
      final adapter = _StubAdapter(
        (_) => _json(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{'id': 'a', 'title': 'No image'},
          ],
          'next_cursor': null,
          'currency': 'EUR',
        }),
      );

      final ProductPage page = await repo(adapter).fetchProducts();
      expect(page.items.single.thumbnailUrl, isEmpty);
      expect(page.items.single.title, 'No image');
    });

    test('FR-052: a fallback currency is carried through to the UI', () async {
      final adapter = _StubAdapter(
        (_) => _json(<String, Object?>{
          'items': <Object?>[],
          'next_cursor': null,
          'currency': 'EUR',
          'currency_fallback': true,
        }),
      );

      final ProductPage page = await repo(adapter).fetchProducts();
      expect(page.currencyFallback, isTrue);
    });

    test('FR-078: an unknown stock status does not hide the product', () async {
      final adapter = _StubAdapter(
        (_) => _json(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{'id': 'a', 'title': 'X', 'stock_status': 'something_new'},
          ],
          'next_cursor': null,
          'currency': 'EUR',
        }),
      );

      final ProductPage page = await repo(adapter).fetchProducts();
      expect(page.items, hasLength(1));
      expect(page.items.single.stockStatus, StockStatus.inStock);
    });
  });
}
