/// Exact money.
///
/// Research D4: amounts are an integer count of minor units, never a double. Binary floating
/// point cannot represent 0.10, and charm pricing makes `.99` and `.49` endings ubiquitous —
/// exactly the values that accumulate error. An integer subtotal is exact and comparable, which
/// is what the determinism requirement (SC-008) rests on.
library;

import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

@immutable
class Money implements Comparable<Money> {
  const Money({required this.amountMinor, required this.currency})
      : assert(currency.length == 3, 'currency must be an ISO 4217 alpha-3 code');

  const Money.zero(this.currency) : amountMinor = 0;

  final int amountMinor;
  final String currency;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amountMinor: amountMinor + other.amountMinor, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amountMinor: amountMinor - other.amountMinor, currency: currency);
  }

  /// Multiplication by a whole quantity stays exact — this is the cart subtotal path.
  Money operator *(int quantity) =>
      Money(amountMinor: amountMinor * quantity, currency: currency);

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return amountMinor > other.amountMinor;
  }

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return amountMinor < other.amountMinor;
  }

  bool get isZero => amountMinor == 0;

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      // Loud rather than lenient: adding EUR to USD is a bug in the caller, and the currency
      // seam exists precisely so this cannot happen accidentally (FR-051).
      throw ArgumentError(
        'Cannot combine $currency with ${other.currency}. '
        'Convert through CurrencyService first.',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return amountMinor.compareTo(other.amountMinor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.amountMinor == amountMinor && other.currency == currency;

  @override
  int get hashCode => Object.hash(amountMinor, currency);

  @override
  String toString() => 'Money($amountMinor $currency)';
}

/// Formats money for display.
///
/// Uses the device locale's conventions for grouping and decimal separators via `intl`, so a
/// German user sees `1.234,56 €` and a British one `£1,234.56` — FR-047 applies to numbers,
/// not just strings.
String formatMoney(Money money, {String? locale}) {
  final NumberFormat format = NumberFormat.simpleCurrency(
    locale: locale,
    name: money.currency,
  );
  // Minor units to major, done here rather than by the caller so no screen invents its own
  // divisor and gets a currency with a different exponent wrong.
  return format.format(money.amountMinor / _minorUnitDivisor(money.currency));
}

/// Currencies whose minor unit is not 1/100.
const Map<String, int> _exponentOverrides = <String, int>{
  'JPY': 0,
  'KRW': 0,
  'ISK': 0,
  'BHD': 3,
  'KWD': 3,
  'TND': 3,
};

int _minorUnitDivisor(String currency) {
  final int exponent = _exponentOverrides[currency] ?? 2;
  var divisor = 1;
  for (var i = 0; i < exponent; i++) {
    divisor *= 10;
  }
  return divisor;
}
