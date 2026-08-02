/// Product detail: image carousel, price, description, rating summary, paginated reviews.
///
/// Covers US1 acceptance scenario 6 — "swipe through every image and see title, price,
/// description, average rating, rating count, and a paginated review list" — plus FR-006 and
/// FR-007.
///
/// The reviews list pages independently of the product itself: a review fetch that fails must
/// not take the product off the screen (FR-060).
library;

import 'package:flutter/material.dart';

import '../../../core/currency/money.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_view.dart';
import '../../../core/network/api_client.dart';
import '../data/catalogue_repository.dart';
import '../domain/catalogue_models.dart';
import 'product_tile.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.repository,
    required this.productId,
    this.imageBuilder = defaultProductImage,
    super.key,
  });

  final CatalogueRepository repository;
  final String productId;
  final ProductImageBuilder imageBuilder;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductDetail? _product;
  AppFailure? _productFailure;
  bool _loadingProduct = true;

  final List<Review> _reviews = <Review>[];
  String? _reviewCursor;
  bool _hasMoreReviews = true;
  bool _loadingReviews = false;
  AppFailure? _reviewFailure;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loadingProduct = true;
      _productFailure = null;
    });
    try {
      final ProductDetail product = await widget.repository.fetchProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loadingProduct = false;
      });
      await _loadMoreReviews();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _productFailure = e.failure;
        _loadingProduct = false;
      });
    }
  }

  Future<void> _loadMoreReviews() async {
    if (_loadingReviews || !_hasMoreReviews) return;
    setState(() {
      _loadingReviews = true;
      _reviewFailure = null;
    });
    try {
      final ReviewPage page = await widget.repository.fetchReviews(
        widget.productId,
        cursor: _reviewCursor,
      );
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page.items);
        _reviewCursor = page.nextCursor;
        _hasMoreReviews = page.hasMore;
        _loadingReviews = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Scoped to the reviews section: the product stays on screen (FR-060).
      setState(() {
        _reviewFailure = e.failure;
        _loadingReviews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_product?.summary.title ?? 'Product')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loadingProduct) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_productFailure != null) {
      return ListView(children: <Widget>[
        const SizedBox(height: 80),
        FailureView(failure: _productFailure!, onRetry: _loadProduct),
      ]);
    }

    final ProductDetail product = _product!;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        ImageCarousel(images: product.images, imageBuilder: widget.imageBuilder),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(product.summary.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              _PriceLine(summary: product.summary),
              if (product.summary.stockStatus == StockStatus.outOfStock) ...<Widget>[
                const SizedBox(height: 8),
                // FR-078: labelled clearly; the add-to-cart control (US3) reads the same flag.
                Text('Out of stock', style: Theme.of(context).textTheme.labelLarge),
              ],
              const SizedBox(height: 16),
              RatingSummary(
                average: product.summary.ratingAverage,
                count: product.summary.ratingCount,
              ),
              const SizedBox(height: 16),
              Text(product.description, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
              Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
            ],
          ),
        ),
        ..._reviewSection(),
      ],
    );
  }

  List<Widget> _reviewSection() {
    if (_reviews.isEmpty && _loadingReviews) {
      return <Widget>[const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())];
    }

    if (_reviews.isEmpty && _reviewFailure == null) {
      // FR-063: an empty state, not a blank gap. No action here — writing a review is US2+.
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'No reviews yet. Be the first once you have bought it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    }

    return <Widget>[
      for (final Review review in _reviews)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ReviewCard(review: review),
        ),
      if (_reviewFailure != null)
        Padding(
          padding: const EdgeInsets.all(16),
          // Wrap, not Row: at a narrow width — and far more so at 200% text scale (FR-067) —
          // the label and the button do not fit on one line, and a Row would overflow rather
          // than reflow.
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: <Widget>[
              const Text("Couldn't load more reviews"),
              TextButton(onPressed: _loadMoreReviews, child: const Text('Retry')),
            ],
          ),
        )
      else if (_hasMoreReviews)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: _loadingReviews
                ? const CircularProgressIndicator()
                : OutlinedButton(
                    onPressed: _loadMoreReviews,
                    child: const Text('Show more reviews'),
                  ),
          ),
        ),
    ];
  }
}

/// Swipeable image carousel (US1 scenario 6).
///
/// Each page handles its own load failure, so one broken image does not blank the carousel —
/// the same rule as the grid (FR-061).
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({
    required this.images,
    this.imageBuilder = defaultProductImage,
    super.key,
  });

  final List<ProductImage> images;
  final ProductImageBuilder imageBuilder;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      // A product with no images is still a product (FR-061).
      return AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.image_not_supported_outlined, size: 48)),
        ),
      );
    }

    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (int i) => setState(() => _index = i),
            itemBuilder: (BuildContext context, int i) {
              final ProductImage image = widget.images[i];
              return Semantics(
                image: true,
                // FR-068: the alt text the seed pipeline generated, plus position, so a
                // screen-reader user knows how many there are.
                label: '${image.altText}. Image ${i + 1} of ${widget.images.length}',
                excludeSemantics: true,
                child: widget.imageBuilder(context, image.url, image.altText),
              );
            },
          ),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < widget.images.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _Dot(active: i == _index),
                  ),
              ],
            ),
          ),
        if (_currentAttribution != null)
          // FR-075: credit where the source's licence asks for it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _currentAttribution!,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }

  String? get _currentAttribution {
    if (_index >= widget.images.length) return null;
    final ProductImage image = widget.images[_index];
    if (image.photographer == null) return null;
    return 'Photo by ${image.photographer}${image.source == null ? '' : ' on ${image.source}'}';
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? colors.primary : colors.outlineVariant,
      ),
    );
  }
}

/// Average rating and count (FR-006).
class RatingSummary extends StatelessWidget {
  const RatingSummary({required this.average, required this.count, super.key});

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (count == 0) {
      // The "product has zero reviews" edge case: no average exists, so do not print 0.0 —
      // an unrated product would look terrible rather than new.
      return Text('No ratings yet', style: theme.textTheme.bodyMedium);
    }

    return Semantics(
      label: 'Rated ${average.toStringAsFixed(1)} out of 5 from $count reviews',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (int i = 1; i <= 5; i++)
            Icon(
              average >= i
                  ? Icons.star
                  : (average >= i - 0.5 ? Icons.star_half : Icons.star_border),
              size: 18,
              color: theme.colorScheme.primary,
            ),
          const SizedBox(width: 8),
          // FR-069: the number is present in text, so the stars are not the only signal.
          Text('${average.toStringAsFixed(1)} ($count)', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({required this.review, super.key});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: '${review.displayName} rated ${review.rating} out of 5'
          '${review.comment == null ? '' : '. ${review.comment}'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(review.displayName, style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              for (int i = 1; i <= 5; i++)
                Icon(
                  i <= review.rating ? Icons.star : Icons.star_border,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
          if (review.comment != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(review.comment!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.summary});
  final ProductSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(formatMoney(summary.price), style: theme.textTheme.titleLarge),
        if (summary.isDiscounted)
          Text(
            formatMoney(summary.originalPrice!),
            style: theme.textTheme.bodyMedium?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
