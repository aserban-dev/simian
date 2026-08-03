"""Price synthesis (T147).

FR-073 and Principle III: a given product id always yields the same price, on every run, on
every machine. That is what makes a re-seed a no-op (FR-072) and what lets a test assert an
exact number instead of a range.

The mechanism is an RNG **seeded on the product id** — not `random`, not the clock, not a
counter. Three rules on top of it, all from spec §17.5:

* per-category bands, so a mascara does not cost what a laptop does;
* a low-end bias, because a catalogue of uniformly distributed prices looks generated;
* charm endings (`.99`, `.95`, `.49`), which is what makes integer minor units mandatory —
  these are exactly the values binary floats cannot hold (research D4).
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class PriceBand:
    """Inclusive bounds, in minor units of the base currency."""

    min_minor: int
    max_minor: int


# Per-category bands. A band that is missing falls back to `DEFAULT_BAND` rather than raising:
# a new category should produce a plausible catalogue, not a failed seed run.
CATEGORY_BANDS: dict[str, PriceBand] = {
    "beauty": PriceBand(4_99, 79_99),
    "accessories": PriceBand(9_99, 249_99),
    "home": PriceBand(14_99, 899_99),
    "electronics": PriceBand(49_99, 2_499_99),
    "sport": PriceBand(9_99, 399_99),
    "mens-clothing": PriceBand(14_99, 199_99),
    "womens-clothing": PriceBand(14_99, 249_99),
    "mens-shoes": PriceBand(29_99, 349_99),
    "womens-shoes": PriceBand(29_99, 399_99),
}

DEFAULT_BAND = PriceBand(9_99, 199_99)

# Charm endings, in minor units. Applied after the band is chosen, so a price is always one of
# these three shapes — which is what §17.5 asks for and what makes a generated catalogue read as
# a real one.
CHARM_ENDINGS: tuple[int, ...] = (99, 95, 49)

# How hard to bias towards the low end. 2 squares the uniform draw, which roughly doubles the
# density of cheap items — enough to look like a real shop, not so much that the band's top is
# never reached.
_LOW_END_EXPONENT = 2


def _unit_interval(product_id: str, salt: str) -> float:
    """A deterministic value in [0, 1) derived from the product id.

    Hashing rather than `random.Random(seed)`: a hash is stable across Python versions, and
    `random`'s stream is explicitly not guaranteed to be. A seed pipeline that produced
    different prices after an interpreter upgrade would break FR-073 in the least visible way
    possible.
    """
    digest = hashlib.sha256(f"{product_id}:{salt}".encode()).digest()
    # 52 bits is the mantissa of a float64, so this divides exactly.
    value = int.from_bytes(digest[:7], "big")
    return value / float(1 << 56)


def band_for(category_slug: str) -> PriceBand:
    return CATEGORY_BANDS.get(category_slug, DEFAULT_BAND)


def synthesise_price_minor(product_id: str, category_slug: str) -> int:
    """The price for a product that arrived without one (FR-073).

    Deterministic, banded, biased low, and charm-ended. The result is always a whole number of
    minor units — no float ever reaches a stored price.
    """
    band = band_for(category_slug)
    span = band.max_minor - band.min_minor
    if span <= 0:
        return _apply_charm_ending(band.min_minor)

    # Low-end bias: squaring a uniform draw concentrates it near zero.
    position = _unit_interval(product_id, "price") ** _LOW_END_EXPONENT
    raw = band.min_minor + int(position * span)
    return _apply_charm_ending(raw, band, product_id=product_id)


def _apply_charm_ending(amount_minor: int, band: PriceBand, product_id: str | None = None) -> int:
    """Replace the minor part with a charm ending, keeping the result inside `band`.

    Truncating to the whole major unit and appending an ending moves the price by up to 99 minor
    units in either direction, which is enough to leave the band at an edge — a 29.99 minimum
    becomes 29.49, one unit *below* its own floor. So the result is nudged by a whole major unit
    when it falls outside, and clamped as a backstop.

    That matters because the bands are what the price-filter tests and the catalogue's own
    filters are written against: a price outside its band is invisible until a filter silently
    stops returning something.
    """
    ending = (
        CHARM_ENDINGS[int(_unit_interval(product_id, "charm") * len(CHARM_ENDINGS))]
        if product_id is not None
        else CHARM_ENDINGS[0]
    )

    whole = amount_minor // 100
    if whole == 0:
        # Below one major unit there is no room for an ending; keep the amount honest.
        return max(min(amount_minor, band.max_minor), band.min_minor)

    candidate = whole * 100 + ending
    if candidate < band.min_minor:
        candidate += 100
    elif candidate > band.max_minor:
        candidate -= 100

    return max(min(candidate, band.max_minor), band.min_minor)


def synthesise_discount_percentage(product_id: str) -> float | None:
    """An occasional discount, deterministically (FR-077 gives it somewhere to show).

    Roughly one product in five, at 10–40%. Returns None rather than 0 so that "not discounted"
    and "discounted by nothing" stay distinguishable — the client renders a struck-through
    original only for the former.
    """
    roll = _unit_interval(product_id, "discount")
    if roll >= 0.2:
        return None
    # Map the surviving fifth onto 10–40, in whole percent.
    return float(10 + int(_unit_interval(product_id, "discount-size") * 31))
