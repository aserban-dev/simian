/// Checkout orchestration (T078, T086, T088, T089).
///
/// Three rules, each with a specific failure it prevents:
///
/// * **Connectivity is a precondition, not an error to recover from** (FR-029). Checkout is the
///   one operation this offline-first app refuses to queue, and the user is told why.
/// * **A successful order empties the cart** (FR-028), and a failed one does not (FR-025).
/// * **Only orderable lines are submitted** (FR-021) — a flagged line is never sent.
library;

import 'package:drift/native.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:dupermarket/core/currency/currency_service.dart';
import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/core/errors/app_failure.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:dupermarket/features/cart/data/cart_repository.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:dupermarket/features/checkout/data/checkout_service.dart';
import 'package:dupermarket/features/checkout/demo_cards.dart';
import 'package:flutter_test/flutter_test.dart';

ProductSummary _product({String id = 'p1', int priceMinor = 4999}) => ProductSummary(
      id: id,
      title: 'Running Shoe',
      price: Money(amountMinor: priceMinor, currency: 'EUR'),
      thumbnailUrl: 'https://cdn.test/$id.webp',
      thumbnailAlt: 'photo',
      ratingAverage: 4.5,
      ratingCount: 10,
      stockStatus: StockStatus.inStock,
    );

/// Records what was submitted and answers with whatever the test scripted.
class FakeOrderApi implements OrderApi {
  FakeOrderApi({this.failWith});

  final Object? failWith;
  final List<Map<String, dynamic>> submissions = <Map<String, dynamic>>[];

  @override
  Future<PlacedOrder> create(Map<String, dynamic> body) async {
    submissions.add(body);
    if (failWith != null) {
      // ignore: only_throw_errors
      throw failWith!;
    }
    return PlacedOrder(
      id: 'order-1',
      orderNumber: 'DM-ABC123',
      total: const Money(amountMinor: 4999, currency: 'EUR'),
      windowStart: DateTime.utc(2026, 8, 3, 12),
      windowEnd: DateTime.utc(2026, 8, 5, 12),
    );
  }
}

void main() {
  late CacheDatabase db;
  late CartRepository cart;

  setUp(() {
    db = CacheDatabase(NativeDatabase.memory());
    cart = CartRepository(db, currency: const CurrencyService());
  });
  tearDown(() async => db.close());

  CheckoutService service(
    FakeOrderApi api, {
    bool online = true,
  }) =>
      CheckoutService(
        api: api,
        cart: cart,
        hasConnectivity: () => online,
      );

  group('connectivity is a precondition (T088, FR-029)', () {
    test('an offline checkout is refused before anything is submitted', () async {
      await cart.add(_product());
      final api = FakeOrderApi();

      await expectLater(
        service(api, online: false).placeOrder(
          addressId: 'addr-1',
          card: DemoCards.visaSuccess,
          currency: 'EUR',
        ),
        throwsA(isA<CheckoutUnavailableOffline>()),
      );
      expect(api.submissions, isEmpty);
    });

    test('nothing is queued for later', () async {
      // The whole point of FR-029: an offline checkout leaves no pending intent behind.
      await cart.add(_product());
      final api = FakeOrderApi();
      final CheckoutService checkout = service(api, online: false);

      await _ignoringFailure(() => checkout.placeOrder(
            addressId: 'addr-1',
            card: DemoCards.visaSuccess,
            currency: 'EUR',
          ));

      expect(checkout.hasQueuedOrder, isFalse);
    });

    test('the cart is untouched by a refused checkout', () async {
      await cart.add(_product());

      await _ignoringFailure(() => service(FakeOrderApi(), online: false)
          .placeOrder(addressId: 'a', card: DemoCards.visaSuccess, currency: 'EUR'));

      expect((await cart.read(displayCurrency: 'EUR')).lines, hasLength(1));
    });
  });

  group('a successful order empties the cart (T089, FR-028)', () {
    test('the cart is empty afterwards', () async {
      await cart.add(_product());

      await service(FakeOrderApi()).placeOrder(
        addressId: 'addr-1',
        card: DemoCards.visaSuccess,
        currency: 'EUR',
      );

      expect((await cart.read(displayCurrency: 'EUR')).isEmpty, isTrue);
    });

    test('the order number is returned for the confirmation screen (FR-030)', () async {
      await cart.add(_product());

      final PlacedOrder order = await service(FakeOrderApi()).placeOrder(
        addressId: 'addr-1',
        card: DemoCards.visaSuccess,
        currency: 'EUR',
      );

      expect(order.orderNumber, 'DM-ABC123');
      expect(order.windowEnd.isAfter(order.windowStart), isTrue);
    });
  });

  group('a failed order leaves the cart alone (FR-025)', () {
    test('a decline does not empty the cart', () async {
      await cart.add(_product());
      final api = FakeOrderApi(
        failWith: const ApiException(
          ServiceError(status: 402, detail: 'That card was declined.', retryable: true),
        ),
      );

      await _ignoringFailure(() =>
          service(api).placeOrder(addressId: 'a', card: DemoCards.decline, currency: 'EUR'));

      expect((await cart.read(displayCurrency: 'EUR')).lines, hasLength(1));
    });

    test('a server error does not empty the cart', () async {
      await cart.add(_product());
      final api = FakeOrderApi(failWith: const ApiException(ServiceUnreachable()));

      await _ignoringFailure(() =>
          service(api).placeOrder(addressId: 'a', card: DemoCards.visaSuccess, currency: 'EUR'));

      expect((await cart.read(displayCurrency: 'EUR')).lines, hasLength(1));
    });
  });

  group('what gets submitted', () {
    test('an unavailable line is not sent (FR-021)', () async {
      await cart.add(_product());
      await cart.add(_product(id: 'p2'));
      await cart.markWithdrawn('p1');
      final api = FakeOrderApi();

      await service(api)
          .placeOrder(addressId: 'a', card: DemoCards.visaSuccess, currency: 'EUR');

      final List<dynamic> items = api.submissions.single['items'] as List<dynamic>;
      expect(items, hasLength(1));
      expect((items.single as Map<String, dynamic>)['product_id'], 'p2');
    });

    test('an empty cart is refused without a request', () async {
      final api = FakeOrderApi();

      await expectLater(
        service(api).placeOrder(addressId: 'a', card: DemoCards.visaSuccess, currency: 'EUR'),
        throwsA(isA<CheckoutHasNothingToOrder>()),
      );
      expect(api.submissions, isEmpty);
    });

    test('a cart of only unavailable lines is refused', () async {
      await cart.add(_product());
      await cart.markWithdrawn('p1');
      final api = FakeOrderApi();

      await expectLater(
        service(api).placeOrder(addressId: 'a', card: DemoCards.visaSuccess, currency: 'EUR'),
        throwsA(isA<CheckoutHasNothingToOrder>()),
      );
    });

    test('the demo card is sent as an identifier and nothing else', () async {
      await cart.add(_product());
      final api = FakeOrderApi();

      await service(api)
          .placeOrder(addressId: 'a', card: DemoCards.visaSuccess, currency: 'EUR');

      final Map<String, dynamic> body = api.submissions.single;
      expect(body['demo_card_id'], 'visa_success');
      expect(body.keys, isNot(contains('card_number')));
    });

    test('an idempotency key is attached so a retry cannot duplicate the order', () async {
      await cart.add(_product());
      final api = FakeOrderApi();

      await service(api)
          .placeOrder(addressId: 'a', card: DemoCards.visaSuccess, currency: 'EUR');

      expect(api.submissions.single['idempotency_key'], isNotEmpty);
    });

    test('retrying after a failure reuses the same key', () async {
      // Otherwise the retry the user makes after a lost response becomes a second order.
      await cart.add(_product());
      final failing = FakeOrderApi(failWith: const ApiException(ServiceUnreachable()));
      final CheckoutService checkout = service(failing);

      await _ignoringFailure(() =>
          checkout.placeOrder(addressId: 'a', card: DemoCards.visaSuccess, currency: 'EUR'));
      final String firstKey = failing.submissions.single['idempotency_key'] as String;

      final retrying = FakeOrderApi();
      await CheckoutService(api: retrying, cart: cart, hasConnectivity: () => true)
          .placeOrder(
        addressId: 'a',
        card: DemoCards.visaSuccess,
        currency: 'EUR',
        idempotencyKey: firstKey,
      );

      expect(retrying.submissions.single['idempotency_key'], firstKey);
    });
  });

  group('the demo cards (T086, FR-023, FR-024)', () {
    test('exactly one card declines', () {
      expect(
        DemoCards.all.where((DemoCard c) => c.declines),
        hasLength(1),
        reason: 'FR-024 needs a deterministic decline, and only one is useful',
      );
    });

    test('at least two cards succeed, so a retry has somewhere to go', () {
      expect(DemoCards.all.where((DemoCard c) => !c.declines).length, greaterThanOrEqualTo(2));
    });

    test('the ids match the contract enum exactly', () {
      expect(
        DemoCards.all.map((DemoCard c) => c.id).toSet(),
        <String>{'visa_success', 'mastercard_success', 'decline'},
      );
    });

    test('no card carries anything resembling a number (Principle I)', () {
      for (final DemoCard card in DemoCards.all) {
        expect(
          RegExp(r'\d').hasMatch(card.label),
          isFalse,
          reason: '${card.label} contains digits; demo cards are cosmetic labels only',
        );
      }
    });

    test('the declining card says so up front', () {
      expect(DemoCards.decline.label.toLowerCase(), contains('decline'));
    });
  });
}

/// Runs [action] and discards whatever it throws.
///
/// The tests below assert on the *state left behind* by a failed checkout, not on the exception
/// itself — that is covered separately — so the failure is deliberately ignored here.
Future<void> _ignoringFailure(Future<void> Function() action) async {
  try {
    await action();
  } on Object {
    // Expected: the assertion that follows is about what survived the failure.
  }
}
