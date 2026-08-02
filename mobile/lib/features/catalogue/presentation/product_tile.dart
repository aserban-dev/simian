/// A single product in the grid.
///
/// Carries three requirements that are easy to lose in a refactor:
///
/// * **FR-061** — a failed image shows a placeholder *in its own tile*. The `errorBuilder` is
///   what keeps one broken URL from taking the grid with it.
/// * **FR-077** — a discounted price is primary, the original struck through.
/// * **FR-068 / FR-069** — the tile is announced as one semantic node, and the discount is
///   conveyed in text rather than by colour alone.
library;

import 'package:flutter/material.dart';

import '../../../core/currency/money.dart';
import '../domain/catalogue_models.dart';

/// Builds the image widget. Injectable so tests can supply a provider that fails on demand
/// without needing a network or a mocked HTTP client.
typedef ProductImageBuilder = Widget Function(BuildContext context, String url, String altText);

Widget defaultProductImage(BuildContext context, String url, String altText) {
  if (url.isEmpty) return const _ImagePlaceholder();
  return Image.network(
    url,
    fit: BoxFit.cover,
    // FR-061: this tile degrades, its siblings do not.
    errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) =>
        progress == null ? child : const _ImagePlaceholder(shimmer: true),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({this.shimmer = false});
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          shimmer ? Icons.image_outlined : Icons.image_not_supported_outlined,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    required this.product,
    this.onTap,
    this.imageBuilder = defaultProductImage,
    super.key,
  });

  final ProductSummary product;
  final VoidCallback? onTap;
  final ProductImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      // FR-068: one announcement per tile, rather than the screen reader walking six
      // disconnected fragments.
      label: _semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: imageBuilder(context, product.thumbnailUrl, product.thumbnailAlt),
            ),
            const SizedBox(height: 8),
            Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            _PriceRow(product: product),
            if (product.stockStatus == StockStatus.outOfStock)
              // FR-078: labelled, not hidden.
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Out of stock', style: theme.textTheme.labelSmall),
              ),
          ],
        ),
      ),
    );
  }

  String get _semanticLabel {
    final StringBuffer buffer = StringBuffer(product.title)
      ..write(', ')
      ..write(formatMoney(product.price));
    if (product.isDiscounted) {
      buffer.write(', reduced from ${formatMoney(product.originalPrice!)}');
    }
    if (product.hasRating) {
      buffer.write(', rated ${product.ratingAverage.toStringAsFixed(1)} out of 5');
      buffer.write(' from ${product.ratingCount} reviews');
    }
    if (product.stockStatus == StockStatus.outOfStock) {
      buffer.write(', out of stock');
    }
    return buffer.toString();
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});
  final ProductSummary product;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          formatMoney(product.price),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (product.isDiscounted)
          // FR-077: the original, struck through. The strikethrough is decoration, not the
          // only signal — the semantic label says "reduced from" in words (FR-069).
          Text(
            formatMoney(product.originalPrice!),
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
