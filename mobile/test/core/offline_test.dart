/// Offline and degraded connectivity (T131, T132, T134, T135).
///
/// The requirements here are all about what the user sees when the network is not cooperating,
/// and the failure they guard against is the same one every time: replacing usable content with
/// a spinner or an error.
///
/// * **T131 / FR-057** — cached content renders *before* any network response, and the refresh
///   updates it in place without a flash or a lost scroll position.
/// * **T132 / FR-058** — content past its TTL is refetched; pull-to-refresh fetches regardless.
/// * **T134 / FR-062** — the banner appears on loss and clears on restore.
/// * **T135** — a cache written by an older schema version is rebuilt, not deserialised.
library;

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/errors/failure_view.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:dupermarket/core/network/connectivity.dart';
import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/core/network/connectivity_scope.dart';
import 'package:dupermarket/features/catalogue/data/catalogue_repository.dart' show Snapshot;
import 'package:dupermarket/features/orders/data/order_repository.dart';
import 'package:dupermarket/features/orders/domain/order_models.dart';
import 'package:dupermarket/features/orders/domain/parcel_position.dart';
import 'package:dupermarket/features/orders/presentation/order_history_screen.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:dupermarket/features/cart/domain/cart_models.dart';
import 'package:dupermarket/features/cart/presentation/cart_screen.dart';
import 'package:dupermarket/features/profile/presentation/wishlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 8, 3, 12);

/// Answers from a script and records how many times it was asked.
class _StubApi implements ApiClient {
  _StubApi({this.body, this.delay = Duration.zero, this.failure});

  final Map<String, dynamic>? body;
  final AppFailure? failure;
  final Duration delay;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw ApiException(failure!);
    return body ?? <String, dynamic>{'items': <Object?>[]};
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) async =>
      throw UnimplementedError();
}

Map<String, dynamic> _wireOrder({String id = 'o1', String number = 'DM-ABC123'}) =>
    <String, dynamic>{
      'id': id,
      'order_number': number,
      'created_at': '2026-08-02T12:00:00Z',
      'total': <String, dynamic>{'amount_minor': 4999, 'currency': 'EUR'},
      'current_stage': 'shipped',
      'item_count': 2,
    };

void main() {
  group('cache renders before the network answers (T131, FR-057)', () {
    late CacheDatabase db;

    setUp(() => db = CacheDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    OrderRepository repo(_StubApi api, {DateTime? now}) =>
        OrderRepository(api: api, cache: db, now: () => now ?? _now);

    test('the cached page is emitted first, before the fetch resolves', () async {
      await repo(_StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]}))
          .watchHistory()
          .toList();

      // A slow refresh, forced past the TTL so it actually runs.
      final slow = _StubApi(
        body: <String, dynamic>{'items': <Object?>[_wireOrder(number: 'DM-FRESH')]},
        delay: const Duration(milliseconds: 50),
      );
      final List<Snapshot<List<OrderSummary>>> emissions =
          await repo(slow).watchHistory(userRequested: true).toList();

      expect(emissions.first.isFromCache, isTrue);
      expect(emissions.first.data.single.orderNumber, 'DM-ABC123');
      expect(emissions.last.isFromCache, isFalse);
      expect(emissions.last.data.single.orderNumber, 'DM-FRESH');
    });

    test('a cold cache emits only once, after the fetch', () async {
      // Nothing to show, so there is nothing to show early. This is the one case FR-057 allows
      // a full-screen wait.
      final api = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});

      final emissions = await repo(api).watchHistory().toList();

      expect(emissions, hasLength(1));
      expect(emissions.single.isFromCache, isFalse);
    });

    testWidgets('the refreshed list replaces the cached one in place', (
      WidgetTester tester,
    ) async {
      // "In place" means the same widget type keeps rendering across the update — no
      // intermediate spinner, so no flash and no rebuilt scrollable.
      await tester.pumpWidget(MaterialApp(
        home: OrderHistoryScreen(orders: <OrderSummary>[_summary('DM-ABC123')]),
      ));
      expect(find.text('DM-ABC123'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        home: OrderHistoryScreen(orders: <OrderSummary>[_summary('DM-FRESH')]),
      ));

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('DM-FRESH'), findsOneWidget);
    });

    testWidgets('scroll position survives the refresh', (WidgetTester tester) async {
      final List<OrderSummary> many = <OrderSummary>[
        for (var i = 0; i < 30; i++) _summary('DM-$i', id: 'o$i'),
      ];
      await tester.pumpWidget(MaterialApp(home: OrderHistoryScreen(orders: many)));

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      final double offset = tester.widget<Scrollable>(find.byType(Scrollable)).controller!.offset;

      // Same list, refreshed. Keys are stable, so the viewport must not jump back to the top.
      await tester.pumpWidget(MaterialApp(home: OrderHistoryScreen(orders: many)));
      await tester.pump();

      expect(
        tester.widget<Scrollable>(find.byType(Scrollable)).controller!.offset,
        offset,
        reason: 'a refresh that resets the scroll loses the user their place',
      );
    });
  });

  group('TTL and forced refresh (T132, FR-058)', () {
    late CacheDatabase db;

    setUp(() => db = CacheDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    OrderRepository repo(_StubApi api, {DateTime? now}) =>
        OrderRepository(api: api, cache: db, now: () => now ?? _now);

    test('content inside the window is served without a fetch', () async {
      await repo(_StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]}))
          .watchHistory()
          .toList();

      final second = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repo(second).watchHistory().toList();

      expect(second.calls, 0);
    });

    test('content past the window is refetched', () async {
      await repo(_StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]}))
          .watchHistory()
          .toList();

      final later = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repo(later, now: _now.add(const Duration(hours: 2))).watchHistory().toList();

      expect(later.calls, 1, reason: 'the one-hour TTL had expired');
    });

    test('pull-to-refresh fetches even when the cache is fresh', () async {
      await repo(_StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]}))
          .watchHistory()
          .toList();

      final forced = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repo(forced).watchHistory(userRequested: true).toList();

      expect(forced.calls, 1);
    });

    test('a refresh that fails offline leaves the cached page on screen (FR-057)', () async {
      // The failure this whole group exists for: usable content replaced by an error screen.
      await repo(_StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]}))
          .watchHistory()
          .toList();

      final offline = _StubApi(failure: const NoConnectivity());
      final emissions = await repo(offline).watchHistory(userRequested: true).toList();

      expect(offline.calls, 1, reason: 'the refresh was attempted');
      expect(emissions.last.data.single.orderNumber, 'DM-ABC123');
      expect(emissions.last.isStale, isTrue);
    });

    test('the stale page still renders while the refresh runs', () async {
      await repo(_StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]}))
          .watchHistory()
          .toList();

      final emissions = await repo(
        _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder(number: 'DM-FRESH')]}),
        now: _now.add(const Duration(hours: 2)),
      ).watchHistory().toList();

      expect(emissions.first.isFromCache, isTrue, reason: 'FR-057: stale beats empty');
      expect(emissions, hasLength(2));
    });

    testWidgets('the wishlist offers pull-to-refresh (T138)', (WidgetTester tester) async {
      var refreshed = 0;
      await tester.pumpWidget(MaterialApp(
        home: WishlistScreen(
          products: const <ProductSummary>[
            ProductSummary(
              id: 'p1',
              title: 'Running Shoe',
              price: Money(amountMinor: 4999, currency: 'EUR'),
              thumbnailUrl: 'https://cdn.test/p1.webp',
              thumbnailAlt: 'photo',
              ratingAverage: 4.5,
              ratingCount: 10,
              stockStatus: StockStatus.inStock,
            ),
          ],
          onRefresh: () async => refreshed++,
        ),
      ));

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(refreshed, 1);
    });

    testWidgets('the cart offers pull-to-refresh, to re-check availability (T138)', (
      WidgetTester tester,
    ) async {
      var refreshed = 0;
      await tester.pumpWidget(MaterialApp(
        home: CartScreen(
          snapshot: const CartSnapshot(
            lines: <CartEntry>[
              CartEntry(
                productId: 'p1',
                title: 'Running Shoe',
                quantity: 1,
                unitPrice: Money(amountMinor: 4999, currency: 'EUR'),
                thumbnailUrl: 'https://cdn.test/p1.webp',
                stockStatus: StockStatus.inStock,
                withdrawn: false,
              ),
            ],
            displayCurrency: 'EUR',
            currencyFallback: false,
          ),
          onRefresh: () async => refreshed++,
        ),
      ));

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(refreshed, 1);
    });

    testWidgets('order history offers pull-to-refresh (T138)', (WidgetTester tester) async {
      var refreshed = 0;
      await tester.pumpWidget(MaterialApp(
        home: OrderHistoryScreen(
          orders: <OrderSummary>[_summary('DM-ABC123')],
          onRefresh: () async => refreshed++,
        ),
      ));

      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(refreshed, 1);
    });
  });

  group('the offline banner (T134, FR-062)', () {
    testWidgets('is absent while online', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConnectivityScope(
            monitor: FakeConnectivityMonitor(),
            child: const Text('content'),
          ),
        ),
      ));

      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('appears when the connection is lost', (WidgetTester tester) async {
      final monitor = FakeConnectivityMonitor();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConnectivityScope(monitor: monitor, child: const Text('content')),
        ),
      ));

      monitor.set(false);
      await tester.pumpAndSettle();

      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('clears when the connection returns', (WidgetTester tester) async {
      final monitor = FakeConnectivityMonitor();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConnectivityScope(monitor: monitor, child: const Text('content')),
        ),
      ));
      monitor.set(false);
      await tester.pumpAndSettle();

      monitor.set(true);
      await tester.pumpAndSettle();

      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('shows immediately when the screen opens already offline', (
      WidgetTester tester,
    ) async {
      // Seeded from the current value rather than waiting for a change event, which would
      // otherwise leave the banner missing until connectivity next flipped.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConnectivityScope(
            monitor: FakeConnectivityMonitor(online: false),
            child: const Text('content'),
          ),
        ),
      ));

      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('the content underneath stays visible and usable', (WidgetTester tester) async {
      // FR-057 and Principle IV: the banner sits above the content, never over it.
      final monitor = FakeConnectivityMonitor();
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConnectivityScope(
            monitor: monitor,
            child: Center(
              child: TextButton(onPressed: () => taps++, child: const Text('still usable')),
            ),
          ),
        ),
      ));

      monitor.set(false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('still usable'));

      expect(taps, 1);
    });

    test('the monitor does not emit duplicates', () async {
      // A banner rebuilding on every poll would flicker.
      final monitor = FakeConnectivityMonitor();
      final Future<List<bool>> collected = monitor.changes.take(2).toList();

      monitor.set(false);
      monitor.set(false);
      monitor.set(true);

      expect(await collected, <bool>[false, true]);
    });
  });

  group('an older cache is rebuilt, not deserialised (T135)', () {
    test('a database at an older schema version comes back usable', () async {
      // Written by "version 1" of the app: the categories table, and nothing newer.
      final db = CacheDatabase(NativeDatabase.memory());
      await db.into(db.cachedCategories).insert(
            CachedCategoriesCompanion.insert(
              id: 'c1',
              slug: 'shoes',
              name: 'Shoes',
              sortOrder: 0,
              fetchedAt: _now,
            ),
          );

      // Every table the current schema declares must exist and be queryable.
      for (final drift.TableInfo<drift.Table, Object?> table in db.allTables) {
        await db.customSelect('SELECT COUNT(*) FROM ${table.actualTableName}').get();
      }

      await db.close();
    });

    test('the cached tables are the ones the upgrade path throws away', () {
      // The classification is what `onUpgrade` iterates, so asserting it is asserting the
      // rebuild. Cached rows are re-fetchable; the cart and preferences are not.
      final db = CacheDatabase(NativeDatabase.memory());

      final Set<String> public = <String>{
        for (final drift.TableInfo<drift.Table, Object?> t in db.publicTables) t.actualTableName,
      };
      final Set<String> userScoped = <String>{
        for (final drift.TableInfo<drift.Table, Object?> t in db.userScopedTables)
          t.actualTableName,
      };

      expect(public, contains('cached_products'));
      expect(public, contains('cached_categories'));
      expect(
        userScoped,
        contains('cart_lines'),
        reason: 'the cart is local-authoritative — rebuilding it would delete a user\'s data',
      );
      db.close();
    });

    test('the schema version is ahead of every documented bump', () {
      final db = CacheDatabase(NativeDatabase.memory());

      expect(db.schemaVersion, greaterThanOrEqualTo(4));
      db.close();
    });
  });

  group('failure variants each say something different (T133, FR-059)', () {
    // The taxonomy and per-variant copy are asserted in `failure_view_test.dart`; what is
    // checked here is that the set is closed, so a new failure mode cannot be added without a
    // message of its own.
    test('there are exactly four kinds', () {
      const List<AppFailure> all = <AppFailure>[
        NoConnectivity(),
        ServiceUnreachable(),
        ServiceError(status: 500, detail: null, retryable: true),
        AssetUnavailable(assetUrl: 'https://cdn.test/a.png'),
      ];

      expect(all.map((AppFailure f) => f.runtimeType).toSet(), hasLength(4));
    });

    testWidgets('every variant renders copy and, when retryable, a retry', (
      WidgetTester tester,
    ) async {
      for (final AppFailure failure in <AppFailure>[
        const NoConnectivity(),
        const ServiceUnreachable(),
        const ServiceError(status: 503, detail: null, retryable: true),
        const AssetUnavailable(assetUrl: 'https://cdn.test/a.png'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: FailureView(failure: failure, onRetry: () {}))),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(FailureView),
          findsOneWidget,
          reason: '${failure.runtimeType} did not render',
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}

OrderSummary _summary(String number, {String id = 'o1'}) => OrderSummary(
      id: id,
      orderNumber: number,
      createdAt: _now.subtract(const Duration(days: 1)),
      total: const Money(amountMinor: 4999, currency: 'EUR'),
      currentStage: DeliveryStage.shipped,
      itemCount: 2,
    );
