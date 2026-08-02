/// The cart screen (T085, T079).
///
/// Two states get equal weight here. The populated cart is the obvious one; the **empty** cart
/// is the one apps get wrong, so FR-063 makes it a requirement: an illustration, a line of
/// human copy, and a primary action.
///
/// A flagged line is shown, labelled, and struck from the total (FR-021) — it is not removed,
/// because the user put it there and deleting their choice silently is worse than showing them
/// why it cannot be bought.
library;

import 'package:flutter/material.dart';

import '../../../core/currency/money.dart';
import '../domain/cart_models.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({
    required this.snapshot,
    this.onQuantityChanged,
    this.onRemove,
    this.onCheckOut,
    this.onBrowse,
    super.key,
  });

  final CartSnapshot snapshot;
  final void Function(String productId, int quantity)? onQuantityChanged;
  final void Function(String productId)? onRemove;
  final VoidCallback? onCheckOut;
  final VoidCallback? onBrowse;

  static const String emptyTitle = 'Your cart is empty';
  static const String emptyBody = 'Add something you like and it will show up here.';
  static const String browseLabel = 'Browse the shop';
  static const IconData emptyIcon = Icons.shopping_basket_outlined;
  static const String unavailableLabel = 'No longer available';
  static const String checkOutLabel = 'Check out';
  static const String subtotalLabel = 'Subtotal';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: SafeArea(
        child: snapshot.isEmpty ? _Empty(onBrowse: onBrowse) : _Lines(snapshot: snapshot,
            onQuantityChanged: onQuantityChanged, onRemove: onRemove),
      ),
      bottomNavigationBar: snapshot.isEmpty ? null : _Footer(
        snapshot: snapshot,
        onCheckOut: onCheckOut,
      ),
    );
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
              CartScreen.emptyIcon,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              CartScreen.emptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              CartScreen.emptyBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text(CartScreen.browseLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.snapshot, this.onQuantityChanged, this.onRemove});

  final CartSnapshot snapshot;
  final void Function(String productId, int quantity)? onQuantityChanged;
  final void Function(String productId)? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: snapshot.lines.length,
      separatorBuilder: (_, __) => const Divider(height: 24),
      itemBuilder: (BuildContext context, int index) => _Line(
        entry: snapshot.lines[index],
        onQuantityChanged: onQuantityChanged,
        onRemove: onRemove,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.entry, this.onQuantityChanged, this.onRemove});

  final CartEntry entry;
  final void Function(String productId, int quantity)? onQuantityChanged;
  final void Function(String productId)? onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(entry.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(formatMoney(entry.unitPrice), style: theme.textTheme.bodyMedium),
        if (!entry.isAvailable) ...<Widget>[
          const SizedBox(height: 4),
          // Words, not just a colour — and it names the consequence, not just the state.
          Text(
            CartScreen.unavailableLabel,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        // Wrap rather than Row: at a large text scale the quantity controls and the price no
        // longer fit on one line, and wrapping is what keeps them all reachable (FR-067).
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Decrease quantity',
              onPressed: onQuantityChanged == null
                  ? null
                  : () => onQuantityChanged!(entry.productId, entry.quantity - 1),
            ),
            Text('${entry.quantity}', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Increase quantity',
              onPressed: onQuantityChanged == null
                  ? null
                  : () => onQuantityChanged!(entry.productId, entry.quantity + 1),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove ${entry.title}',
              onPressed: onRemove == null ? null : () => onRemove!(entry.productId),
            ),
          ],
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.snapshot, this.onCheckOut});

  final CartSnapshot snapshot;
  final VoidCallback? onCheckOut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(CartScreen.subtotalLabel, style: Theme.of(context).textTheme.titleMedium),
                Flexible(
                  child: Text(
                    formatMoney(snapshot.subtotal),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              // FR-021: unavailable lines do not block checkout, but a cart of nothing else
              // has nothing to submit.
              onPressed: snapshot.canCheckOut ? onCheckOut : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text(CartScreen.checkOutLabel),
            ),
          ],
        ),
      ),
    );
  }
}
