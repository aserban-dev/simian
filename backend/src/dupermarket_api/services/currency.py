"""The single currency seam (backend half).

FR-050: prices are stored once in a base currency and converted only at display time.
FR-051: every conversion goes through this one interface. Replacing fixed rates with a live
feed is a change to `RateProvider` and nothing else — no caller learns about it.
FR-052: with no rate for the requested currency, the base-currency price is returned and
flagged, rather than an invented number or an error.

The client has a mirror of this in `mobile/lib/core/currency/`. The duplication is deliberate:
the client converts cached prices offline, where it cannot call the server. The rules — round
half-up at the minor unit, fall back rather than fail — are asserted on both sides.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal
from typing import Protocol

# Phase 1 of spec §8.3: fixed rates. Phase 2 swaps the provider, not the callers.
_FIXED_RATES: dict[str, Decimal] = {
    "EUR": Decimal("1.0"),
    "USD": Decimal("1.09"),
    "GBP": Decimal("0.85"),
    "RON": Decimal("4.97"),
    "PLN": Decimal("4.31"),
    "SEK": Decimal("11.45"),
}


class RateProvider(Protocol):
    def rate(self, base: str, target: str) -> Decimal | None: ...


class FixedRateProvider:
    def __init__(self, base_currency: str = "EUR", rates: dict[str, Decimal] | None = None):
        self._base = base_currency
        self._rates = rates if rates is not None else _FIXED_RATES

    def rate(self, base: str, target: str) -> Decimal | None:
        if base == target:
            return Decimal("1.0")
        if base != self._base:
            # Cross-rates are not supported in v1. Guessing one silently would be worse than
            # declining; the caller falls back to the base currency (FR-052).
            return None
        return self._rates.get(target)


@dataclass(frozen=True, slots=True)
class Converted:
    amount_minor: int
    currency: str
    used_fallback: bool
    rate: Decimal


class CurrencyService:
    def __init__(self, provider: RateProvider | None = None) -> None:
        self._provider = provider or FixedRateProvider()

    def convert(self, amount_minor: int, base: str, target: str) -> Converted:
        rate = self._provider.rate(base, target)
        if rate is None:
            return Converted(
                amount_minor=amount_minor,
                currency=base,
                used_fallback=True,
                rate=Decimal("1.0"),
            )

        # Rounding lives here and nowhere else, so two call sites cannot disagree about a
        # half-cent. Half-up, matching what a shopper expects a price to do.
        converted = (Decimal(amount_minor) * rate).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
        return Converted(
            amount_minor=int(converted),
            currency=target,
            used_fallback=False,
            rate=rate,
        )

    def convert_pair(
        self, price_minor: int, original_minor: int | None, base: str, target: str
    ) -> tuple[Converted, Converted | None]:
        """FR-077: a discounted price and its original convert together.

        One call rather than two, because converting them separately is what allows the pair to
        end up in different currencies when one falls back and the other does not.
        """
        price = self.convert(price_minor, base, target)
        if original_minor is None:
            return price, None

        effective_target = base if price.used_fallback else target
        return price, self.convert(original_minor, base, effective_target)
