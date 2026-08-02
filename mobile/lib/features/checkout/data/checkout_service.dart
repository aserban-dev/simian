/// Placing an order (T088, T089).
///
/// Checkout is the single exception to this app's offline-first posture, and the exception is
/// deliberate (Principle VI, FR-029): it requires connectivity, it is **never** queued, and the
/// user is told so in those words. Queuing would mean an order the user believes was placed,
/// arriving minutes later against prices and stock that have moved.
///
/// The other rule here is FR-028/FR-025 as a pair: the cart is emptied only after the server
/// has confirmed, so a decline or a dropped connection leaves it exactly as it was.
library;

import 'package:meta/meta.dart';

import '../../../core/currency/money.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../cart/data/cart_repository.dart';
import '../../cart/domain/cart_models.dart';
import '../demo_cards.dart';

/// The order as the confirmation screen needs it (FR-030).
@immutable
class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.orderNumber,
    required this.total,
    required this.windowStart,
    required this.windowEnd,
  });

  final String id;
  final String orderNumber;
  final Money total;
  final DateTime windowStart;
  final DateTime windowEnd;

  factory PlacedOrder.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> total = (json['total'] as Map<String, dynamic>?) ?? const {};
    final Map<String, dynamic> tracking =
        (json['tracking'] as Map<String, dynamic>?) ?? const {};
    return PlacedOrder(
      id: json['id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      total: Money(
        amountMinor: total['amount_minor'] as int? ?? 0,
        currency: total['currency'] as String? ?? 'EUR',
      ),
      windowStart: DateTime.tryParse(tracking['window_start'] as String? ?? '')?.toUtc() ??
          DateTime.utc(1970),
      windowEnd: DateTime.tryParse(tracking['window_end'] as String? ?? '')?.toUtc() ??
          DateTime.utc(1970),
    );
  }
}

/// The order half of the API, narrowed to what checkout needs.
abstract class OrderApi {
  Future<PlacedOrder> create(Map<String, dynamic> body);
}

class HttpOrderApi implements OrderApi {
  HttpOrderApi(this._client);

  final ApiClient _client;

  @override
  Future<PlacedOrder> create(Map<String, dynamic> body) async =>
      PlacedOrder.fromJson(await _client.postJson('/orders', body: body));
}

/// FR-029: the one failure this app refuses to paper over.
class CheckoutUnavailableOffline implements Exception {
  const CheckoutUnavailableOffline();
}

/// The cart has nothing that can be submitted — empty, or every line flagged (FR-021).
class CheckoutHasNothingToOrder implements Exception {
  const CheckoutHasNothingToOrder();
}

/// FR-025: recoverable, and carries the message the server chose to show the user.
class CheckoutDeclined implements Exception {
  const CheckoutDeclined(this.message);

  final String message;
}

class CheckoutService {
  CheckoutService({
    required OrderApi api,
    required CartRepository cart,
    required ConnectivityProbe hasConnectivity,
  })  : _api = api,
        _cart = cart,
        _hasConnectivity = hasConnectivity;

  final OrderApi _api;
  final CartRepository _cart;
  final ConnectivityProbe _hasConnectivity;

  /// Always false, and a constant rather than a field on purpose: FR-029 forbids queueing, so
  /// there is no queue to report on. Exposed so the requirement is testable rather than merely
  /// unimplemented.
  bool get hasQueuedOrder => false;

  /// Submits the orderable lines and empties the cart on success.
  ///
  /// [idempotencyKey] should be reused when retrying a submission that may have reached the
  /// server: that is what stops a lost *response* from becoming a second order.
  Future<PlacedOrder> placeOrder({
    required String addressId,
    required DemoCard card,
    required String currency,
    String? idempotencyKey,
  }) async {
    // Checked before the cart is even read: an offline checkout must not have side effects.
    if (!_hasConnectivity()) {
      throw const CheckoutUnavailableOffline();
    }

    final CartSnapshot snapshot = await _cart.read(displayCurrency: currency);
    final List<CartEntry> orderable = snapshot.orderable;
    if (orderable.isEmpty) {
      throw const CheckoutHasNothingToOrder();
    }

    final Map<String, dynamic> body = <String, dynamic>{
      // FR-021: flagged lines are excluded here, so the server never sees them.
      'items': <Map<String, dynamic>>[
        for (final CartEntry line in orderable)
          <String, dynamic>{'product_id': line.productId, 'quantity': line.quantity},
      ],
      'address_id': addressId,
      // The entire payment payload: an identifier for a cosmetic card (Principle I).
      'demo_card_id': card.id,
      'currency': currency,
      'idempotency_key': idempotencyKey ?? _newIdempotencyKey(orderable, addressId),
    };

    final PlacedOrder order;
    try {
      order = await _api.create(body);
    } on ApiException catch (error) {
      // A decline is a distinct outcome, not a generic error: the UI has to offer another card
      // rather than a bare retry (FR-025).
      final AppFailure failure = error.failure;
      if (failure is ServiceError && failure.status == 402) {
        throw CheckoutDeclined(
          failure.detail ?? 'That card was declined. Try another one.',
        );
      }
      rethrow;
    }

    // FR-028, and only now: the cart survives every failure above it.
    await _cart.clear();
    return order;
  }

  /// Derived from the submission rather than random, so the retry of a failed attempt reuses it
  /// without the caller having to store anything.
  static String _newIdempotencyKey(List<CartEntry> lines, String addressId) {
    final String basket =
        lines.map((CartEntry l) => '${l.productId}x${l.quantity}').join('|');
    return '$addressId:$basket'.hashCode.toRadixString(16);
  }
}
