/// The single currency seam.
///
/// FR-050: prices are stored once in a base currency and converted only at display time.
/// FR-051: every conversion goes through this one interface, so replacing fixed rates with a
/// live rate feed is a change to [FixedRateProvider] and nothing else.
/// FR-052: when no rate exists for the active currency, the base-currency price is shown rather
/// than an incorrect converted price or an error.
/// FR-077: a discounted price and its original are converted in the same call, so they can
/// never end up displayed in different currencies.
library;

import 'package:meta/meta.dart';

import 'money.dart';

/// Supplies conversion rates. The rest of the app never sees this type — it exists so the
/// Phase 2 upgrade to live rates touches one implementation.
abstract interface class RateProvider {
  /// Units of [target] per one unit of [base], or null when unknown.
  double? rate({required String base, required String target});
}

/// v1: fixed rates, per spec §8.3 Phase 1.
class FixedRateProvider implements RateProvider {
  const FixedRateProvider({String baseCurrency = 'EUR', Map<String, double>? rates})
      : _base = baseCurrency,
        _rates = rates ?? _defaultRates;

  final String _base;
  final Map<String, double> _rates;

  static const Map<String, double> _defaultRates = {
    'EUR': 1.0,
    'USD': 1.09,
    'GBP': 0.85,
    'RON': 4.97,
    'PLN': 4.31,
    'SEK': 11.45,
  };

  @override
  double? rate({required String base, required String target}) {
    if (base == target) return 1.0;
    if (base != _base) {
      // Cross-rates are not supported in v1 and silently guessing one would be worse than
      // declining. The caller falls back to the base currency (FR-052).
      return null;
    }
    return _rates[target];
  }
}

/// The result of a conversion. [usedFallback] is surfaced so the UI can say why a price is not
/// in the currency the user chose, instead of quietly showing the wrong symbol (FR-052).
@immutable
class ConversionResult {
  const ConversionResult({required this.money, required this.usedFallback});

  final Money money;
  final bool usedFallback;
}

class CurrencyService {
  const CurrencyService({RateProvider provider = const FixedRateProvider()})
      : _provider = provider;

  final RateProvider _provider;

  /// Converts [amount] into [target].
  ///
  /// Rounds half-up to the target's minor unit. Rounding lives here and nowhere else, so two
  /// call sites cannot disagree about a half-cent.
  ConversionResult convert(Money amount, String target) {
    if (amount.currency == target) {
      return ConversionResult(money: amount, usedFallback: false);
    }

    final rate = _provider.rate(base: amount.currency, target: target);
    if (rate == null) {
      // FR-052: no rate → show the base-currency price, flagged, never an error and never a
      // number that looks converted but is not.
      return ConversionResult(money: amount, usedFallback: true);
    }

    return ConversionResult(
      money: Money(
        amountMinor: _roundHalfUp(amount.amountMinor * rate),
        currency: target,
      ),
      usedFallback: false,
    );
  }

  /// Converts a price and its pre-discount original together (FR-077).
  ///
  /// Deliberately one call rather than two: converting them separately is what allows a
  /// discounted price and its struck-through original to end up in different currencies when
  /// one conversion falls back and the other does not.
  ({ConversionResult price, ConversionResult? original}) convertPricePair(
    Money price,
    Money? original,
    String target,
  ) {
    final converted = convert(price, target);
    if (original == null) return (price: converted, original: null);

    // If the price fell back to base, the original must too — otherwise the pair is incoherent.
    final effectiveTarget = converted.usedFallback ? price.currency : target;
    return (price: converted, original: convert(original, effectiveTarget));
  }

  static int _roundHalfUp(double value) {
    // Dart's round() rounds half away from zero, which is half-up for the non-negative amounts
    // this system deals in. Stated explicitly so the behaviour is a decision, not an accident.
    return value.round();
  }
}
