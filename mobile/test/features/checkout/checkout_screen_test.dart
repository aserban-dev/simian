/// The checkout screens (T078, T087).
///
/// FR-022 (an address is required before confirming), FR-023 (only built-in cards, and no field
/// that accepts card details), FR-029 (offline is refused explicitly) and FR-030 (the
/// confirmation shows an order number and a delivery window).
library;

import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/features/cart/domain/cart_models.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:dupermarket/features/checkout/data/checkout_service.dart';
import 'package:dupermarket/features/checkout/demo_cards.dart';
import 'package:dupermarket/features/checkout/presentation/checkout_screen.dart';
import 'package:dupermarket/features/checkout/presentation/order_confirmation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two saved addresses: neither is preselected, so the user must choose (FR-022).
const List<CheckoutAddress> _twoAddresses = <CheckoutAddress>[
  CheckoutAddress(id: 'a1', label: 'Home', formatted: '1 Test Street, Bucharest'),
  CheckoutAddress(id: 'a2', label: 'Work', formatted: '2 Office Road, Bucharest'),
];

/// The default for tests about *confirming*: one address is preselected, so the confirm button
/// is live and the test is about the thing it says it is about.
const List<CheckoutAddress> _oneAddress = <CheckoutAddress>[
  CheckoutAddress(id: 'a1', label: 'Home', formatted: '1 Test Street, Bucharest'),
];

CartSnapshot _snapshot() => const CartSnapshot(
      lines: <CartEntry>[
        CartEntry(
          productId: 'p1',
          title: 'Running Shoe',
          quantity: 2,
          unitPrice: Money(amountMinor: 4999, currency: 'EUR'),
          thumbnailUrl: 'https://cdn.test/p1.webp',
          stockStatus: StockStatus.inStock,
          withdrawn: false,
        ),
      ],
      displayCurrency: 'EUR',
      currencyFallback: false,
    );

Widget _screen({
  List<CheckoutAddress> addresses = _oneAddress,
  Future<void> Function(String addressId, DemoCard card)? onConfirm,
}) =>
    MaterialApp(
      home: CheckoutScreen(
        snapshot: _snapshot(),
        addresses: addresses,
        onConfirm: onConfirm ?? (String _, DemoCard __) async {},
      ),
    );

void main() {
  group('review (FR-022, T087)', () {
    testWidgets('shows what is being ordered', (WidgetTester tester) async {
      await tester.pumpWidget(_screen());

      expect(find.text('Running Shoe'), findsOneWidget);
    });

    testWidgets('shows the order total', (WidgetTester tester) async {
      await tester.pumpWidget(_screen());

      expect(find.text(CheckoutScreen.totalLabel), findsOneWidget);
    });

    testWidgets('lists the saved addresses to choose from', (WidgetTester tester) async {
      await tester.pumpWidget(_screen(addresses: _twoAddresses));

      expect(find.text('1 Test Street, Bucharest'), findsOneWidget);
      expect(find.text('2 Office Road, Bucharest'), findsOneWidget);
    });

    testWidgets('offers every demo card', (WidgetTester tester) async {
      await tester.pumpWidget(_screen());

      for (final DemoCard card in DemoCards.all) {
        expect(find.text(card.label), findsOneWidget);
      }
    });

    testWidgets('has no field that accepts card details (FR-023, Principle I)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_screen());

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });
  });

  group('an address is required before confirming (FR-022)', () {
    testWidgets('confirm is disabled until an address is chosen', (WidgetTester tester) async {
      await tester.pumpWidget(_screen(addresses: const <CheckoutAddress>[]));

      final Widget button =
          tester.widget(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      expect((button as FilledButton).onPressed, isNull);
    });

    testWidgets('the only address is preselected, so the common case is one tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_screen(addresses: _oneAddress));

      final Widget button =
          tester.widget(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      expect((button as FilledButton).onPressed, isNotNull);
    });

    testWidgets('with no address at all, the screen says what to do (Principle IV)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_screen(addresses: const <CheckoutAddress>[]));

      expect(find.text(CheckoutScreen.noAddressLabel), findsOneWidget);
    });

    testWidgets('the chosen address is the one submitted', (WidgetTester tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(_screen(
        addresses: _twoAddresses,
        onConfirm: (String addressId, DemoCard _) async => chosen.add(addressId),
      ));

      await tester.tap(find.text('2 Office Road, Bucharest'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      await tester.pumpAndSettle();

      expect(chosen, <String>['a2']);
    });

    testWidgets('the chosen card is the one submitted', (WidgetTester tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(_screen(
        onConfirm: (String _, DemoCard card) async => chosen.add(card.id),
      ));

      await tester.tap(find.text(DemoCards.decline.label));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      await tester.pumpAndSettle();

      expect(chosen, <String>['decline']);
    });
  });

  group('offline is refused explicitly (T078, FR-029)', () {
    testWidgets('the connection message is shown, not a generic failure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_screen(
        onConfirm: (String _, DemoCard __) async => throw const CheckoutUnavailableOffline(),
      ));

      await tester.tap(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      await tester.pumpAndSettle();

      expect(find.text(CheckoutScreen.offlineMessage), findsOneWidget);
    });

    testWidgets('the message says the order was not placed', (WidgetTester tester) async {
      // FR-029: "tell the user explicitly" — an ambiguous message is what makes people retry
      // and end up with two orders.
      await tester.pumpWidget(_screen(
        onConfirm: (String _, DemoCard __) async => throw const CheckoutUnavailableOffline(),
      ));

      await tester.tap(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      await tester.pumpAndSettle();

      expect(CheckoutScreen.offlineMessage.toLowerCase(), contains('not'));
    });

    testWidgets('confirm stays available so the user can retry when back online', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_screen(
        onConfirm: (String _, DemoCard __) async => throw const CheckoutUnavailableOffline(),
      ));

      await tester.tap(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      await tester.pumpAndSettle();

      final Widget button =
          tester.widget(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      expect((button as FilledButton).onPressed, isNotNull);
    });

    testWidgets('a decline shows its own message and offers another card (FR-025)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_screen(
        onConfirm: (String _, DemoCard __) async =>
            throw const CheckoutDeclined('That card was declined.'),
      ));

      await tester.tap(find.widgetWithText(FilledButton, CheckoutScreen.confirmLabel));
      await tester.pumpAndSettle();

      expect(find.text('That card was declined.'), findsOneWidget);
      expect(find.text(DemoCards.visaSuccess.label), findsOneWidget);
    });
  });

  group('confirmation (FR-030)', () {
    testWidgets('shows the order number', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OrderConfirmationScreen(
          order: PlacedOrder(
            id: 'o1',
            orderNumber: 'DM-ABC123',
            total: const Money(amountMinor: 9998, currency: 'EUR'),
            windowStart: DateTime.utc(2026, 8, 3, 12),
            windowEnd: DateTime.utc(2026, 8, 5, 12),
          ),
        ),
      ));

      expect(find.textContaining('DM-ABC123'), findsOneWidget);
    });

    testWidgets('shows an estimated delivery window', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OrderConfirmationScreen(
          order: PlacedOrder(
            id: 'o1',
            orderNumber: 'DM-ABC123',
            total: const Money(amountMinor: 9998, currency: 'EUR'),
            windowStart: DateTime.utc(2026, 8, 3, 12),
            windowEnd: DateTime.utc(2026, 8, 5, 12),
          ),
        ),
      ));

      expect(find.text(OrderConfirmationScreen.windowLabel), findsOneWidget);
    });

    testWidgets('offers a way onward rather than ending the journey', (
      WidgetTester tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(MaterialApp(
        home: OrderConfirmationScreen(
          order: PlacedOrder(
            id: 'o1',
            orderNumber: 'DM-ABC123',
            total: const Money(amountMinor: 9998, currency: 'EUR'),
            windowStart: DateTime.utc(2026, 8, 3, 12),
            windowEnd: DateTime.utc(2026, 8, 5, 12),
          ),
          onContinue: () => done++,
        ),
      ));

      await tester.tap(find.text(OrderConfirmationScreen.continueLabel));
      await tester.pumpAndSettle();

      expect(done, 1);
    });
  });
}
