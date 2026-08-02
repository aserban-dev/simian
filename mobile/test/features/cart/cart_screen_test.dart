/// The cart screen (T077, T079).
///
/// FR-021 and FR-078: an unavailable line is *flagged and kept*, excluded from the total, and
/// does not block checking out the rest. FR-063: an empty cart is a state with copy and a way
/// forward, not a blank page.
library;

import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/features/cart/domain/cart_models.dart';
import 'package:dupermarket/features/cart/presentation/add_to_cart_button.dart';
import 'package:dupermarket/features/cart/presentation/cart_screen.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CartEntry _entry({
  String productId = 'p1',
  String title = 'Running Shoe',
  int quantity = 1,
  int unitMinor = 4999,
  StockStatus stock = StockStatus.inStock,
  bool withdrawn = false,
}) =>
    CartEntry(
      productId: productId,
      title: title,
      quantity: quantity,
      unitPrice: Money(amountMinor: unitMinor, currency: 'EUR'),
      thumbnailUrl: 'https://cdn.test/$productId.webp',
      stockStatus: stock,
      withdrawn: withdrawn,
    );

CartSnapshot _snapshot(List<CartEntry> lines) =>
    CartSnapshot(lines: lines, displayCurrency: 'EUR', currencyFallback: false);

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('the empty cart (T079, FR-063)', () {
    testWidgets('says something rather than showing a blank page', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(CartScreen(snapshot: _snapshot(const <CartEntry>[]))));

      expect(find.text(CartScreen.emptyTitle), findsOneWidget);
      expect(find.text(CartScreen.emptyBody), findsOneWidget);
    });

    testWidgets('offers a way to start browsing', (WidgetTester tester) async {
      var browsed = 0;
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(const <CartEntry>[]),
        onBrowse: () => browsed++,
      )));

      await tester.tap(find.text(CartScreen.browseLabel));
      await tester.pumpAndSettle();

      expect(browsed, 1);
    });

    testWidgets('carries an illustration', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(CartScreen(snapshot: _snapshot(const <CartEntry>[]))));

      expect(find.byIcon(CartScreen.emptyIcon), findsOneWidget);
    });

    testWidgets('offers no checkout when there is nothing to order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CartScreen(snapshot: _snapshot(const <CartEntry>[]))));

      expect(find.text(CartScreen.checkOutLabel), findsNothing);
    });
  });

  group('unavailable lines (T077, FR-021)', () {
    testWidgets('a withdrawn line is flagged on screen', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(<CartEntry>[_entry(withdrawn: true)]),
      )));

      expect(find.text(CartScreen.unavailableLabel), findsOneWidget);
    });

    testWidgets('a withdrawn line stays visible rather than disappearing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(<CartEntry>[_entry(withdrawn: true)]),
      )));

      expect(find.text('Running Shoe'), findsOneWidget);
    });

    testWidgets('an out-of-stock line is flagged the same way (FR-078)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(<CartEntry>[_entry(stock: StockStatus.outOfStock)]),
      )));

      expect(find.text(CartScreen.unavailableLabel), findsOneWidget);
    });

    testWidgets('the total excludes the unavailable line', (WidgetTester tester) async {
      final CartSnapshot snapshot = _snapshot(<CartEntry>[
        _entry(unitMinor: 1000),
        _entry(productId: 'p2', unitMinor: 500, withdrawn: true),
      ]);

      await tester.pumpWidget(_wrap(CartScreen(snapshot: snapshot)));

      expect(snapshot.subtotal.amountMinor, 1000);
    });

    testWidgets('checkout stays available when only some lines are unavailable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(<CartEntry>[
          _entry(),
          _entry(productId: 'p2', withdrawn: true),
        ]),
        onCheckOut: () {},
      )));

      expect(find.text(CartScreen.checkOutLabel), findsOneWidget);
      final Widget button = tester.widget(find.widgetWithText(
        FilledButton,
        CartScreen.checkOutLabel,
      ));
      expect((button as FilledButton).onPressed, isNotNull);
    });

    testWidgets('checkout is unavailable when every line is unavailable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(<CartEntry>[_entry(withdrawn: true)]),
        onCheckOut: () {},
      )));

      final Widget button = tester.widget(find.widgetWithText(
        FilledButton,
        CartScreen.checkOutLabel,
      ));
      expect((button as FilledButton).onPressed, isNull);
    });
  });

  group('quantity controls (FR-018)', () {
    testWidgets('increasing the quantity reports the new value', (WidgetTester tester) async {
      final changes = <int>[];
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(<CartEntry>[_entry(quantity: 2)]),
        onQuantityChanged: (String _, int q) => changes.add(q),
      )));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(changes, <int>[3]);
    });

    testWidgets('decreasing the quantity reports the new value', (WidgetTester tester) async {
      final changes = <int>[];
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(<CartEntry>[_entry(quantity: 2)]),
        onQuantityChanged: (String _, int q) => changes.add(q),
      )));

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      expect(changes, <int>[1]);
    });

    testWidgets('a line can be removed', (WidgetTester tester) async {
      final removed = <String>[];
      await tester.pumpWidget(_wrap(CartScreen(
        snapshot: _snapshot(<CartEntry>[_entry()]),
        onRemove: removed.add,
      )));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(removed, <String>['p1']);
    });

    testWidgets('survives a 200% text scale (FR-067)', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CartScreen(
            snapshot: _snapshot(<CartEntry>[_entry(), _entry(productId: 'p2')]),
            onCheckOut: () {},
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('add to cart (T077, FR-078)', () {
    testWidgets('is enabled for an in-stock product', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: AddToCartButton(stockStatus: StockStatus.inStock, onAdd: () {}),
      )));

      final Widget button = tester.widget(find.byType(FilledButton));
      expect((button as FilledButton).onPressed, isNotNull);
    });

    testWidgets('is enabled for a low-stock product', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: AddToCartButton(stockStatus: StockStatus.lowStock, onAdd: () {}),
      )));

      final Widget button = tester.widget(find.byType(FilledButton));
      expect((button as FilledButton).onPressed, isNotNull);
    });

    testWidgets('is disabled for an out-of-stock product', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: AddToCartButton(stockStatus: StockStatus.outOfStock, onAdd: () {}),
      )));

      final Widget button = tester.widget(find.byType(FilledButton));
      expect((button as FilledButton).onPressed, isNull);
    });

    testWidgets('an out-of-stock product says so instead of just being greyed out', (
      WidgetTester tester,
    ) async {
      // Principle VII: colour alone must not carry the meaning.
      await tester.pumpWidget(_wrap(Scaffold(
        body: AddToCartButton(stockStatus: StockStatus.outOfStock, onAdd: () {}),
      )));

      expect(find.text(AddToCartButton.outOfStockLabel), findsOneWidget);
    });
  });
}
