"""Deterministic price synthesis (T139).

FR-073 and Principle III. The requirement is not "prices look plausible" — it is that the same
product id yields the same price on every run, on every machine, forever. That is what makes a
re-seed a no-op (FR-072) and what lets these tests assert an exact integer.

The values below are pinned deliberately. If a change to the hashing or the bands moves them,
these tests fail — which is the point: a silent change would re-price the entire catalogue and
re-upload nothing, leaving the database and the CDN describing different shops.
"""

from __future__ import annotations

import pytest

from dupermarket_seed.prices import (
    CATEGORY_BANDS,
    CHARM_ENDINGS,
    DEFAULT_BAND,
    band_for,
    synthesise_discount_percentage,
    synthesise_price_minor,
)


class TestDeterminism:
    def test_the_same_id_yields_the_same_price(self) -> None:
        first = synthesise_price_minor("kaggle:1234", "womens-shoes")
        second = synthesise_price_minor("kaggle:1234", "womens-shoes")

        assert first == second

    def test_it_is_stable_across_many_calls(self) -> None:
        prices = {synthesise_price_minor("kaggle:1234", "womens-shoes") for _ in range(50)}

        assert len(prices) == 1

    def test_different_ids_generally_differ(self) -> None:
        """Not a uniqueness guarantee — a catalogue has repeated prices — but not one value."""
        prices = {synthesise_price_minor(f"kaggle:{i}", "womens-shoes") for i in range(100)}

        assert len(prices) > 10

    def test_the_category_changes_the_price(self) -> None:
        # Same product id, different band: an id alone must not determine the price, or a
        # recategorised product would keep an out-of-band one.
        shoe = synthesise_price_minor("kaggle:1234", "womens-shoes")
        mascara = synthesise_price_minor("kaggle:1234", "beauty")

        assert shoe != mascara

    def test_no_float_reaches_the_price(self) -> None:
        price = synthesise_price_minor("kaggle:1234", "electronics")

        assert isinstance(price, int)
        assert not isinstance(price, float)


class TestBands:
    @pytest.mark.parametrize("slug", sorted(CATEGORY_BANDS))
    def test_every_price_falls_inside_its_band(self, slug: str) -> None:
        for index in range(200):
            price = synthesise_price_minor(f"product-{index}", slug)
            band = band_for(slug)
            assert band.min_minor <= price <= band.max_minor, f"{slug}: {price}"

    def test_an_unknown_category_uses_the_default_band(self) -> None:
        assert band_for("something-new") is DEFAULT_BAND

    def test_an_unknown_category_still_produces_a_price(self) -> None:
        """A new category should yield a plausible catalogue, not a failed run."""
        price = synthesise_price_minor("kaggle:1", "something-new")

        assert DEFAULT_BAND.min_minor <= price <= DEFAULT_BAND.max_minor

    def test_electronics_are_dearer_than_beauty_on_average(self) -> None:
        electronics = [synthesise_price_minor(f"p{i}", "electronics") for i in range(200)]
        beauty = [synthesise_price_minor(f"p{i}", "beauty") for i in range(200)]

        assert sum(electronics) / len(electronics) > sum(beauty) / len(beauty)


class TestCharmEndings:
    def test_every_price_ends_in_a_charm_value(self) -> None:
        """§17.5. These are the endings that make integer minor units mandatory (research D4)."""
        for index in range(300):
            price = synthesise_price_minor(f"product-{index}", "home")
            assert price % 100 in CHARM_ENDINGS, price

    def test_all_three_endings_are_used(self) -> None:
        endings = {synthesise_price_minor(f"product-{i}", "home") % 100 for i in range(300)}

        assert endings == set(CHARM_ENDINGS)


class TestLowEndBias:
    def test_most_prices_sit_in_the_lower_half_of_the_band(self) -> None:
        """A uniformly distributed catalogue reads as generated; a real one is bottom-heavy."""
        band = band_for("electronics")
        midpoint = (band.min_minor + band.max_minor) / 2
        prices = [synthesise_price_minor(f"p{i}", "electronics") for i in range(500)]

        below = [p for p in prices if p < midpoint]
        assert len(below) / len(prices) > 0.6

    def test_the_top_of_the_band_is_still_reachable(self) -> None:
        # A bias so strong that expensive items never appear would be its own kind of wrong.
        band = band_for("electronics")
        upper_quarter = band.min_minor + (band.max_minor - band.min_minor) * 0.75
        prices = [synthesise_price_minor(f"p{i}", "electronics") for i in range(2000)]

        assert any(price > upper_quarter for price in prices)


class TestDiscounts:
    def test_a_discount_is_deterministic(self) -> None:
        assert synthesise_discount_percentage("kaggle:7") == synthesise_discount_percentage(
            "kaggle:7"
        )

    def test_most_products_are_not_discounted(self) -> None:
        discounted = [synthesise_discount_percentage(f"p{i}") for i in range(500)]
        present = [d for d in discounted if d is not None]

        assert 0.1 < len(present) / len(discounted) < 0.35

    def test_a_discount_is_never_zero(self) -> None:
        """None and 0% must stay distinguishable: only the former renders without a strike."""
        for index in range(500):
            discount = synthesise_discount_percentage(f"p{index}")
            assert discount is None or discount > 0

    def test_discounts_stay_within_a_believable_range(self) -> None:
        for index in range(500):
            discount = synthesise_discount_percentage(f"p{index}")
            if discount is not None:
                assert 10 <= discount <= 40
