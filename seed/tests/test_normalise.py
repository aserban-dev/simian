"""Taxonomy normalisation and exclusions (T140).

FR-071: food, vehicle and motorcycle categories never survive. The exclusion is enforced once,
here, rather than in each ingest module — and the tests below check it from both directions,
because the interesting failure is not "an excluded category got through" but "a *renamed*
excluded category got through", which a whitelist catches and a blacklist alone does not.
"""

from __future__ import annotations

import pytest

from dupermarket_seed.models import SourceImage, SourceProduct
from dupermarket_seed.normalise import (
    CATEGORY_MAP,
    EXCLUDED_CATEGORIES,
    canonical,
    category_slug_for,
    is_excluded,
    normalise,
    normalise_all,
)


def product(
    category: str,
    *,
    source_id: str = "dummyjson:1",
    price_minor: int | None = 1999,
    title: str = "A Thing",
) -> SourceProduct:
    return SourceProduct(
        source_id=source_id,
        title=title,
        description="A thing you can buy",
        source_category=category,
        images=[SourceImage(url="https://cdn/a.jpg", source="DummyJSON")],
        price_minor=price_minor,
    )


class TestExclusions:
    @pytest.mark.parametrize("category", sorted(EXCLUDED_CATEGORIES))
    def test_every_excluded_category_is_rejected(self, category: str) -> None:
        assert is_excluded(category)
        assert category_slug_for(category) is None

    @pytest.mark.parametrize(
        "category",
        ["Groceries", "GROCERIES", " groceries ", "motor-cycle", "Motorcycles", "Vehicle"],
    )
    def test_spelling_variations_are_still_excluded(self, category: str) -> None:
        """Two sources spell categories differently; the exclusion must not depend on which."""
        assert category_slug_for(category) is None

    def test_an_excluded_product_is_dropped_entirely(self) -> None:
        assert normalise(product("groceries")) is None

    def test_excluded_products_do_not_survive_a_batch(self) -> None:
        batch = [
            product("beauty", source_id="a"),
            product("groceries", source_id="b"),
            product("motorcycle", source_id="c"),
            product("laptops", source_id="d"),
        ]

        surviving = normalise_all(batch)

        assert {p.source_id for p in surviving} == {"a", "d"}

    def test_no_excluded_category_is_also_mapped(self) -> None:
        """A category cannot be both excluded and admitted — that would be decided by ordering."""
        mapped = {canonical(key) for key in CATEGORY_MAP}

        assert mapped.isdisjoint(EXCLUDED_CATEGORIES)


class TestUnmappedCategories:
    def test_an_unrecognised_category_is_dropped_not_passed_through(self) -> None:
        """The failure this prevents: an excluded category arriving under a new source name."""
        assert normalise(product("weaponry")) is None

    def test_an_empty_category_is_dropped(self) -> None:
        assert normalise(product("")) is None


class TestMapping:
    def test_a_mapped_category_becomes_its_app_slug(self) -> None:
        normalised = normalise(product("laptops"))

        assert normalised is not None
        assert normalised.category_slug == "electronics"

    def test_several_source_categories_can_share_one_slug(self) -> None:
        for source in ("beauty", "fragrances", "skin-care"):
            normalised = normalise(product(source))
            assert normalised is not None
            assert normalised.category_slug == "beauty"

    def test_every_mapped_slug_is_lowercase_and_hyphenated(self) -> None:
        for slug in set(CATEGORY_MAP.values()):
            assert slug == slug.lower()
            assert " " not in slug and "_" not in slug

    def test_the_title_is_trimmed(self) -> None:
        normalised = normalise(product("beauty", title="  Mascara  "))

        assert normalised is not None
        assert normalised.title == "Mascara"

    def test_images_are_carried_through(self) -> None:
        normalised = normalise(product("beauty"))

        assert normalised is not None
        assert len(normalised.images) == 1


class TestPricing:
    def test_a_product_with_no_price_and_no_synthesis_is_dropped(self) -> None:
        """A zero would render as free; dropping is the honest outcome."""
        assert normalise(product("beauty", price_minor=None)) is None

    def test_a_synthesised_price_is_used(self) -> None:
        normalised = normalise(product("beauty", price_minor=None), price_minor=2499)

        assert normalised is not None
        assert normalised.price_minor == 2499

    def test_a_synthesised_price_overrides_the_source(self) -> None:
        normalised = normalise(product("beauty", price_minor=1000), price_minor=2499)

        assert normalised is not None
        assert normalised.price_minor == 2499

    def test_a_negative_price_is_dropped(self) -> None:
        assert normalise(product("beauty", price_minor=-1)) is None

    def test_the_batch_synthesises_only_where_needed(self) -> None:
        calls: list[str] = []

        def price_for(source: SourceProduct) -> int:
            calls.append(source.source_id)
            return 2499

        batch = [
            product("beauty", source_id="has-price", price_minor=1000),
            product("beauty", source_id="no-price", price_minor=None),
        ]

        surviving = normalise_all(batch, price_for=price_for)

        assert calls == ["no-price"]
        assert {p.source_id: p.price_minor for p in surviving} == {
            "has-price": 1000,
            "no-price": 2499,
        }
