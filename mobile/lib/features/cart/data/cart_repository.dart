/// The Drift-backed cart (T085).
///
/// Local-authoritative by design (FR-019): every mutation here is a local write that succeeds
/// with no network, and nothing on this path talks to the server. That is what makes the cart
/// usable offline without a queue, a sync conflict, or a spinner.
///
/// Prices are snapshotted onto the line at add time. Storing the product id alone would be
/// tidier and would make an offline subtotal impossible, which FR-020 requires.
library;

import 'package:drift/drift.dart';

import '../../../core/cache/cache_database.dart';
import '../../../core/currency/currency_service.dart';
import '../../../core/currency/money.dart';
import '../../catalogue/domain/catalogue_models.dart';
import '../domain/cart_models.dart';

class CartRepository {
  CartRepository(this._db, {required CurrencyService currency}) : _currency = currency;

  final CacheDatabase _db;
  final CurrencyService _currency;

  /// Adds [product], or increases the quantity if it is already in the cart (FR-018).
  Future<void> add(ProductSummary product, {int quantity = 1}) async {
    final CartLine? existing = await _lineFor(product.id);
    final int newQuantity = (existing?.quantity ?? 0) + quantity;

    await _db.into(_db.cartLines).insertOnConflictUpdate(
          CartLinesCompanion.insert(
            productId: product.id,
            quantity: newQuantity,
            title: product.title,
            unitPriceMinor: product.price.amountMinor,
            currency: product.price.currency,
            thumbnailUrl: product.thumbnailUrl,
            stockStatus: Value<String>(product.stockStatus.wire),
            addedAt: existing?.addedAt ?? DateTime.now().toUtc(),
          ),
        );
  }

  /// Sets an absolute quantity. Zero or less removes the line, because a cart line of nothing
  /// is not a state worth representing.
  Future<void> setQuantity(String productId, int quantity) async {
    if (quantity < 1) return remove(productId);
    await (_db.update(_db.cartLines)..where(($CartLinesTable t) => t.productId.equals(productId)))
        .write(CartLinesCompanion(quantity: Value<int>(quantity)));
  }

  Future<void> remove(String productId) async {
    await (_db.delete(_db.cartLines)..where(($CartLinesTable t) => t.productId.equals(productId)))
        .go();
  }

  /// FR-028: emptied by a successful checkout, and by sign-out (FR-016).
  Future<void> clear() async => _db.delete(_db.cartLines).go();

  /// FR-021: the product is gone from the catalogue entirely.
  Future<void> markWithdrawn(String productId) async {
    await (_db.update(_db.cartLines)..where(($CartLinesTable t) => t.productId.equals(productId)))
        .write(const CartLinesCompanion(withdrawn: Value<bool>(true)));
  }

  /// FR-078: stock changed while the product sat in the cart.
  Future<void> updateStock(String productId, StockStatus status) async {
    await (_db.update(_db.cartLines)..where(($CartLinesTable t) => t.productId.equals(productId)))
        .write(CartLinesCompanion(stockStatus: Value<String>(status.wire)));
  }

  Future<CartSnapshot> read({required String displayCurrency}) async {
    final List<CartLine> rows = await _ordered().get();
    return _toSnapshot(rows, displayCurrency);
  }

  /// FR-020: "updated immediately on any change" — the UI watches rather than polls.
  Stream<CartSnapshot> watch({required String displayCurrency}) =>
      _ordered().watch().map((List<CartLine> rows) => _toSnapshot(rows, displayCurrency));

  Future<CartLine?> _lineFor(String productId) =>
      (_db.select(_db.cartLines)..where(($CartLinesTable t) => t.productId.equals(productId)))
          .getSingleOrNull();

  /// Oldest first, so the list does not reshuffle when a quantity changes.
  SimpleSelectStatement<$CartLinesTable, CartLine> _ordered() {
    final SimpleSelectStatement<$CartLinesTable, CartLine> query = _db.select(_db.cartLines);
    query.orderBy(<OrderClauseGenerator<$CartLinesTable>>[
      ($CartLinesTable t) => OrderingTerm.asc(t.addedAt),
    ]);
    return query;
  }

  /// Converts every line through the currency seam (FR-051).
  ///
  /// If any conversion falls back, the whole snapshot reports the stored currency rather than
  /// mixing: a cart showing two currencies in one column adds up to nothing meaningful (FR-052).
  CartSnapshot _toSnapshot(List<CartLine> rows, String target) {
    if (rows.isEmpty) {
      return CartSnapshot(
        lines: const <CartEntry>[],
        displayCurrency: target,
        currencyFallback: false,
      );
    }

    // First pass decides the currency for the whole cart; the second expresses every line in
    // it. Two passes rather than one because a fallback on the *last* line still has to govern
    // the first — otherwise the column mixes currencies and the subtotal means nothing.
    final bool fallback = rows.any(
      (CartLine row) => _currency
          .convert(Money(amountMinor: row.unitPriceMinor, currency: row.currency), target)
          .usedFallback,
    );
    final String currency = fallback ? rows.first.currency : target;

    return CartSnapshot(
      lines: <CartEntry>[
        for (final CartLine row in rows)
          CartEntry(
            productId: row.productId,
            title: row.title,
            quantity: row.quantity,
            unitPrice: _currency
                .convert(
                  Money(amountMinor: row.unitPriceMinor, currency: row.currency),
                  currency,
                )
                .money,
            thumbnailUrl: row.thumbnailUrl,
            stockStatus: StockStatus.parse(row.stockStatus),
            withdrawn: row.withdrawn,
          ),
      ],
      displayCurrency: currency,
      currencyFallback: fallback,
    );
  }
}
