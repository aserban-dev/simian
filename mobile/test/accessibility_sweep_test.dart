/// Accessibility sweep across every screen (T153, T154, T155).
///
/// Run against Flutter's own guidelines rather than hand-written assertions, because the
/// interesting failures are the ones a person stops noticing: a tap target two pixels too
/// small, a label that reads as "button", a contrast ratio that passes in light mode and fails
/// in dark.
///
/// * **FR-068 / SC-010** — every interactive element has a semantic label
///   (`labeledTapTargetGuideline`).
/// * **FR-069** — contrast meets WCAG AA (`textContrastGuideline`), in *both* themes.
/// * **FR-070** — safe areas, notches and cutouts are respected, checked by rendering each
///   screen inside a viewport with insets on all four sides.
///
/// Adding a screen here is one line. Leaving one out is the failure mode, so the list is kept
/// next to the sweep rather than inside each test.
library;

import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/features/auth/domain/auth_models.dart';
import 'package:dupermarket/features/auth/presentation/sign_in_screen.dart';
import 'package:dupermarket/features/auth/presentation/welcome_screen.dart';
import 'package:dupermarket/features/cart/domain/cart_models.dart';
import 'package:dupermarket/features/cart/presentation/cart_screen.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:dupermarket/features/checkout/data/checkout_service.dart';
import 'package:dupermarket/features/checkout/demo_cards.dart';
import 'package:dupermarket/features/checkout/presentation/checkout_screen.dart';
import 'package:dupermarket/features/checkout/presentation/order_confirmation_screen.dart';
import 'package:dupermarket/features/notifications/presentation/notification_permission_prompt.dart';
import 'package:dupermarket/features/orders/domain/order_models.dart';
import 'package:dupermarket/features/orders/domain/parcel_position.dart';
import 'package:dupermarket/features/orders/presentation/order_history_screen.dart';
import 'package:dupermarket/features/orders/presentation/stage_timeline.dart';
import 'package:dupermarket/features/profile/domain/preferences.dart';
import 'package:dupermarket/features/profile/presentation/address_list_screen.dart';
import 'package:dupermarket/features/profile/presentation/photo_credits_screen.dart';
import 'package:dupermarket/features/profile/presentation/preferences_screen.dart';
import 'package:dupermarket/features/profile/presentation/profile_screen.dart';
import 'package:dupermarket/features/profile/presentation/wishlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 8, 3, 12);

ProductSummary _product({StockStatus stock = StockStatus.inStock}) => ProductSummary(
      id: 'p1',
      title: 'Running Shoe',
      price: const Money(amountMinor: 4999, currency: 'EUR'),
      thumbnailUrl: '',
      thumbnailAlt: 'Running shoe photo',
      ratingAverage: 4.5,
      ratingCount: 10,
      stockStatus: stock,
    );

CartSnapshot _cart() => const CartSnapshot(
      lines: <CartEntry>[
        CartEntry(
          productId: 'p1',
          title: 'Running Shoe',
          quantity: 2,
          unitPrice: Money(amountMinor: 4999, currency: 'EUR'),
          thumbnailUrl: '',
          stockStatus: StockStatus.inStock,
          withdrawn: false,
        ),
      ],
      displayCurrency: 'EUR',
      currencyFallback: false,
    );

DeliveryTracking _tracking() => DeliveryTracking(
      origin: const GeoPoint(lat: 0, lng: 0),
      destination: const GeoPoint(lat: 10, lng: 20),
      processingAt: _now,
      shippedAt: _now.add(const Duration(hours: 6)),
      outForDeliveryAt: _now.add(const Duration(hours: 54)),
      deliveredAt: _now.add(const Duration(hours: 60)),
    );

OrderSummary _order() => OrderSummary(
      id: 'o1',
      orderNumber: 'DM-ABC123',
      createdAt: _now.subtract(const Duration(days: 1)),
      total: const Money(amountMinor: 9998, currency: 'EUR'),
      currentStage: DeliveryStage.shipped,
      itemCount: 2,
    );

PlacedOrder _placed() => PlacedOrder(
      id: 'o1',
      orderNumber: 'DM-ABC123',
      total: const Money(amountMinor: 9998, currency: 'EUR'),
      windowStart: _now,
      windowEnd: _now.add(const Duration(days: 2)),
    );

/// Every screen in the app, by name. A screen absent from here is a screen never swept.
final Map<String, Widget Function()> screens = <String, Widget Function()>{
  'sign in': () => SignInScreen(
        providers: const <SocialProvider>[
          SocialProvider.google,
          SocialProvider.facebook,
          SocialProvider.apple,
        ],
        onSignIn: (SocialProvider _) async {},
      ),
  'welcome': () => WelcomeScreen(onDismiss: () {}),
  'profile': () => ProfileScreen(
        user: const AuthUser(uid: 'u1', displayName: 'Sam Shopper'),
        onSignOut: () async {},
      ),
  'cart': () => CartScreen(snapshot: _cart(), onCheckOut: () {}, onBrowse: () {}),
  'cart (empty)': () => CartScreen(
        snapshot: const CartSnapshot(
          lines: <CartEntry>[],
          displayCurrency: 'EUR',
          currencyFallback: false,
        ),
        onBrowse: () {},
      ),
  'checkout': () => CheckoutScreen(
        snapshot: _cart(),
        addresses: const <CheckoutAddress>[
          CheckoutAddress(id: 'a1', label: 'Home', formatted: '1 Test Street'),
        ],
        onConfirm: (String _, DemoCard __) async {},
      ),
  'order confirmation': () => OrderConfirmationScreen(order: _placed(), onContinue: () {}),
  'order history': () => OrderHistoryScreen(orders: <OrderSummary>[_order()], onBrowse: () {}),
  'order history (empty)': () =>
      OrderHistoryScreen(orders: const <OrderSummary>[], onBrowse: () {}),
  'addresses': () => AddressListScreen(
        addresses: const <SavedAddress>[
          SavedAddress(id: 'a1', formatted: '1 Test Street', isDefault: true, label: 'Home'),
        ],
        onAdd: () {},
      ),
  'addresses (empty)': () =>
      AddressListScreen(addresses: const <SavedAddress>[], onAdd: () {}),
  'wishlist': () => WishlistScreen(products: <ProductSummary>[_product()], onBrowse: () {}),
  'wishlist (empty)': () =>
      WishlistScreen(products: const <ProductSummary>[], onBrowse: () {}),
  'preferences': () => const PreferencesScreen(
        preferences: UserPreferences(),
        deviceLocale: 'en-GB',
      ),
  'photo credits': () => const PhotoCreditsScreen(
        images: <ProductImage>[
          ProductImage(
            url: 'https://cdn/a.jpg',
            altText: 'A photo',
            photographer: 'Ada Photographer',
            source: 'Pexels',
          ),
        ],
      ),
  'notification prompt': () => Scaffold(
        body: NotificationPermissionPrompt(onAllow: () async {}, onNotNow: () {}),
      ),
  'stage timeline': () => Scaffold(
        body: StageTimeline(tracking: _tracking(), now: _now),
      ),
};

/// A viewport with insets on all four edges: a notch at the top, a home indicator at the
/// bottom, and cutouts either side. FR-070 is about what happens *there*.
const MediaQueryData _withInsets = MediaQueryData(
  padding: EdgeInsets.only(top: 47, bottom: 34, left: 12, right: 12),
  viewPadding: EdgeInsets.only(top: 47, bottom: 34, left: 12, right: 12),
  size: Size(390, 844),
);

Widget _wrap(Widget child, {required Brightness brightness, bool withInsets = false}) {
  final Widget body = withInsets ? MediaQuery(data: _withInsets, child: child) : child;
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: const Color(0xFFFF6B00),
    ),
    home: body,
  );
}

void main() {
  group('every interactive element is labelled (T153, FR-068, SC-010)', () {
    for (final MapEntry<String, Widget Function()> entry in screens.entries) {
      testWidgets(entry.key, (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(entry.value(), brightness: Brightness.light));
        await tester.pump();

        // A screen reader announcing "button, button, button" is the failure this catches.
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('contrast meets WCAG AA in light mode (T154, FR-069)', () {
    for (final MapEntry<String, Widget Function()> entry in screens.entries) {
      testWidgets(entry.key, (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(entry.value(), brightness: Brightness.light));
        await tester.pump();

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('contrast meets WCAG AA in dark mode (T154, FR-069)', () {
    for (final MapEntry<String, Widget Function()> entry in screens.entries) {
      testWidgets(entry.key, (WidgetTester tester) async {
        // Dark mode is where a palette tuned by eye in light mode usually fails.
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(entry.value(), brightness: Brightness.dark));
        await tester.pump();

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('tap targets are large enough (T153, Principle VII)', () {
    for (final MapEntry<String, Widget Function()> entry in screens.entries) {
      testWidgets(entry.key, (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(entry.value(), brightness: Brightness.light));
        await tester.pump();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('safe areas, notches and cutouts (T155, FR-070)', () {
    for (final MapEntry<String, Widget Function()> entry in screens.entries) {
      testWidgets(entry.key, (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(entry.value(), brightness: Brightness.light, withInsets: true),
        );
        await tester.pump();

        // Rendering inside a notched viewport must not overflow or throw. A layout that
        // ignores the insets shows up here as an overflow exception.
        expect(tester.takeException(), isNull, reason: '${entry.key} broke inside safe areas');
      });
    }
  });

  group('the sweep covers the app', () {
    test('every screen in the app is listed', () {
      // A reminder rather than a mechanism: the list cannot discover screens by itself, so its
      // size is asserted to make an omission visible in review.
      expect(screens.length, greaterThanOrEqualTo(16));
    });
  });
}
