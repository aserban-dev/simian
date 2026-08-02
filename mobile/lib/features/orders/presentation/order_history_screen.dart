/// Order history (T107).
///
/// Three states, all of them designed rather than defaulted:
///
/// * **Has orders** — the list, newest first.
/// * **Has orders, shown from cache after a failed refresh** — the same list plus an
///   unobtrusive line saying it may be out of date (FR-057, Principle IV: inline and quiet, not
///   a modal over usable content).
/// * **No orders** — an illustration, a line of copy, and a route into the catalogue (FR-063).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/money.dart';
import '../domain/order_models.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({
    required this.orders,
    this.isStale = false,
    this.onOpenOrder,
    this.onBrowse,
    this.onRefresh,
    super.key,
  });

  final List<OrderSummary> orders;

  /// True when the list came from cache and the refresh behind it failed (FR-057).
  final bool isStale;

  final void Function(OrderSummary order)? onOpenOrder;
  final VoidCallback? onBrowse;
  final Future<void> Function()? onRefresh;

  static const String title = 'Your orders';
  static const String emptyTitle = 'No orders yet';
  static const String emptyBody =
      'When you order something, it will appear here with live delivery tracking.';
  static const String browseLabel = 'Start shopping';
  static const IconData emptyIcon = Icons.receipt_long_outlined;

  /// FR-057: says the content may be out of date without implying it is wrong or lost.
  static const String staleNotice = 'Showing your saved orders — this list may be out of date.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: SafeArea(
        child: orders.isEmpty ? _Empty(onBrowse: onBrowse) : _List(
          orders: orders,
          isStale: isStale,
          onOpenOrder: onOpenOrder,
          onRefresh: onRefresh,
        ),
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
              OrderHistoryScreen.emptyIcon,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              OrderHistoryScreen.emptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              OrderHistoryScreen.emptyBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text(OrderHistoryScreen.browseLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.orders,
    required this.isStale,
    this.onOpenOrder,
    this.onRefresh,
  });

  final List<OrderSummary> orders;
  final bool isStale;
  final void Function(OrderSummary order)? onOpenOrder;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final Widget list = ListView.separated(
      padding: const EdgeInsets.all(16),
      // The notice is the first row rather than a banner, so it scrolls with the content it
      // describes instead of covering it.
      itemCount: orders.length + (isStale ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (BuildContext context, int index) {
        if (isStale && index == 0) return const _StaleNotice();
        final OrderSummary order = orders[index - (isStale ? 1 : 0)];
        return _OrderRow(order: order, onTap: onOpenOrder);
      },
    );

    // FR-058: pull-to-refresh forces a fetch whatever the TTL says.
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              OrderHistoryScreen.staleNotice,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, this.onTap});

  final OrderSummary order;
  final void Function(OrderSummary order)? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateFormat format = DateFormat.yMMMd();

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(order),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(order.orderNumber, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            // Wrap, not Row: at a large text scale the date, stage and total stop fitting on
            // one line and must reflow rather than clip (FR-067).
            Wrap(
              spacing: 12,
              children: <Widget>[
                Text(format.format(order.createdAt.toLocal()), style: theme.textTheme.bodySmall),
                Text(order.currentStage.label, style: theme.textTheme.bodySmall),
                Text(formatMoney(order.total), style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
