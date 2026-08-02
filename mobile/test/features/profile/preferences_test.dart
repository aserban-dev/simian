/// Language, currency and notification preferences (T114, T115, T116).
///
/// * **T114 / FR-049** — a currency override changes every displayed price, and survives a
///   relaunch. Persistence is tested against a file-backed database, because "survives a
///   restart" is exactly the claim an in-memory one cannot support.
/// * **T115 / FR-047** — an untranslated string falls back to English rather than showing a key.
/// * **T116 / FR-063** — the empty wishlist and no-addresses states carry copy and an action.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:dupermarket/core/currency/currency_service.dart';
import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:dupermarket/features/profile/data/preferences_repository.dart';
import 'package:dupermarket/features/profile/domain/preferences.dart';
import 'package:dupermarket/features/profile/presentation/address_list_screen.dart';
import 'package:dupermarket/features/profile/presentation/preferences_screen.dart';
import 'package:dupermarket/features/profile/presentation/wishlist_screen.dart';
import 'package:flutter/material.dart';
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
  group('the fallback rule (T115, FR-047)', () {
    const Map<String, String> partiallyTranslated = <String, String>{
      'en': 'Add to cart',
      'ro': 'Adaugă în coș',
    };

    test('an available translation is used', () {
      expect(localise(partiallyTranslated, 'ro'), 'Adaugă în coș');
    });

    test('a missing translation falls back to English, not to a key', () {
      final String resolved = localise(partiallyTranslated, 'pl');

      expect(resolved, 'Add to cart');
      expect(resolved, isNot(contains('.')), reason: 'a key on screen is a visible bug');
    });

    test('a regional locale finds its base language first', () {
      expect(localise(partiallyTranslated, 'ro-RO'), 'Adaugă în coș');
    });

    test('an empty translation is treated as missing', () {
      expect(localise(<String, String>{'en': 'Add to cart', 'ro': ''}, 'ro'), 'Add to cart');
    });

    test('a string with no English either yields empty rather than a key', () {
      // Empty is recoverable in a layout; a raw key is not, and it looks broken.
      expect(localise(<String, String>{'ro': 'Salut'}, 'pl'), '');
    });

    test('the fallback language is English', () {
      expect(fallbackLanguage, 'en');
    });
  });

  group('language and currency resolve independently (FR-049)', () {
    test('the language override wins over the device', () {
      const prefs = UserPreferences(languageOverride: 'ro');

      expect(prefs.activeLanguage('en-GB'), 'ro');
    });

    test('with no override the device language is used (FR-047)', () {
      const prefs = UserPreferences();

      expect(prefs.activeLanguage('ro-RO'), 'ro-RO');
    });

    test('the currency override wins over the device', () {
      const prefs = UserPreferences(currencyOverride: 'RON');

      expect(prefs.activeCurrency('en-GB'), 'RON');
    });

    test('with no override the currency comes from the device locale', () {
      const prefs = UserPreferences();

      expect(prefs.activeCurrency('en-GB'), 'GBP');
      expect(prefs.activeCurrency('ro-RO'), 'RON');
    });

    test('an unknown locale falls back to the base currency rather than guessing', () {
      expect(const UserPreferences().activeCurrency('xx-ZZ'), defaultCurrency);
    });

    test('changing currency does not change language', () {
      // FR-049 says "independently", and this is what that means in practice: English in
      // Bucharest with prices in RON is an ordinary combination.
      const prefs = UserPreferences(currencyOverride: 'RON');

      expect(prefs.activeLanguage('en-GB'), 'en-GB');
      expect(prefs.activeCurrency('en-GB'), 'RON');
    });
  });

  group('a currency override changes displayed prices (T114, FR-049)', () {
    const CurrencyService currency = CurrencyService();

    test('every price converts through the seam', () {
      const prefs = UserPreferences(currencyOverride: 'RON');
      final List<ProductSummary> products = <ProductSummary>[
        _product(priceMinor: 1000),
        _product(id: 'p2', priceMinor: 2000),
      ];

      final List<Money> displayed = <Money>[
        for (final ProductSummary p in products)
          currency.convert(p.price, prefs.activeCurrency('en-GB')).money,
      ];

      expect(displayed.map((Money m) => m.currency).toSet(), <String>{'RON'});
      expect(displayed.map((Money m) => m.amountMinor), <int>[4970, 9940]);
    });

    test('clearing the override returns prices to the device currency', () {
      const prefs = UserPreferences(currencyOverride: 'RON');
      final UserPreferences cleared = prefs.copyWith(clearCurrency: true);

      expect(cleared.activeCurrency('en-GB'), 'GBP');
    });
  });

  group('an override survives a relaunch (T114)', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dupermarket_prefs_test');
      file = File('${dir.path}/prefs.sqlite');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('the currency override is readable by the next instance', () async {
      final first = CacheDatabase(NativeDatabase(file));
      await PreferencesRepository(cache: first).setCurrencyOverride('RON');
      await first.close();

      // A second instance over the same file is what an app restart actually is.
      final second = CacheDatabase(NativeDatabase(file));
      final UserPreferences prefs = await PreferencesRepository(cache: second).read();
      await second.close();

      expect(prefs.currencyOverride, 'RON');
    });

    test('the language override is readable by the next instance', () async {
      final first = CacheDatabase(NativeDatabase(file));
      await PreferencesRepository(cache: first).setLanguageOverride('ro');
      await first.close();

      final second = CacheDatabase(NativeDatabase(file));
      final UserPreferences prefs = await PreferencesRepository(cache: second).read();
      await second.close();

      expect(prefs.languageOverride, 'ro');
    });
  });

  group('storing preferences locally', () {
    late CacheDatabase db;
    late PreferencesRepository repository;

    setUp(() {
      db = CacheDatabase(NativeDatabase.memory());
      repository = PreferencesRepository(cache: db);
    });
    tearDown(() async => db.close());

    test('setting then clearing returns to following the device', () async {
      await repository.setCurrencyOverride('RON');
      await repository.setCurrencyOverride(null);

      expect((await repository.read()).currencyOverride, isNull);
    });

    test('the two overrides are stored independently', () async {
      await repository.setLanguageOverride('ro');
      await repository.setCurrencyOverride('SEK');

      final UserPreferences prefs = await repository.read();
      expect(prefs.languageOverride, 'ro');
      expect(prefs.currencyOverride, 'SEK');
    });

    test('clearing one leaves the other alone', () async {
      await repository.setLanguageOverride('ro');
      await repository.setCurrencyOverride('SEK');

      await repository.setCurrencyOverride(null);

      final UserPreferences prefs = await repository.read();
      expect(prefs.languageOverride, 'ro');
      expect(prefs.currencyOverride, isNull);
    });

    test('notification preferences round-trip (FR-046)', () async {
      await repository.setNotificationPreference('promotions', enabled: false);

      final UserPreferences prefs = await repository.read();
      expect(prefs.isNotificationEnabled('promotions'), isFalse);
      expect(prefs.isNotificationEnabled('delivery'), isTrue, reason: 'unset means default-on');
    });

    test('the profile is authoritative after sign-in (FR-048)', () async {
      await repository.adoptFromProfile(<String, dynamic>{
        'language_override': 'pl',
        'currency_override': 'PLN',
        'notification_prefs': <String, dynamic>{'promotions': false},
      });

      final UserPreferences prefs = await repository.read();
      expect(prefs.languageOverride, 'pl');
      expect(prefs.currencyOverride, 'PLN');
      expect(prefs.isNotificationEnabled('promotions'), isFalse);
    });

    test('preferences are purged by the sign-out purge (FR-016)', () async {
      // The next person to sign in on a shared device must not inherit them.
      await repository.setCurrencyOverride('RON');

      await db.clearUserScopedData();

      expect((await repository.read()).currencyOverride, isNull);
    });
  });

  group('the preferences screen', () {
    // The screen offers six languages, six currencies and two notification switches, which does
    // not fit the default 800x600 test window. A tall viewport renders the whole list, so these
    // tests assert on content rather than on scroll mechanics.
    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

    Future<void> pump(WidgetTester tester, {UserPreferences? prefs}) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PreferencesScreen(
            preferences: prefs ?? const UserPreferences(),
            deviceLocale: 'en-GB',
          ),
        ),
      );
    }

    testWidgets('offers language and currency separately', (WidgetTester tester) async {
      await pump(tester);

      expect(find.text(PreferencesScreen.languageLabel), findsOneWidget);
      expect(find.text(PreferencesScreen.currencyLabel), findsOneWidget);
    });

    testWidgets('offers a way back to the device default', (WidgetTester tester) async {
      await pump(tester);

      expect(find.textContaining(PreferencesScreen.followDeviceLabel), findsNWidgets(2));
    });

    testWidgets('choosing a currency reports it', (WidgetTester tester) async {
      final chosen = <String?>[];
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: PreferencesScreen(
          preferences: const UserPreferences(),
          deviceLocale: 'en-GB',
          onCurrencyChanged: chosen.add,
        ),
      ));

      await tester.tap(find.text('RON'));
      await tester.pumpAndSettle();

      expect(chosen, <String?>['RON']);
    });

    testWidgets('shows notification switches (FR-046)', (WidgetTester tester) async {
      await pump(tester);

      expect(find.byType(SwitchListTile), findsNWidgets(2));
    });
  });

  group('empty states (T116, FR-063)', () {
    testWidgets('the empty wishlist has copy and an action', (WidgetTester tester) async {
      var browsed = 0;
      await tester.pumpWidget(MaterialApp(
        home: WishlistScreen(products: const <ProductSummary>[], onBrowse: () => browsed++),
      ));

      expect(find.text(WishlistScreen.emptyTitle), findsOneWidget);
      expect(find.text(WishlistScreen.emptyBody), findsOneWidget);
      expect(find.byIcon(WishlistScreen.emptyIcon), findsOneWidget);

      await tester.tap(find.text(WishlistScreen.browseLabel));
      await tester.pumpAndSettle();
      expect(browsed, 1);
    });

    testWidgets('the no-addresses state has copy and an action', (WidgetTester tester) async {
      var added = 0;
      await tester.pumpWidget(MaterialApp(
        home: AddressListScreen(addresses: const <SavedAddress>[], onAdd: () => added++),
      ));

      expect(find.text(AddressListScreen.emptyTitle), findsOneWidget);
      expect(find.text(AddressListScreen.emptyBody), findsOneWidget);
      expect(find.byIcon(AddressListScreen.emptyIcon), findsOneWidget);

      await tester.tap(find.text(AddressListScreen.addLabel));
      await tester.pumpAndSettle();
      expect(added, 1);
    });

    testWidgets('a populated wishlist shows its products instead', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: WishlistScreen(products: <ProductSummary>[_product()]),
      ));

      expect(find.text('Running Shoe'), findsOneWidget);
      expect(find.text(WishlistScreen.emptyTitle), findsNothing);
    });

    testWidgets('an out-of-stock wishlist item is labelled, not hidden (FR-078)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: WishlistScreen(
          products: <ProductSummary>[_product(stock: StockStatus.outOfStock)],
        ),
      ));

      expect(find.text('Running Shoe'), findsOneWidget);
      expect(find.text(WishlistScreen.unavailableLabel), findsOneWidget);
    });

    testWidgets('the default address is marked in words (FR-041)', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: AddressListScreen(
          addresses: <SavedAddress>[
            SavedAddress(id: 'a1', formatted: '1 Test Street', isDefault: true, label: 'Home'),
            SavedAddress(id: 'a2', formatted: '2 Office Road', isDefault: false, label: 'Work'),
          ],
        ),
      ));

      expect(find.text(AddressListScreen.defaultLabel), findsOneWidget);
    });
  });
}
