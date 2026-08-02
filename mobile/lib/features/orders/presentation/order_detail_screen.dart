/// One order in full (T107).
///
/// The stage timeline sits above the map (T101), so the answer to "where is it" is readable
/// without waiting for a map surface to load — and remains readable if the map never loads at
/// all (Principle IV).
library;

import 'package:flutter/material.dart';

import '../../../core/currency/money.dart';
import '../domain/order_models.dart';
import 'delivery_map.dart';
import 'stage_timeline.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    required this.order,
    required this.now,
    this.showMap = true,
    super.key,
  });

  final OrderDetail order;

  /// Injected, so the whole screen — timeline, map and parcel — shares one notion of "now"
  /// and a test can place the delivery anywhere in its window (Principle III).
  final DateTime now;

  /// The map is a platform view and cannot render in a widget test; screens under test pass
  /// false and assert the rest. Production always passes true.
  final bool showMap;

  static const String itemsLabel = 'Items';
  static const String deliverToLabel = 'Delivering to';
  static const String totalLabel = 'Total';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(order.summary.orderNumber)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            StageTimeline(tracking: order.tracking, now: now),
            const SizedBox(height: 16),
            if (showMap)
              SizedBox(
                height: 240,
                child: DeliveryMap(tracking: order.tracking, now: now),
              ),
            const SizedBox(height: 24),

            Text(OrderDetailScreen.deliverToLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (order.recipientName != null) Text(order.recipientName!),
            Text(order.addressFormatted, style: theme.textTheme.bodyMedium),
            const Divider(height: 32),

            Text(OrderDetailScreen.itemsLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final OrderLine line in order.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    Text('${line.quantity} ×'),
                    // The snapshot taken at purchase, not today's catalogue entry (FR-027).
                    Text(line.title),
                    Text(formatMoney(line.lineTotal)),
                  ],
                ),
              ),
            const Divider(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(OrderDetailScreen.totalLabel, style: theme.textTheme.titleLarge),
                Flexible(
                  child: Text(
                    formatMoney(order.summary.total),
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
