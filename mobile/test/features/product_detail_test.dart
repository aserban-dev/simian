import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dupermarket/core/cache/cache_database.dart';
import 'package:dupermarket/core/errors/failure_view.dart';
import 'package:dupermarket/core/network/api_client.dart';
import 'package:dupermarket/features/catalogue/data/catalogue_repository.dart';
import 'package:dupermarket/features/catalogue/presentation/product_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RouteAdapter implements HttpClientAdapter {
  _RouteAdapter(this.routes);

  /// Path substring -> responder, matched in insertion order.
  ///
  /// Substring matching is not specific: `/products/p1/reviews` also contains `/products/p1`,
  /// so the reviews route must be listed first, and a route omitted to make a call fail will
  /// instead be swallowed by a broader one. Always route both explicitly.
  final Map<String, ResponseBody Function(RequestOptions)> routes;
  final List<RequestOptions> seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    for (final MapEntry<String, ResponseBody Function(RequestOptions)> route in routes.entries) {
      if (options.path.contains(route.key)) return route.value(options);
    }
    throw DioException(requestOptions: options, type: DioExceptionType.badResponse);
  }

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

Widget okImage(BuildContext context, String url, String alt) =>
    ColoredBox(color: const Color(0xFF00FF00), child: Text(url, textDirection: TextDirection.ltr));

Map<String, Object?> _productBody({
  int imageCount = 3,
  double rating = 4.5,
  int ratingCount = 12,
  String stock = 'in_stock',
  String? photographer,
}) =>
    <String, Object?>{
      'id': 'p1',
      'title': 'Running Shoe',
      'price': <String, Object?>{'amount_minor': 4999, 'currency': 'EUR'},
      'original_price': <String, Object?>{'amount_minor': 7999, 'currency': 'EUR'},
      'thumbnail_url': 'https://cdn/0.webp',
      'thumbnail_alt': 'Running Shoe',
      'rating_average': rating,
      'rating_count': ratingCount,
      'stock_status': stock,
      'description': 'Light and fast, for long runs.',
      'sku': 'SKU-1',
      'category_slug': 'shoes',
      'images': <Object?>[
        for (int i = 0; i < imageCount; i++)
          <String, Object?>{
            'url': 'https://cdn/$i.webp',
            'sort_order': i,
            'alt_text': 'Running Shoe, view ${i + 1}',
            'attribution': photographer == null
                ? null
                : <String, Object?>{'source': 'pexels', 'photographer': photographer},
          },
      ],
    };

Map<String, Object?> _reviewsBody(List<String> ids, {String? nextCursor}) => <String, Object?>{
      'items': <Object?>[
        for (final String id in ids)
          <String, Object?>{
            'id': id,
            'rating': 5,
            'comment': 'Comment $id',
            'author_name': 'Reviewer $id',
            'created_at': '2026-08-01T10:00:00Z',
          },
      ],
      'next_cursor': nextCursor,
    };

void main() {
  late CacheDatabase cache;
  setUp(() => cache = CacheDatabase(NativeDatabase.memory()));
  tearDown(() async => cache.close());

  CatalogueRepository repo(_RouteAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'))..httpClientAdapter = adapter;
    return CatalogueRepository(
      api: ApiClient(dio: dio, tokenProvider: () async => null, hasConnectivity: () => true),
      cache: cache,
      now: () => DateTime.utc(2026, 8, 2, 12),
    );
  }

  Future<void> pumpDetail(WidgetTester tester, _RouteAdapter adapter) async {
    // A phone-sized surface. The default 800x600 makes the 1:1 carousel 800px tall, which
    // pushes the whole body below the fold — and a ListView never builds what is off-screen,
    // so every content assertion would fail for a layout reason rather than a real one.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: ProductDetailScreen(
        repository: repo(adapter),
        productId: 'p1',
        imageBuilder: okImage,
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('FR-006: the detail screen shows everything the requirement lists', () {
    testWidgets('title, price, description, rating average and count all render',
        (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>['r1'])),
          '/products/p1': (_) => _json(_productBody()),
        }),
      );

      expect(find.text('Running Shoe'), findsWidgets);
      expect(find.textContaining('49'), findsWidgets); // 49.99
      expect(find.text('Light and fast, for long runs.'), findsOneWidget);
      expect(find.textContaining('4.5 (12)'), findsOneWidget);
    });

    testWidgets('FR-077: the pre-discount price is struck through',
        (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>[])),
          '/products/p1': (_) => _json(_productBody()),
        }),
      );

      final Text original = tester.widget<Text>(find.textContaining('79'));
      expect(original.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('FR-078: an out-of-stock product is labelled', (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>[])),
          '/products/p1': (_) => _json(_productBody(stock: 'out_of_stock')),
        }),
      );
      expect(find.text('Out of stock'), findsOneWidget);
    });
  });

  group('image carousel', () {
    testWidgets('US1 scenario 6: every image is reachable by swiping',
        (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>[])),
          '/products/p1': (_) => _json(_productBody(imageCount: 3)),
        }),
      );

      expect(find.text('https://cdn/0.webp'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('https://cdn/1.webp'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('https://cdn/2.webp'), findsOneWidget);
    });

    testWidgets('FR-068: each image announces its position in the set',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>[])),
          '/products/p1': (_) => _json(_productBody(imageCount: 3)),
        }),
      );

      expect(find.bySemanticsLabel(RegExp('Image 1 of 3')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('FR-061: a product with no images shows a placeholder, not an error',
        (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>[])),
          '/products/p1': (_) => _json(_productBody(imageCount: 0)),
        }),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.text('Running Shoe'), findsWidgets, reason: 'the product still renders');
    });

    testWidgets('FR-075: a photographer credit is shown when the source requires it',
        (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>[])),
          '/products/p1': (_) => _json(_productBody(photographer: 'Ada Lovelace')),
        }),
      );

      expect(find.textContaining('Photo by Ada Lovelace'), findsOneWidget);
    });
  });

  group('FR-007: reviews are paginated', () {
    testWidgets('the first page renders', (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>['r1', 'r2'])),
          '/products/p1': (_) => _json(_productBody()),
        }),
      );

      expect(find.text('Comment r1'), findsOneWidget);
      expect(find.text('Comment r2'), findsOneWidget);
    });

    testWidgets('a next page is fetched with the cursor and appended', (WidgetTester tester) async {
      var call = 0;
      final adapter = _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
        '/reviews': (_) {
          call++;
          return call == 1
              ? _json(_reviewsBody(<String>['r1'], nextCursor: 'cursor-1'))
              : _json(_reviewsBody(<String>['r2']));
        },
        '/products/p1': (_) => _json(_productBody()),
      });

      await pumpDetail(tester, adapter);
      expect(find.text('Comment r1'), findsOneWidget);

      await tester.tap(find.text('Show more reviews'));
      await tester.pumpAndSettle();

      expect(find.text('Comment r2'), findsOneWidget);
      expect(find.text('Comment r1'), findsOneWidget, reason: 'pages append, not replace');

      final RequestOptions second =
          adapter.seen.lastWhere((RequestOptions o) => o.path.contains('/reviews'));
      expect(second.queryParameters['cursor'], 'cursor-1');
    });

    testWidgets('no more pages means no load-more control', (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>['r1'])),
          '/products/p1': (_) => _json(_productBody()),
        }),
      );
      expect(find.text('Show more reviews'), findsNothing);
    });

    testWidgets('a product with no reviews says so instead of leaving a gap',
        (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          '/reviews': (_) => _json(_reviewsBody(<String>[])),
          '/products/p1': (_) => _json(_productBody(rating: 0, ratingCount: 0)),
        }),
      );

      expect(find.textContaining('No reviews yet'), findsOneWidget);
      // The zero-reviews edge case: no average exists, so printing 0.0 would make a new
      // product look terrible rather than new.
      expect(find.text('No ratings yet'), findsOneWidget);
      expect(find.textContaining('0.0'), findsNothing);
    });
  });

  group('FR-060: failures are scoped', () {
    testWidgets('a failed review fetch leaves the product on screen',
        (WidgetTester tester) async {
      await pumpDetail(
        tester,
        _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{
          // Explicitly failed, not merely unrouted: an omitted route would be caught by the
          // broader '/products/p1' entry and quietly succeed.
          '/reviews': (RequestOptions o) => throw DioException(
                requestOptions: o,
                type: DioExceptionType.connectionError,
              ),
          '/products/p1': (_) => _json(_productBody()),
        }),
      );

      expect(find.text('Running Shoe'), findsWidgets, reason: 'the product must survive');

      // The reviews section sits below the fold on a phone. Drag the ListView specifically:
      // the carousel's PageView is also a Scrollable, so scrollUntilVisible's default finder
      // matches two and throws.
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't load more reviews"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a failed product fetch shows a retry for the whole screen',
        (WidgetTester tester) async {
      await pumpDetail(tester, _RouteAdapter(<String, ResponseBody Function(RequestOptions)>{}));

      expect(find.byType(FailureView), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
