/// What a cart is, independent of how it is stored (T085).
///
/// The rule worth naming here is FR-021: a line whose product has gone away is **flagged and
/// excluded**, not deleted and not blocking. So availability is a property of a line, the
/// subtotal is defined over the available ones, and "can I check out" is defined over whether
/// any remain — three consequences of one requirement, all in one place.
library;

import 'package:meta/meta.dart';

import '../../../core/currency/money.dart';
import '../../catalogue/domain/catalogue_models.dart';

@immutable
class CartEntry {
  const CartEntry({
    required this.productId,
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.thumbnailUrl,
    required this.stockStatus,
    required this.withdrawn,
  });

  final String productId;
  final String title;
  final int quantity;

  /// The price snapshot, in whatever currency it was captured in. Converted for display, never
  /// re-derived — an offline cart has no way to look the price up again.
  final Money unitPrice;

  final String thumbnailUrl;
  final StockStatus stockStatus;

  /// True once the catalogue reports the product gone entirely (FR-021).
  final bool withdrawn;

  /// FR-021 and FR-078: withdrawn or out of stock means it cannot be ordered. Low stock can.
  bool get isAvailable => !withdrawn && stockStatus != StockStatus.outOfStock;

  Money get lineTotal => unitPrice * quantity;

  CartEntry copyWith({int? quantity}) => CartEntry(
        productId: productId,
        title: title,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice,
        thumbnailUrl: thumbnailUrl,
        stockStatus: stockStatus,
        withdrawn: withdrawn,
      );
}

@immutable
class CartSnapshot {
  const CartSnapshot({
    required this.lines,
    required this.displayCurrency,
    required this.currencyFallback,
  });

  final List<CartEntry> lines;

  /// The currency the line prices are actually expressed in. Not necessarily the one that was
  /// asked for — with no rate available, prices fall back to the stored currency (FR-052).
  final String displayCurrency;

  final bool currencyFallback;

  bool get isEmpty => lines.isEmpty;

  List<CartEntry> get orderable => lines.where((CartEntry l) => l.isAvailable).toList();

  List<CartEntry> get unavailable => lines.where((CartEntry l) => !l.isAvailable).toList();

  /// FR-020, FR-021: the running total over the lines that can actually be bought.
  ///
  /// Integer minor units throughout (research D4) — the sum of exact line totals, never a
  /// floating-point accumulation.
  Money get subtotal => orderable.fold(
        Money.zero(displayCurrency),
        (Money running, CartEntry line) => running + line.lineTotal,
      );

  int get itemCount => orderable.fold(0, (int n, CartEntry line) => n + line.quantity);

  /// FR-021: an unavailable line must not block checkout — but a cart of nothing else has
  /// nothing to submit.
  bool get canCheckOut => orderable.isNotEmpty;
}
