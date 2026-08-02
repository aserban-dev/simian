/// Catalogue domain types.
///
/// Mirrors the response schemas in `contracts/openapi.yaml`. Decoding is hand-written rather
/// than generated so that a missing or malformed field degrades to something renderable instead
/// of throwing into the widget tree (Principle IV) — a product with no image is a placeholder
/// tile, not a broken grid (FR-061).
library;

import 'package:meta/meta.dart';

import '../../../core/currency/money.dart';

enum StockStatus {
  inStock,
  lowStock,
  outOfStock;

  static StockStatus parse(Object? raw) => switch (raw) {
        'in_stock' => StockStatus.inStock,
        'low_stock' => StockStatus.lowStock,
        'out_of_stock' => StockStatus.outOfStock,
        // An unknown status must not hide the product; treat it as buyable and let the
        // server's own checks decide (FR-078).
        _ => StockStatus.inStock,
      };

  /// The contract's spelling. Needed because the cart persists this value locally, and storing
  /// the enum's Dart name would break the moment one is renamed.
  String get wire => switch (this) {
        StockStatus.inStock => 'in_stock',
        StockStatus.lowStock => 'low_stock',
        StockStatus.outOfStock => 'out_of_stock',
      };

  /// FR-078: browsable and labelled, but not addable to the cart.
  bool get isPurchasable => this != StockStatus.outOfStock;
}

enum ProductSort {
  newest('newest', 'Newest'),
  priceAsc('price_asc', 'Price: low to high'),
  priceDesc('price_desc', 'Price: high to low'),
  rating('rating', 'Top rated'),
  relevance('relevance', 'Best match');

  const ProductSort(this.wire, this.label);
  final String wire;
  final String label;
}

@immutable
class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    required this.sortOrder,
    this.imageUrl,
    this.children = const <Category>[],
  });

  final String id;
  final String slug;
  final String name;
  final int sortOrder;
  final String? imageUrl;
  final List<Category> children;

  bool get hasChildren => children.isNotEmpty;

  static Category fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sortOrder: json['sort_order'] as int? ?? 0,
        imageUrl: json['image_url'] as String?,
        children: <Category>[
          for (final Object? child in (json['children'] as List<Object?>?) ?? const <Object?>[])
            if (child is Map<String, dynamic>) Category.fromJson(child),
        ],
      );
}

@immutable
class ProductSummary {
  const ProductSummary({
    required this.id,
    required this.title,
    required this.price,
    required this.thumbnailUrl,
    required this.thumbnailAlt,
    required this.ratingAverage,
    required this.ratingCount,
    required this.stockStatus,
    this.originalPrice,
  });

  final String id;
  final String title;
  final Money price;

  /// FR-077: present only when discounted, and always in the same currency as [price].
  final Money? originalPrice;

  /// Empty when the product has no image. Renders as a placeholder (FR-061).
  final String thumbnailUrl;
  final String thumbnailAlt;
  final double ratingAverage;
  final int ratingCount;
  final StockStatus stockStatus;

  bool get isDiscounted => originalPrice != null;
  bool get hasRating => ratingCount > 0;

  static Money _money(Object? raw, {String fallbackCurrency = 'EUR'}) {
    if (raw is Map<String, dynamic>) {
      return Money(
        amountMinor: raw['amount_minor'] as int? ?? 0,
        currency: raw['currency'] as String? ?? fallbackCurrency,
      );
    }
    return Money(amountMinor: 0, currency: fallbackCurrency);
  }

  static ProductSummary fromJson(Map<String, dynamic> json) {
    final Money price = _money(json['price']);
    final Object? original = json['original_price'];
    return ProductSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      price: price,
      originalPrice:
          original is Map<String, dynamic> ? _money(original, fallbackCurrency: price.currency) : null,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      thumbnailAlt: json['thumbnail_alt'] as String? ?? json['title'] as String? ?? '',
      ratingAverage: (json['rating_average'] as num?)?.toDouble() ?? 0,
      ratingCount: json['rating_count'] as int? ?? 0,
      stockStatus: StockStatus.parse(json['stock_status']),
    );
  }
}

@immutable
class ProductImage {
  const ProductImage({required this.url, required this.altText, this.photographer, this.source});

  final String url;
  final String altText;

  /// FR-075: surfaced on the photo credits screen.
  final String? photographer;
  final String? source;

  static ProductImage fromJson(Map<String, dynamic> json) {
    final Object? attribution = json['attribution'];
    return ProductImage(
      url: json['url'] as String? ?? '',
      altText: json['alt_text'] as String? ?? '',
      photographer:
          attribution is Map<String, dynamic> ? attribution['photographer'] as String? : null,
      source: attribution is Map<String, dynamic> ? attribution['source'] as String? : null,
    );
  }
}

@immutable
class ProductDetail {
  const ProductDetail({
    required this.summary,
    required this.description,
    required this.sku,
    required this.categorySlug,
    required this.images,
  });

  final ProductSummary summary;
  final String description;
  final String sku;
  final String categorySlug;
  final List<ProductImage> images;

  static ProductDetail fromJson(Map<String, dynamic> json) => ProductDetail(
        summary: ProductSummary.fromJson(json),
        description: json['description'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        categorySlug: json['category_slug'] as String? ?? '',
        images: <ProductImage>[
          for (final Object? image in (json['images'] as List<Object?>?) ?? const <Object?>[])
            if (image is Map<String, dynamic>) ProductImage.fromJson(image),
        ],
      );
}

@immutable
class ProductPage {
  const ProductPage({
    required this.items,
    required this.nextCursor,
    required this.currency,
    this.currencyFallback = false,
  });

  final List<ProductSummary> items;

  /// Null on the last page (FR-002).
  final String? nextCursor;
  final String currency;

  /// FR-052: true when the requested currency had no rate, so the UI can say why.
  final bool currencyFallback;

  bool get hasMore => nextCursor != null;

  static ProductPage fromJson(Map<String, dynamic> json) => ProductPage(
        items: <ProductSummary>[
          for (final Object? item in (json['items'] as List<Object?>?) ?? const <Object?>[])
            if (item is Map<String, dynamic>) ProductSummary.fromJson(item),
        ],
        nextCursor: json['next_cursor'] as String?,
        currency: json['currency'] as String? ?? 'EUR',
        currencyFallback: json['currency_fallback'] as bool? ?? false,
      );
}

/// A product review.
///
/// FR-079 makes this a closed set on the server; mirroring it here keeps the client from
/// depending on a field the contract does not promise.
@immutable
class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.authorName,
    this.authorAvatarUrl,
  });

  final String id;
  final int rating;
  final DateTime createdAt;
  final String? comment;
  final String? authorName;
  final String? authorAvatarUrl;

  /// Seeded demo reviews, and reviews whose author deleted their account (FR-017), have none.
  String get displayName => authorName ?? 'Anonymous';

  static Review fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String? ?? '',
        // Clamped rather than trusted: a rating outside 1–5 would break every star widget
        // downstream, and the server's CHECK constraint means it should never happen.
        rating: ((json['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime(1970),
        comment: json['comment'] as String?,
        authorName: json['author_name'] as String?,
        authorAvatarUrl: json['author_avatar_url'] as String?,
      );
}

@immutable
class ReviewPage {
  const ReviewPage({required this.items, required this.nextCursor});

  final List<Review> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  static ReviewPage fromJson(Map<String, dynamic> json) => ReviewPage(
        items: <Review>[
          for (final Object? item in (json['items'] as List<Object?>?) ?? const <Object?>[])
            if (item is Map<String, dynamic>) Review.fromJson(item),
        ],
        nextCursor: json['next_cursor'] as String?,
      );
}
