/// Review, address, card, confirm (T087).
///
/// One screen rather than a wizard: with a saved address and a fixed set of cosmetic cards
/// there are only two decisions to make, and splitting two decisions across four pages would be
/// ceremony rather than clarity.
///
/// What is *not* here is the point (FR-023, Principle I): there is no text field on this screen
/// at all, so there is nowhere to type a card number even by accident.
library;

import 'package:flutter/material.dart';

import '../../../core/currency/money.dart';
import '../../cart/domain/cart_models.dart';
import '../data/checkout_service.dart';
import '../demo_cards.dart';

/// A saved address, reduced to what choosing one needs.
@immutable
class CheckoutAddress {
  const CheckoutAddress({
    required this.id,
    required this.label,
    required this.formatted,
  });

  final String id;
  final String label;
  final String formatted;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.snapshot,
    required this.addresses,
    required this.onConfirm,
    super.key,
  });

  final CartSnapshot snapshot;
  final List<CheckoutAddress> addresses;
  final Future<void> Function(String addressId, DemoCard card) onConfirm;

  static const String totalLabel = 'Total';
  static const String confirmLabel = 'Confirm order';
  static const String addressSectionLabel = 'Deliver to';
  static const String cardSectionLabel = 'Pay with';
  static const String noAddressLabel = 'Add a delivery address to check out.';

  /// FR-029, in the words the requirement asks for: explicit, and clear that nothing happened.
  static const String offlineMessage =
      'You are offline, so this order was not placed. Reconnect and try again — '
      'your cart is safe.';

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _addressId;
  DemoCard _card = DemoCards.visaSuccess;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The overwhelmingly common case is exactly one saved address; making the user tap it would
    // be ceremony. With several, they choose (FR-022).
    if (widget.addresses.length == 1) _addressId = widget.addresses.single.id;
  }

  Future<void> _confirm() async {
    final String? addressId = _addressId;
    if (addressId == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onConfirm(addressId, _card);
    } on CheckoutUnavailableOffline {
      if (mounted) setState(() => _message = CheckoutScreen.offlineMessage);
    } on CheckoutDeclined catch (declined) {
      // FR-025: the server's message, which is written to be shown to a user.
      if (mounted) setState(() => _message = declined.message);
    } on Object {
      if (mounted) {
        setState(() => _message = "We couldn't place that order. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canConfirm = _addressId != null && widget.snapshot.canCheckOut && !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Your order', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final CartEntry line in widget.snapshot.orderable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    Text('${line.quantity} ×'),
                    Text(line.title),
                    Text(formatMoney(line.lineTotal)),
                  ],
                ),
              ),
            const Divider(height: 32),

            Text(CheckoutScreen.addressSectionLabel, style: theme.textTheme.titleMedium),
            if (widget.addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  CheckoutScreen.noAddressLabel,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            RadioGroup<String>(
              groupValue: _addressId,
              onChanged: (String? id) => setState(() => _addressId = id),
              child: Column(
                children: <Widget>[
                  for (final CheckoutAddress address in widget.addresses)
                    RadioListTile<String>(
                      value: address.id,
                      title: Text(address.label),
                      subtitle: Text(address.formatted),
                    ),
                ],
              ),
            ),
            const Divider(height: 32),

            Text(CheckoutScreen.cardSectionLabel, style: theme.textTheme.titleMedium),
            RadioGroup<String>(
              groupValue: _card.id,
              onChanged: (String? id) =>
                  setState(() => _card = DemoCards.byId(id ?? _card.id) ?? _card),
              child: Column(
                children: <Widget>[
                  for (final DemoCard card in DemoCards.all)
                    RadioListTile<String>(value: card.id, title: Text(card.label)),
                ],
              ),
            ),
          ],
        ),
      ),
      // The total and the confirm action stay put rather than scrolling away with the page.
      // On a long checkout — several lines, several addresses — a primary action that has to be
      // scrolled to is one the user has to hunt for at exactly the wrong moment.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(CheckoutScreen.totalLabel, style: theme.textTheme.titleLarge),
                  Flexible(
                    child: Text(
                      formatMoney(widget.snapshot.subtotal),
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              if (_message != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: canConfirm ? _confirm : null,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text(CheckoutScreen.confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
