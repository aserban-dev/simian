/// Cache-then-network catalogue access.
///
/// FR-057 in one place: [watchCategories] emits **twice** on a warm cache — once immediately
/// from Drift, once when the network answers — so a screen renders before any request
/// completes and updates in place afterwards. On a cold cache it emits once, after the fetch.
///
/// FR-058: the TTL decides whether the second emission is even attempted;
/// `userRequested: true` (pull-to-refresh) forces it regardless.
library;

import 'package:drift/drift.dart';

import '../../../core/cache/cache_database.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/currency/money.dart';
import '../domain/catalogue_models.dart';

/// One emission of a cache-then-network read.
class Snapshot<T> {
  const Snapshot({
    required this.data,
    required this.isFromCache,
    this.failure,
  });

  final T data;
  final bool isFromCache;

  /// Set when the refresh failed but cached data is being shown anyway. The UI shows the
  /// content plus an unobtrusive notice, never an error screen over usable data (FR-057).
  final AppFailure? failure;

  bool get isStale => isFromCache && failure != null;
}

const String _categoriesCacheKey = 'categories';

class CatalogueRepository {
  CatalogueRepository({
    required ApiClient api,
    required CacheDatabase cache,
    required DateTime Function() now,
    CachePolicy policy = CachePolicy.catalogue,
  })  : _api = api,
        _cache = cache,
        _now = now,
        _policy = policy;

  final ApiClient _api;
  final CacheDatabase _cache;
  final DateTime Function() _now;
  final CachePolicy _policy;

  /// Categories, cache first (FR-001, FR-057).
  Stream<Snapshot<List<Category>>> watchCategories({bool userRequested = false}) async* {
    final List<Category> cached = await _readCachedCategories();
    final DateTime? fetchedAt = await _cacheStamp(_categoriesCacheKey);
    final FetchReason reason = _policy.decide(
      fetchedAt: fetchedAt,
      now: _now(),
      userRequested: userRequested,
    );

    // Emit what we already have before touching the network — this is the requirement.
    if (cached.isNotEmpty && _policy.hasContentToShow(reason)) {
      yield Snapshot<List<Category>>(data: cached, isFromCache: true);
    }

    if (!_policy.shouldFetch(reason)) return;

    try {
      final Map<String, dynamic> json = await _api.getJson('/categories');
      final List<Category> fresh = <Category>[
        for (final Object? item in (json['items'] as List<Object?>?) ?? const <Object?>[])
          if (item is Map<String, dynamic>) Category.fromJson(item),
      ];
      await _writeCategories(fresh);
      yield Snapshot<List<Category>>(data: fresh, isFromCache: false);
    } on ApiException catch (e) {
      if (cached.isEmpty) {
        // Nothing to fall back on: the failure *is* the screen.
        rethrow;
      }
      // We have content. Show it, flagged, rather than replacing it with an error (FR-057).
      yield Snapshot<List<Category>>(
        data: cached,
        isFromCache: true,
        failure: e.failure,
      );
    }
  }

  /// One page of products (FR-002 – FR-005).
  ///
  /// Not cache-then-network: a filtered, sorted, cursor-paged query is a different collection
  /// each time, so caching it by key would grow without bound. The first page of a category is
  /// cached because that is the one a returning user sees first.
  Future<ProductPage> fetchProducts({
    String? categorySlug,
    String? query,
    int? minPriceMinor,
    int? maxPriceMinor,
    double? minRating,
    ProductSort sort = ProductSort.newest,
    String? cursor,
    String? currency,
    int limit = 20,
  }) async {
    final Map<String, dynamic> json = await _api.getJson(
      '/products',
      query: <String, dynamic>{
        'category': categorySlug,
        'q': query,
        'min_price': minPriceMinor,
        'max_price': maxPriceMinor,
        'min_rating': minRating,
        'sort': sort.wire,
        'cursor': cursor,
        'currency': currency,
        'limit': limit,
      },
    );

    final ProductPage page = ProductPage.fromJson(json);

    final bool isFirstPageOfCategory =
        cursor == null && query == null && categorySlug != null && sort == ProductSort.newest;
    if (isFirstPageOfCategory) {
      await _writeProducts(page.items, categorySlug);
    }
    return page;
  }

  /// The cached first page of a category, for rendering before the network answers.
  Future<List<ProductSummary>> cachedProductsFor(String categorySlug) async {
    final List<CachedProduct> rows = await (_cache.select(_cache.cachedProducts)
          ..where(($CachedProductsTable t) => t.categorySlug.equals(categorySlug))
          ..orderBy(<OrderClauseGenerator<$CachedProductsTable>>[
            ($CachedProductsTable t) => OrderingTerm.asc(t.position),
          ]))
        .get();

    return rows.map(_toSummary).toList();
  }

  /// Reviews for a product, newest first, keyset paged (FR-007).
  Future<ReviewPage> fetchReviews(String productId, {String? cursor, int limit = 20}) async {
    final Map<String, dynamic> json = await _api.getJson(
      '/products/$productId/reviews',
      query: <String, dynamic>{'cursor': cursor, 'limit': limit},
    );
    return ReviewPage.fromJson(json);
  }

  Future<ProductDetail> fetchProduct(String id, {String? currency}) async {
    final Map<String, dynamic> json = await _api.getJson(
      '/products/$id',
      query: <String, dynamic>{'currency': currency},
    );
    return ProductDetail.fromJson(json);
  }

  // --- cache plumbing ---------------------------------------------------------------

  Future<DateTime?> _cacheStamp(String key) async {
    final CacheEntry? row = await (_cache.select(_cache.cacheEntries)
          ..where(($CacheEntriesTable t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.fetchedAt;
  }

  Future<List<Category>> _readCachedCategories() async {
    final List<CachedCategory> rows = await (_cache.select(_cache.cachedCategories)
          ..orderBy(<OrderClauseGenerator<$CachedCategoriesTable>>[
            ($CachedCategoriesTable t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .get();
    if (rows.isEmpty) return const <Category>[];

    // Rebuild the tree from flat rows, same shape the API returns.
    final Map<String?, List<CachedCategory>> byParent = <String?, List<CachedCategory>>{};
    for (final CachedCategory row in rows) {
      byParent.putIfAbsent(row.parentId, () => <CachedCategory>[]).add(row);
    }

    Category build(CachedCategory row) => Category(
          id: row.id,
          slug: row.slug,
          name: row.name,
          sortOrder: row.sortOrder,
          imageUrl: row.imageUrl,
          children: (byParent[row.id] ?? const <CachedCategory>[]).map(build).toList(),
        );

    return (byParent[null] ?? const <CachedCategory>[]).map(build).toList();
  }

  Future<void> _writeCategories(List<Category> categories) async {
    final DateTime stamp = _now();
    final List<CachedCategoriesCompanion> rows = <CachedCategoriesCompanion>[];

    void flatten(Category node, String? parentId) {
      rows.add(
        CachedCategoriesCompanion.insert(
          id: node.id,
          slug: node.slug,
          name: node.name,
          sortOrder: node.sortOrder,
          fetchedAt: stamp,
          imageUrl: Value<String?>(node.imageUrl),
          parentId: Value<String?>(parentId),
        ),
      );
      for (final Category child in node.children) {
        flatten(child, node.id);
      }
    }

    for (final Category root in categories) {
      flatten(root, null);
    }

    await _cache.transaction(() async {
      // Replace wholesale: a category removed upstream must disappear here too, and a
      // per-row upsert would leave it behind forever.
      await _cache.delete(_cache.cachedCategories).go();
      await _cache.batch((Batch b) => b.insertAll(_cache.cachedCategories, rows));
      await _cache.into(_cache.cacheEntries).insertOnConflictUpdate(
            CacheEntriesCompanion.insert(key: _categoriesCacheKey, fetchedAt: stamp),
          );
    });
  }

  Future<void> _writeProducts(List<ProductSummary> products, String categorySlug) async {
    final DateTime stamp = _now();
    await _cache.transaction(() async {
      await (_cache.delete(_cache.cachedProducts)
            ..where(($CachedProductsTable t) => t.categorySlug.equals(categorySlug)))
          .go();
      await _cache.batch((Batch b) {
        b.insertAll(
          _cache.cachedProducts,
          <CachedProductsCompanion>[
            for (int i = 0; i < products.length; i++)
              CachedProductsCompanion.insert(
                id: products[i].id,
                title: products[i].title,
                priceMinor: products[i].price.amountMinor,
                currency: products[i].price.currency,
                thumbnailUrl: products[i].thumbnailUrl,
                thumbnailAlt: products[i].thumbnailAlt,
                ratingAverage: products[i].ratingAverage,
                ratingCount: products[i].ratingCount,
                stockStatus: products[i].stockStatus.name,
                position: i,
                fetchedAt: stamp,
                categorySlug: Value<String?>(categorySlug),
                originalPriceMinor: Value<int?>(products[i].originalPrice?.amountMinor),
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  static ProductSummary _toSummary(CachedProduct row) => ProductSummary(
        id: row.id,
        title: row.title,
        price: Money(amountMinor: row.priceMinor, currency: row.currency),
        originalPrice: row.originalPriceMinor == null
            ? null
            : Money(amountMinor: row.originalPriceMinor!, currency: row.currency),
        thumbnailUrl: row.thumbnailUrl,
        thumbnailAlt: row.thumbnailAlt,
        ratingAverage: row.ratingAverage,
        ratingCount: row.ratingCount,
        stockStatus: StockStatus.values.firstWhere(
          (StockStatus s) => s.name == row.stockStatus,
          orElse: () => StockStatus.inStock,
        ),
      );
}
