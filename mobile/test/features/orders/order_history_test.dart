/// Order history, on screen and from cache (T104, T105).
///
/// FR-057 and Principle VI: with the network down, history renders from the last known state
/// and *says so*. The failure this guards is the common one — an offline app that replaces
/// perfectly good cached content with a full-screen error.
///
/// FR-063: no orders is a designed state, not a blank page.
library;

import 'package:drift/native.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:dupermarket/features/catalogue/data/catalogue_repository.dart' show Snapshot;
import 'package:dupermarket/features/orders/data/order_repository.dart';
import 'package:dupermarket/features/orders/domain/order_models.dart';
import 'package:dupermarket/features/orders/domain/parcel_position.dart';
import 'package:dupermarket/features/orders/presentation/order_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 8, 3, 12);

OrderSummary _order({
  String id = 'o1',
  String number = 'DM-ABC123',
  int totalMinor = 4999,
  DeliveryStage stage = DeliveryStage.shipped,
  int itemCount = 2,
}) =>
    OrderSummary(
      id: id,
      orderNumber: number,
      createdAt: _now.subtract(const Duration(days: 1)),
      total: Money(amountMinor: totalMinor, currency: 'EUR'),
      currentStage: stage,
      itemCount: itemCount,
    );

Widget _screen({
  List<OrderSummary> orders = const <OrderSummary>[],
  bool isStale = false,
  void Function(OrderSummary)? onOpenOrder,
  VoidCallback? onBrowse,
}) =>
    MaterialApp(
      home: OrderHistoryScreen(
        orders: orders,
        isStale: isStale,
        onOpenOrder: onOpenOrder,
        onBrowse: onBrowse,
      ),
    );

/// Answers `/orders` from a script, or fails the way an offline client does.
class _StubApi implements ApiClient {
  _StubApi({this.body, this.failure});

  final Map<String, dynamic>? body;
  final AppFailure? failure;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    calls++;
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
      'current_stage': 'out_for_delivery',
      'item_count': 2,
    };

void main() {
  group('the empty state (T105, FR-063)', () {
    testWidgets('says there are no orders yet', (WidgetTester tester) async {
      await tester.pumpWidget(_screen());

      expect(find.text(OrderHistoryScreen.emptyTitle), findsOneWidget);
      expect(find.text(OrderHistoryScreen.emptyBody), findsOneWidget);
    });

    testWidgets('carries an illustration', (WidgetTester tester) async {
      await tester.pumpWidget(_screen());

      expect(find.byIcon(OrderHistoryScreen.emptyIcon), findsOneWidget);
    });

    testWidgets('offers a route into the catalogue', (WidgetTester tester) async {
      var browsed = 0;
      await tester.pumpWidget(_screen(onBrowse: () => browsed++));

      await tester.tap(find.text(OrderHistoryScreen.browseLabel));
      await tester.pumpAndSettle();

      expect(browsed, 1);
    });

    testWidgets('shows no stale notice when there is nothing to be stale', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_screen(isStale: true));

      expect(find.text(OrderHistoryScreen.staleNotice), findsNothing);
    });
  });

  group('the populated list', () {
    testWidgets('shows each order number', (WidgetTester tester) async {
      await tester.pumpWidget(_screen(orders: <OrderSummary>[
        _order(),
        _order(id: 'o2', number: 'DM-DEF456'),
      ]));

      expect(find.text('DM-ABC123'), findsOneWidget);
      expect(find.text('DM-DEF456'), findsOneWidget);
    });

    testWidgets('shows the delivery stage in words', (WidgetTester tester) async {
      await tester.pumpWidget(_screen(
        orders: <OrderSummary>[_order(stage: DeliveryStage.outForDelivery)],
      ));

      expect(find.text(DeliveryStage.outForDelivery.label), findsOneWidget);
    });

    testWidgets('opening an order reports which one', (WidgetTester tester) async {
      final opened = <String>[];
      await tester.pumpWidget(_screen(
        orders: <OrderSummary>[_order()],
        onOpenOrder: (OrderSummary o) => opened.add(o.id),
      ));

      await tester.tap(find.text('DM-ABC123'));
      await tester.pumpAndSettle();

      expect(opened, <String>['o1']);
    });

    testWidgets('survives a 200% text scale (FR-067)', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: OrderHistoryScreen(orders: <OrderSummary>[_order(), _order(id: 'o2')]),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('cached history with the network down (T104, FR-057)', () {
    late CacheDatabase db;

    setUp(() => db = CacheDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    OrderRepository repository(_StubApi api) => OrderRepository(
          api: api,
          cache: db,
          now: () => _now,
        );

    test('a first fetch populates the cache', () async {
      final api = _StubApi(body: <String, dynamic>{
        'items': <Object?>[_wireOrder()],
      });

      await repository(api).watchHistory().toList();

      expect(await repository(api).cachedHistory(), hasLength(1));
    });

    test('the cached stage survives the round trip', () async {
      // The bug this catches: storing the Dart enum name rather than the contract's spelling,
      // which reads back as `processing` for every out-for-delivery order.
      final api = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repository(api).watchHistory().toList();

      final List<OrderSummary> cached = await repository(api).cachedHistory();

      expect(cached.single.currentStage, DeliveryStage.outForDelivery);
    });

    test('a fresh cache is served without touching the network at all', () async {
      final online = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repository(online).watchHistory().toList();

      final second = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      final emissions = await repository(second).watchHistory().toList();

      expect(second.calls, 0, reason: 'FR-058: inside the TTL there is nothing to fetch');
      expect(emissions.single.data.single.orderNumber, 'DM-ABC123');
    });

    test('history is served from cache when a forced refresh finds no network', () async {
      // Pull-to-refresh, so the fetch genuinely happens and genuinely fails (FR-058).
      final online = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repository(online).watchHistory().toList();

      final offline = _StubApi(failure: const NoConnectivity());
      final List<Snapshot<List<OrderSummary>>> emissions =
          await repository(offline).watchHistory(userRequested: true).toList();

      expect(offline.calls, 1, reason: 'the refresh must have been attempted');
      expect(emissions.last.data.single.orderNumber, 'DM-ABC123');
    });

    test('the offline emission is flagged as stale', () async {
      final online = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repository(online).watchHistory().toList();

      final offline = _StubApi(failure: const NoConnectivity());
      final List<Snapshot<List<OrderSummary>>> emissions =
          await repository(offline).watchHistory(userRequested: true).toList();

      expect(emissions.last.isStale, isTrue);
      expect(emissions.last.failure, isA<NoConnectivity>());
    });

    test('an offline first run with nothing cached surfaces the failure', () async {
      // No content to show, so the failure *is* the screen — there is nothing to degrade to.
      final offline = _StubApi(failure: const NoConnectivity());

      await expectLater(
        repository(offline).watchHistory().toList(),
        throwsA(isA<ApiException>()),
      );
    });

    test('a refreshed page replaces the cached one rather than merging', () async {
      final first = _StubApi(body: <String, dynamic>{
        'items': <Object?>[_wireOrder(), _wireOrder(id: 'o2', number: 'DM-DEF456')],
      });
      await repository(first).watchHistory().toList();

      final second = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repository(second).watchHistory(userRequested: true).toList();

      final List<OrderSummary> cached = await repository(second).cachedHistory();
      expect(cached.map((OrderSummary o) => o.id), <String>['o1']);
    });

    test('cached orders are purged by the sign-out purge (FR-016)', () async {
      final api = _StubApi(body: <String, dynamic>{'items': <Object?>[_wireOrder()]});
      await repository(api).watchHistory().toList();

      await db.clearUserScopedData();

      expect(await repository(api).cachedHistory(), isEmpty);
    });

    test('the catalogue cache survives that purge', () async {
      await db.into(db.cachedCategories).insert(
            CachedCategoriesCompanion.insert(
              id: 'c1',
              slug: 'shoes',
              name: 'Shoes',
              sortOrder: 0,
              fetchedAt: _now,
            ),
          );

      await db.clearUserScopedData();

      expect(await db.select(db.cachedCategories).get(), hasLength(1));
    });
  });

  group('the stale notice on screen (T104)', () {
    testWidgets('is shown when the list came from cache after a failed refresh', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_screen(orders: <OrderSummary>[_order()], isStale: true));

      expect(find.text(OrderHistoryScreen.staleNotice), findsOneWidget);
    });

    testWidgets('the orders are still shown alongside it', (WidgetTester tester) async {
      // The point of FR-057: usable content is not replaced by the notice.
      await tester.pumpWidget(_screen(orders: <OrderSummary>[_order()], isStale: true));

      expect(find.text('DM-ABC123'), findsOneWidget);
    });

    testWidgets('no error screen is shown over the cached content', (WidgetTester tester) async {
      await tester.pumpWidget(_screen(orders: <OrderSummary>[_order()], isStale: true));

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('is absent on a fresh list', (WidgetTester tester) async {
      await tester.pumpWidget(_screen(orders: <OrderSummary>[_order()]));

      expect(find.text(OrderHistoryScreen.staleNotice), findsNothing);
    });
  });
}
