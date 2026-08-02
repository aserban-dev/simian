import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:dupermarket/core/currency/money.dart';
import 'package:dupermarket/core/errors/failure_view.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:dupermarket/features/catalogue/data/catalogue_repository.dart';
import 'package:dupermarket/features/catalogue/domain/catalogue_models.dart';
import 'package:dupermarket/features/catalogue/presentation/home_screen.dart';
import 'package:dupermarket/features/catalogue/presentation/product_list_screen.dart';
import 'package:dupermarket/features/catalogue/presentation/product_tile.dart';
import 'package:dupermarket/features/catalogue/presentation/skeletons.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

/// An image builder that always fails, so FR-061 can be tested without a network.
Widget failingImage(BuildContext context, String url, String alt) =>
    const ColoredBox(color: Color(0xFFEEEEEE), child: Icon(Icons.image_not_supported_outlined));

/// An image builder that always succeeds.
Widget okImage(BuildContext context, String url, String alt) =>
    const ColoredBox(color: Color(0xFF00FF00));

ProductSummary _product(String id, {bool discounted = false, StockStatus? stock}) =>
    ProductSummary(
      id: id,
      title: 'Product $id',
      price: const Money(amountMinor: 1999, currency: 'EUR'),
      originalPrice: discounted ? const Money(amountMinor: 3999, currency: 'EUR') : null,
      thumbnailUrl: 'https://cdn/$id.webp',
      thumbnailAlt: 'Product $id photo',
      ratingAverage: 4.5,
      ratingCount: 12,
      stockStatus: stock ?? StockStatus.inStock,
    );

/// For screens, which supply their own Scaffold.
Widget _wrap(Widget child) => MaterialApp(home: child);

/// For bare widgets.
///
/// Two things the real app supplies that a raw `pumpWidget` does not: a Material ancestor for
/// InkWell, and a grid-cell-sized box. Given the whole 800x600 screen a tile's 1:1 image would
/// demand 800x800 and overflow — an artefact of the harness, not of the tile.
Widget _wrapTile(Widget child, {bool asGridCell = true}) => MaterialApp(
      home: Scaffold(
        body: asGridCell
            ? Center(child: SizedBox(width: 180, height: 320, child: child))
            : child,
      ),
    );

void main() {
  late CacheDatabase cache;

  setUp(() => cache = CacheDatabase(NativeDatabase.memory()));
  tearDown(() async => cache.close());

  CatalogueRepository repo(_StubAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'))
      ..httpClientAdapter = adapter;
    return CatalogueRepository(
      api: ApiClient(
        dio: dio,
        tokenProvider: () async => null,
        hasConnectivity: () => true,
      ),
      cache: cache,
      now: () => DateTime.utc(2026, 8, 2, 12),
    );
  }

  group('ProductTile', () {
    testWidgets('FR-061: a failed image degrades this tile and no other',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapTile(
        asGridCell: false,
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          children: <Widget>[
            ProductTile(product: _product('broken'), imageBuilder: failingImage),
            ProductTile(product: _product('fine'), imageBuilder: okImage),
          ],
        ),
      ));

      // The broken tile shows its placeholder...
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      // ...and both tiles still render their content.
      expect(find.text('Product broken'), findsOneWidget);
      expect(find.text('Product fine'), findsOneWidget);
    });

    testWidgets('FR-061: a product with no image URL renders a placeholder, not an error',
        (WidgetTester tester) async {
      const ProductSummary noImage = ProductSummary(
        id: 'x',
        title: 'No image',
        price: Money(amountMinor: 500, currency: 'EUR'),
        thumbnailUrl: '',
        thumbnailAlt: 'No image',
        ratingAverage: 0,
        ratingCount: 0,
        stockStatus: StockStatus.inStock,
      );

      await tester.pumpWidget(_wrapTile(const ProductTile(product: noImage)));
      expect(tester.takeException(), isNull);
      expect(find.text('No image'), findsOneWidget);
    });

    testWidgets('FR-077: a discount shows the reduced price with the original struck through',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapTile(
        ProductTile(product: _product('a', discounted: true), imageBuilder: okImage),
      ));

      final Text original = tester.widget<Text>(find.textContaining('39'));
      expect(original.style?.decoration, TextDecoration.lineThrough);
      expect(find.textContaining('19'), findsOneWidget);
    });

    testWidgets('FR-069: the discount is stated in words, not carried by styling alone',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrapTile(
        ProductTile(product: _product('a', discounted: true), imageBuilder: okImage),
      ));

      expect(find.bySemanticsLabel(RegExp('reduced from')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('FR-068: the tile is announced as one node, not six fragments',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrapTile(
        ProductTile(product: _product('a'), imageBuilder: okImage),
      ));

      expect(find.bySemanticsLabel(RegExp(r'Product a.*rated 4\.5 out of 5')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('FR-078: an out-of-stock product is labelled, not hidden',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapTile(
        ProductTile(
          product: _product('a', stock: StockStatus.outOfStock),
          imageBuilder: okImage,
        ),
      ));

      expect(find.text('Product a'), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    testWidgets('FR-064: a cold start shows skeletons, not a bare spinner',
        (WidgetTester tester) async {
      final adapter = _StubAdapter((_) => _json(<String, Object?>{'items': <Object?>[]}));
      await tester.pumpWidget(_wrap(HomeScreen(repository: repo(adapter))));

      // Before the future settles.
      expect(find.byType(CategoryGridSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('FR-001: categories render as a grid', (WidgetTester tester) async {
      final adapter = _StubAdapter(
        (_) => _json(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': '1',
              'slug': 'shoes',
              'name': 'Shoes',
              'sort_order': 0,
              'children': <Object?>[],
            },
          ],
        }),
      );

      await tester.pumpWidget(_wrap(HomeScreen(repository: repo(adapter))));
      await tester.pumpAndSettle();

      expect(find.text('Shoes'), findsOneWidget);
    });

    testWidgets('FR-063: no categories shows an empty state with an action',
        (WidgetTester tester) async {
      final adapter = _StubAdapter((_) => _json(<String, Object?>{'items': <Object?>[]}));

      await tester.pumpWidget(_wrap(HomeScreen(repository: repo(adapter))));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('FR-060: a cold-start failure shows a retry, not a blank screen',
        (WidgetTester tester) async {
      final adapter = _StubAdapter((RequestOptions o) {
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      });

      await tester.pumpWidget(_wrap(HomeScreen(repository: repo(adapter))));
      await tester.pumpAndSettle();

      expect(find.byType(FailureView), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('ProductListScreen', () {
    testWidgets('FR-063: no results offers a way out', (WidgetTester tester) async {
      final adapter = _StubAdapter(
        (_) => _json(<String, Object?>{
          'items': <Object?>[],
          'next_cursor': null,
          'currency': 'EUR',
        }),
      );

      await tester.pumpWidget(_wrap(
        ProductListScreen(repository: repo(adapter), searchQuery: 'nothing matches this'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nothing matched that search'), findsOneWidget);
      expect(find.byType(EmptyStateView), findsOneWidget);
    });

    testWidgets('FR-002: products render and the grid is column-based',
        (WidgetTester tester) async {
      final adapter = _StubAdapter(
        (_) => _json(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'a',
              'title': 'Sneaker',
              'price': <String, Object?>{'amount_minor': 1999, 'currency': 'EUR'},
              'thumbnail_url': '',
              'thumbnail_alt': 'Sneaker',
              'rating_average': 4.0,
              'rating_count': 3,
              'stock_status': 'in_stock',
            },
          ],
          'next_cursor': null,
          'currency': 'EUR',
        }),
      );

      await tester.pumpWidget(_wrap(
        ProductListScreen(
          repository: repo(adapter),
          categorySlug: 'shoes',
          categoryName: 'Shoes',
          imageBuilder: okImage,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sneaker'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('FR-052: a currency fallback is explained rather than silently shown',
        (WidgetTester tester) async {
      final adapter = _StubAdapter(
        (_) => _json(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'a',
              'title': 'Sneaker',
              'price': <String, Object?>{'amount_minor': 1999, 'currency': 'EUR'},
              'thumbnail_url': '',
              'thumbnail_alt': 'Sneaker',
              'rating_average': 0,
              'rating_count': 0,
              'stock_status': 'in_stock',
            },
          ],
          'next_cursor': null,
          'currency': 'EUR',
          'currency_fallback': true,
        }),
      );

      await tester.pumpWidget(_wrap(
        ProductListScreen(repository: repo(adapter), categorySlug: 'shoes', imageBuilder: okImage),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('base currency'), findsOneWidget);
    });

    testWidgets('FR-060: a failure with no products shows a retry', (WidgetTester tester) async {
      final adapter = _StubAdapter((RequestOptions o) {
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      });

      await tester.pumpWidget(_wrap(
        ProductListScreen(repository: repo(adapter), categorySlug: 'shoes'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(FailureView), findsOneWidget);
    });
  });
}
