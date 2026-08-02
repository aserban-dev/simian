/// The built-in demo cards (T086) — the only place cards exist in this app.
///
/// Constitution Principle I and FR-023. These are **labels**, not payment instruments. There is
/// no number, no expiry, no security code, and no field anywhere in the app that accepts one.
/// What travels to the server is [DemoCard.id], a value from a closed enum in the contract.
///
/// If a future change adds a real card here, it is a constitutional amendment rather than a
/// feature — and `test/features/checkout/checkout_service_test.dart` fails first, because it
/// asserts no label contains so much as a digit.
library;

import 'package:meta/meta.dart';

@immutable
class DemoCard {
  const DemoCard({
    required this.id,
    required this.label,
    required this.declines,
  });

  /// Matches the contract's `DemoCardId` enum exactly. The only value transmitted.
  final String id;

  /// What the user sees. Deliberately free of digits, so nothing here can be mistaken for — or
  /// quietly grow into — a card number.
  final String label;

  /// FR-024: one card deterministically declines, so the recovery path can be demonstrated
  /// and tested rather than described.
  final bool declines;
}

abstract final class DemoCards {
  static const DemoCard visaSuccess = DemoCard(
    id: 'visa_success',
    label: 'Visa demo card — always approves',
    declines: false,
  );

  static const DemoCard mastercardSuccess = DemoCard(
    id: 'mastercard_success',
    label: 'Mastercard demo card — always approves',
    declines: false,
  );

  /// Two approving cards exist so that recovering from a decline is a real choice rather than
  /// re-tapping the same card and hoping (FR-025).
  static const DemoCard decline = DemoCard(
    id: 'decline',
    label: 'Test card — always declines',
    declines: true,
  );

  static const List<DemoCard> all = <DemoCard>[visaSuccess, mastercardSuccess, decline];

  static DemoCard? byId(String id) {
    for (final DemoCard card in all) {
      if (card.id == id) return card;
    }
    return null;
  }
}
