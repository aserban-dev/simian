/// The wishlist (T120, T116).
///
/// FR-045, and FR-063 for the empty state. An out-of-stock product stays on the list and is
/// labelled: FR-078 keeps it browsable, and silently dropping something the user saved would be
/// the more surprising behaviour.
library;

import 'package:flutter/material.dart';

import '../../../core/currency/money.dart';
import '../../catalogue/domain/catalogue_models.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({
    required this.products,
    this.onOpenProduct,
    this.onRemove,
    this.onBrowse,
    this.onRefresh,
    super.key,
  });

  final List<ProductSummary> products;
  final void Function(ProductSummary product)? onOpenProduct;
  final void Function(ProductSummary product)? onRemove;
  final VoidCallback? onBrowse;

  /// FR-058: pull-to-refresh forces a fetch whatever the TTL says.
  final Future<void> Function()? onRefresh;

  static const String title = 'Wishlist';
  static const String emptyTitle = 'Nothing saved yet';
  static const String emptyBody =
      'Tap the heart on anything you like and it will be waiting for you here.';
  static const String browseLabel = 'Find something you like';
  static const String unavailableLabel = 'Out of stock';
  static const IconData emptyIcon = Icons.favorite_border;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: SafeArea(
        child: products.isEmpty ? _Empty(onBrowse: onBrowse) : _list(),
      ),
    );
  }

  Widget _list() {
    final Widget list = ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (BuildContext context, int index) => _Row(
        product: products[index],
        onOpen: onOpenProduct,
        onRemove: onRemove,
      ),
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              WishlistScreen.emptyIcon,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              WishlistScreen.emptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              WishlistScreen.emptyBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text(WishlistScreen.browseLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.product, this.onOpen, this.onRemove});

  final ProductSummary product;
  final void Function(ProductSummary product)? onOpen;
  final void Function(ProductSummary product)? onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onOpen == null ? null : () => onOpen!(product),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(product.title, style: theme.textTheme.titleMedium),
                  Text(formatMoney(product.price), style: theme.textTheme.bodyMedium),
                  if (!product.stockStatus.isPurchasable)
                    Text(
                      WishlistScreen.unavailableLabel,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove ${product.title} from your wishlist',
              onPressed: onRemove == null ? null : () => onRemove!(product),
            ),
          ],
        ),
      ),
    );
  }
}
