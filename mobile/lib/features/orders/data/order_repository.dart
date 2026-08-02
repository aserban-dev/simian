/// Order history, cache first (T108).
///
/// FR-057 and Principle VI: history renders from the last known state immediately, then
/// refreshes behind it. With no connection there is no error screen — there is the history the
/// user saw last time, plus a note that it may be out of date.
///
/// FR-016: the cache is user-scoped and is purged by sign-out. That is not wired here; the rows
/// live in `cached_orders`, which `CacheDatabase.userScopedTables` lists, so the existing
/// purge covers it and a test asserts the classification is complete.
library;

import 'package:drift/drift.dart';

import '../../../core/cache/cache_database.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/currency/money.dart';
import '../../../core/network/api_client.dart';
import '../../catalogue/data/catalogue_repository.dart' show Snapshot;
import '../domain/order_models.dart';
import '../domain/parcel_position.dart';

const String orderHistoryCacheKey = 'orders';

class OrderRepository {
  OrderRepository({
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

  /// The first page of history, cache first (FR-031, FR-057).
  ///
  /// Only the first page is cached. Later pages are fetched live: they are what a user scrolls
  /// to deliberately, and caching an unbounded number of them would grow the database without
  /// any offline value.
  Stream<Snapshot<List<OrderSummary>>> watchHistory({bool userRequested = false}) async* {
    final List<OrderSummary> cached = await cachedHistory();
    final DateTime? fetchedAt = await _cacheStamp();
    final FetchReason reason = _policy.decide(
      fetchedAt: fetchedAt,
      now: _now(),
      userRequested: userRequested,
    );

    if (cached.isNotEmpty && _policy.hasContentToShow(reason)) {
      yield Snapshot<List<OrderSummary>>(data: cached, isFromCache: true);
    }

    if (!_policy.shouldFetch(reason)) return;

    try {
      final Map<String, dynamic> json = await _api.getJson('/orders');
      final List<OrderSummary> fresh = <OrderSummary>[
        for (final Object? item in (json['items'] as List<Object?>?) ?? const <Object?>[])
          if (item is Map<String, dynamic>) OrderSummary.fromJson(item),
      ];
      await _writeHistory(fresh);
      yield Snapshot<List<OrderSummary>>(data: fresh, isFromCache: false);
    } on ApiException catch (e) {
      if (cached.isEmpty) {
        // Nothing to fall back on: the failure is the screen.
        rethrow;
      }
      // FR-057: usable content stays on screen, flagged — never replaced by an error.
      yield Snapshot<List<OrderSummary>>(
        data: cached,
        isFromCache: true,
        failure: e.failure,
      );
    }
  }

  /// One order in full, including the tracking payload (FR-036).
  ///
  /// Not cached: it is only interesting while a delivery is in flight, and the map recomputes
  /// the parcel position from the clock anyway.
  Future<OrderDetail> fetchOrder(String id) async =>
      OrderDetail.fromJson(await _api.getJson('/orders/$id'));

  Future<List<OrderSummary>> cachedHistory() async {
    final query = _cache.select(_cache.cachedOrders);
    query.orderBy(<OrderClauseGenerator<$CachedOrdersTable>>[
      ($CachedOrdersTable t) => OrderingTerm.asc(t.position),
    ]);
    final List<CachedOrder> rows = await query.get();
    return <OrderSummary>[
      for (final CachedOrder row in rows)
        OrderSummary(
          id: row.id,
          orderNumber: row.orderNumber,
          createdAt: row.createdAt,
          total: Money(amountMinor: row.totalMinor, currency: row.currency),
          currentStage: DeliveryStage.parse(row.currentStage),
          itemCount: row.itemCount,
          thumbnailUrl: row.thumbnailUrl,
        ),
    ];
  }

  Future<DateTime?> _cacheStamp() async {
    final CacheEntry? entry = await (_cache.select(_cache.cacheEntries)
          ..where(($CacheEntriesTable t) => t.key.equals(orderHistoryCacheKey)))
        .getSingleOrNull();
    return entry?.fetchedAt;
  }

  /// Replaces the cached page wholesale.
  ///
  /// A merge would leave an order that no longer appears — cancelled, or pushed off the first
  /// page — visible forever, because nothing would ever delete it.
  Future<void> _writeHistory(List<OrderSummary> orders) async {
    final DateTime stamp = _now();
    await _cache.transaction(() async {
      await _cache.delete(_cache.cachedOrders).go();
      for (final (int index, OrderSummary order) in orders.indexed) {
        await _cache.into(_cache.cachedOrders).insert(
              CachedOrdersCompanion.insert(
                id: order.id,
                orderNumber: order.orderNumber,
                createdAt: order.createdAt,
                totalMinor: order.total.amountMinor,
                currency: order.total.currency,
                currentStage: order.currentStage.wire,
                itemCount: order.itemCount,
                thumbnailUrl: Value<String?>(order.thumbnailUrl),
                position: index,
                fetchedAt: stamp,
              ),
            );
      }
      await _cache.into(_cache.cacheEntries).insertOnConflictUpdate(
            CacheEntriesCompanion.insert(key: orderHistoryCacheKey, fetchedAt: stamp),
          );
    });
  }
}
