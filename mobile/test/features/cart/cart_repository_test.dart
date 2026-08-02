/// The local cart (T076, T085).
///
/// FR-018 (add, change quantity, remove), FR-019 (survives a restart, fully usable offline) and
/// FR-020 (a running subtotal in the active currency).
///
/// Persistence is tested against a real file-backed database rather than an in-memory one,
/// because "survives a restart" is precisely the claim an in-memory database cannot support: a
/// second instance would start empty whether the code persisted anything or not.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:dupermarket/core/currency/currency_service.dart';
import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/features/cart/data/cart_repository.dart';
import 'package:dupermarket/features/cart/domain/cart_models.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:flutter_test/flutter_test.dart';

ProductSummary _product({
  String id = 'p1',
  String title = 'Running Shoe',
  int priceMinor = 4999,
  String currency = 'EUR',
  StockStatus stock = StockStatus.inStock,
}) =>
    ProductSummary(
      id: id,
      title: title,
      price: Money(amountMinor: priceMinor, currency: currency),
      thumbnailUrl: 'https://cdn.test/$id.webp',
      thumbnailAlt: '$title photo',
      ratingAverage: 4.5,
      ratingCount: 10,
      stockStatus: stock,
    );

void main() {
  late CacheDatabase db;
  late CartRepository cart;

  setUp(() {
    db = CacheDatabase(NativeDatabase.memory());
    cart = CartRepository(db, currency: const CurrencyService());
  });
  tearDown(() async => db.close());

  group('add, change, remove (FR-018)', () {
    test('adding a product creates a line', () async {
      await cart.add(_product());

      final CartSnapshot snapshot = await cart.read(displayCurrency: 'EUR');
      expect(snapshot.lines, hasLength(1));
      expect(snapshot.lines.single.title, 'Running Shoe');
    });

    test('adding the same product again increases the quantity', () async {
      await cart.add(_product());
      await cart.add(_product());

      final CartSnapshot snapshot = await cart.read(displayCurrency: 'EUR');
      expect(snapshot.lines, hasLength(1), reason: 'one line per product');
      expect(snapshot.lines.single.quantity, 2);
    });

    test('adding a quantity greater than one is respected', () async {
      await cart.add(_product(), quantity: 3);

      expect((await cart.read(displayCurrency: 'EUR')).lines.single.quantity, 3);
    });

    test('the quantity can be changed directly', () async {
      await cart.add(_product());

      await cart.setQuantity('p1', 7);

      expect((await cart.read(displayCurrency: 'EUR')).lines.single.quantity, 7);
    });

    test('setting the quantity to zero removes the line', () async {
      await cart.add(_product());

      await cart.setQuantity('p1', 0);

      expect((await cart.read(displayCurrency: 'EUR')).lines, isEmpty);
    });

    test('a line can be removed outright', () async {
      await cart.add(_product());
      await cart.add(_product(id: 'p2'));

      await cart.remove('p1');

      final CartSnapshot snapshot = await cart.read(displayCurrency: 'EUR');
      expect(snapshot.lines.map((CartEntry l) => l.productId), <String>['p2']);
    });

    test('clearing empties the whole cart (FR-028)', () async {
      await cart.add(_product());
      await cart.add(_product(id: 'p2'));

      await cart.clear();

      expect((await cart.read(displayCurrency: 'EUR')).isEmpty, isTrue);
    });
  });

  group('persistence across a restart (FR-019)', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dupermarket_cart_test');
      file = File('${dir.path}/cart.sqlite');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('a cart written by one instance is readable by the next', () async {
      final first = CacheDatabase(NativeDatabase(file));
      await CartRepository(first, currency: const CurrencyService())
          .add(_product(), quantity: 2);
      await first.close();

      // A second instance over the same file is what an app restart actually is.
      final second = CacheDatabase(NativeDatabase(file));
      final CartSnapshot snapshot =
          await CartRepository(second, currency: const CurrencyService())
              .read(displayCurrency: 'EUR');
      await second.close();

      expect(snapshot.lines.single.productId, 'p1');
      expect(snapshot.lines.single.quantity, 2);
    });

    test('the price is stored with the line, so an offline restart still totals', () async {
      final first = CacheDatabase(NativeDatabase(file));
      await CartRepository(first, currency: const CurrencyService()).add(_product());
      await first.close();

      final second = CacheDatabase(NativeDatabase(file));
      final CartSnapshot snapshot =
          await CartRepository(second, currency: const CurrencyService())
              .read(displayCurrency: 'EUR');
      await second.close();

      expect(snapshot.subtotal, const Money(amountMinor: 4999, currency: 'EUR'));
    });
  });

  group('the subtotal (FR-020)', () {
    test('an empty cart totals zero rather than failing', () async {
      expect(
        (await cart.read(displayCurrency: 'EUR')).subtotal,
        const Money(amountMinor: 0, currency: 'EUR'),
      );
    });

    test('quantity multiplies into the line total', () async {
      await cart.add(_product(priceMinor: 1999), quantity: 3);

      expect((await cart.read(displayCurrency: 'EUR')).subtotal.amountMinor, 5997);
    });

    test('lines sum exactly, with no floating-point drift', () async {
      // Ten charm-priced lines: the classic case where floats produce 199.89999999999998.
      for (var i = 0; i < 10; i++) {
        await cart.add(_product(id: 'p$i', priceMinor: 1999));
      }

      expect((await cart.read(displayCurrency: 'EUR')).subtotal.amountMinor, 19990);
    });

    test('the subtotal converts into the active currency through the seam', () async {
      await cart.add(_product(priceMinor: 1000));

      final CartSnapshot snapshot = await cart.read(displayCurrency: 'RON');

      expect(snapshot.subtotal.currency, 'RON');
      expect(snapshot.subtotal.amountMinor, 4970);
    });

    test('an unknown currency falls back to the stored one rather than inventing a rate', () async {
      await cart.add(_product(priceMinor: 1000));

      final CartSnapshot snapshot = await cart.read(displayCurrency: 'XYZ');

      expect(snapshot.subtotal.currency, 'EUR', reason: 'FR-052: fall back, never guess');
      expect(snapshot.currencyFallback, isTrue);
    });
  });

  group('unavailable lines (FR-021, FR-078)', () {
    test('a withdrawn line is flagged', () async {
      await cart.add(_product());

      await cart.markWithdrawn('p1');

      expect((await cart.read(displayCurrency: 'EUR')).lines.single.isAvailable, isFalse);
    });

    test('a withdrawn line is excluded from the subtotal', () async {
      await cart.add(_product(priceMinor: 1000));
      await cart.add(_product(id: 'p2', priceMinor: 500));

      await cart.markWithdrawn('p1');

      expect((await cart.read(displayCurrency: 'EUR')).subtotal.amountMinor, 500);
    });

    test('an out-of-stock line is excluded too', () async {
      await cart.add(_product(priceMinor: 1000));
      await cart.add(_product(id: 'p2', priceMinor: 500));

      await cart.updateStock('p1', StockStatus.outOfStock);

      expect((await cart.read(displayCurrency: 'EUR')).subtotal.amountMinor, 500);
    });

    test('a low-stock line is still orderable', () async {
      await cart.add(_product(priceMinor: 1000));

      await cart.updateStock('p1', StockStatus.lowStock);

      expect((await cart.read(displayCurrency: 'EUR')).subtotal.amountMinor, 1000);
    });

    test('an unavailable line stays in the cart rather than vanishing', () async {
      // FR-021: flagged and excluded, not silently deleted — the user chose to put it there.
      await cart.add(_product());

      await cart.markWithdrawn('p1');

      expect((await cart.read(displayCurrency: 'EUR')).lines, hasLength(1));
    });

    test('only the orderable lines are offered for submission', () async {
      await cart.add(_product());
      await cart.add(_product(id: 'p2'));
      await cart.markWithdrawn('p1');

      final CartSnapshot snapshot = await cart.read(displayCurrency: 'EUR');

      expect(snapshot.orderable.map((CartEntry l) => l.productId), <String>['p2']);
      expect(snapshot.unavailable.map((CartEntry l) => l.productId), <String>['p1']);
    });

    test('a cart of only unavailable lines cannot be checked out', () async {
      await cart.add(_product());
      await cart.markWithdrawn('p1');

      expect((await cart.read(displayCurrency: 'EUR')).canCheckOut, isFalse);
    });

    test('a cart with at least one orderable line can be checked out', () async {
      await cart.add(_product());

      expect((await cart.read(displayCurrency: 'EUR')).canCheckOut, isTrue);
    });
  });

  group('watching', () {
    test('a change emits a new snapshot', () async {
      final Stream<CartSnapshot> stream = cart.watch(displayCurrency: 'EUR');
      final Future<List<CartSnapshot>> collected = stream.take(2).toList();

      await cart.add(_product());

      final List<CartSnapshot> snapshots = await collected;
      expect(snapshots.first.isEmpty, isTrue);
      expect(snapshots.last.lines, hasLength(1));
    });
  });
}
