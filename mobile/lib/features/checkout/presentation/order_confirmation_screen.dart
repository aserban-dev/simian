/// Order placed (T087, FR-030).
///
/// Shows the order number and the estimated delivery window — the two things a user looks for
/// immediately afterwards — and a way onward, because a confirmation with no exit is a dead end
/// like any other (Principle IV).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/currency/money.dart';
import '../data/checkout_service.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    required this.order,
    this.onContinue,
    super.key,
  });

  final PlacedOrder order;
  final VoidCallback? onContinue;

  static const String title = 'Order placed';
  static const String windowLabel = 'Estimated delivery';
  static const String continueLabel = 'Keep shopping';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateFormat format = DateFormat.MMMEd();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Order ${order.orderNumber}',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(windowLabel, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${format.format(order.windowStart)} – ${format.format(order.windowEnd)}',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    formatMoney(order.total),
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    child: const Text(continueLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
