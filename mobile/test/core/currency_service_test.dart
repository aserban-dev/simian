import 'package:dupermarket/core/currency/currency_service.dart';
import 'package:dupermarket/core/currency/money.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyRateProvider implements RateProvider {
  @override
  double? rate({required String base, required String target}) => null;
}

void main() {
  group('Money', () {
    test('FR-050: amounts are exact integers, so charm prices do not drift', () {
      // 0.99 x 3 is 2.97 exactly. In binary floating point it is not.
      const price = Money(amountMinor: 99, currency: 'EUR');
      expect((price * 3).amountMinor, 297);

      var total = const Money.zero('EUR');
      for (var i = 0; i < 100; i++) {
        total = total + price;
      }
      expect(total.amountMinor, 9900, reason: 'no accumulated rounding error');
    });

    test('FR-051: combining different currencies throws rather than silently adding', () {
      const eur = Money(amountMinor: 100, currency: 'EUR');
      const usd = Money(amountMinor: 100, currency: 'USD');
      expect(() => eur + usd, throwsArgumentError);
    });
  });

  group('CurrencyService', () {
    const service = CurrencyService();

    test('FR-050: converts from the base currency at display time', () {
      const base = Money(amountMinor: 1000, currency: 'EUR');
      final result = service.convert(base, 'USD');

      expect(result.usedFallback, isFalse);
      expect(result.money.currency, 'USD');
      expect(result.money.amountMinor, 1090); // 10.00 EUR x 1.09
    });

    test('FR-050: converting to the same currency is an identity, not a round trip', () {
      const base = Money(amountMinor: 1234, currency: 'EUR');
      final result = service.convert(base, 'EUR');
      expect(result.money, base);
      expect(result.usedFallback, isFalse);
    });

    test('FR-052: an unknown currency falls back to base and says so', () {
      const base = Money(amountMinor: 1000, currency: 'EUR');
      final result = service.convert(base, 'JPY');

      expect(result.usedFallback, isTrue, reason: 'the UI must be able to explain the symbol');
      expect(result.money, base, reason: 'never an invented number, never an error');
    });

    test('FR-052: a provider with no rates at all still returns a usable price', () {
      final service = CurrencyService(provider: _EmptyRateProvider());
      const base = Money(amountMinor: 500, currency: 'EUR');

      final result = service.convert(base, 'USD');
      expect(result.money, base);
      expect(result.usedFallback, isTrue);
    });

    test('FR-051: rounds half-up at the minor unit, in one place only', () {
      // 4.55 EUR x 1.09 = 4.9595 -> 496 minor units, not 495.
      const base = Money(amountMinor: 455, currency: 'EUR');
      expect(service.convert(base, 'USD').money.amountMinor, 496);
    });

    test('FR-077: a discounted price and its original convert to the same currency', () {
      const price = Money(amountMinor: 799, currency: 'EUR');
      const original = Money(amountMinor: 1599, currency: 'EUR');

      final pair = service.convertPricePair(price, original, 'GBP');

      expect(pair.price.money.currency, 'GBP');
      expect(pair.original!.money.currency, 'GBP');
      expect(pair.original!.money > pair.price.money, isTrue,
          reason: 'the struck-through original must still read as the higher number');
    });

    test('FR-077: when the price falls back to base, the original falls back with it', () {
      const price = Money(amountMinor: 799, currency: 'EUR');
      const original = Money(amountMinor: 1599, currency: 'EUR');

      final pair = service.convertPricePair(price, original, 'JPY');

      expect(pair.price.usedFallback, isTrue);
      expect(pair.price.money.currency, 'EUR');
      expect(pair.original!.money.currency, 'EUR',
          reason: 'a EUR price beside a JPY original would be incoherent');
    });

    test('FR-077: a product with no discount converts without inventing an original', () {
      const price = Money(amountMinor: 799, currency: 'EUR');
      final pair = service.convertPricePair(price, null, 'USD');

      expect(pair.original, isNull);
      expect(pair.price.money.currency, 'USD');
    });
  });
}
