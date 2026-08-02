"""Model → response mapping.

Pure functions over lightweight stand-ins, so no database is involved. This is where FR-006,
FR-047, FR-052, FR-061 and FR-077 are actually covered.
"""

from __future__ import annotations

import datetime as dt
import uuid
from decimal import Decimal
from types import SimpleNamespace

import pytest

from dupermarket_api.services.currency import CurrencyService
from dupermarket_api.services.presentation import (
    cdn_url,
    discounted_minor,
    localise,
    product_summary,
    review_schema,
)

pytestmark = pytest.mark.unit

CDN = "https://images.dupermarket.example"


def make_product(**overrides: object) -> SimpleNamespace:
    base = {
        "id": uuid.uuid4(),
        "sku": "SKU-1",
        "title": {"en": "Running shoes", "es": "Zapatillas"},
        "description": {"en": "Light and fast"},
        "base_price_minor": 5000,
        "base_currency": "EUR",
        "discount_percentage": None,
        "rating_average": Decimal("4.25"),
        "rating_count": 12,
        "stock_status": "in_stock",
        "images": [],
        "category": SimpleNamespace(slug="shoes"),
    }
    base.update(overrides)
    return SimpleNamespace(**base)


def make_image(sort_order: int = 0, **overrides: object) -> SimpleNamespace:
    base = {
        "cdn_path": f"products/x/{sort_order}.webp",
        "sort_order": sort_order,
        "alt_text": f"Running shoes, view {sort_order + 1}",
        "source_name": "pexels",
        "source_url": None,
        "photographer": None,
    }
    base.update(overrides)
    return SimpleNamespace(**base)


def summarise(product: SimpleNamespace, currency: str = "EUR", locale: str = "en"):
    return product_summary(
        product,  # type: ignore[arg-type]
        currency=CurrencyService(),
        target_currency=currency,
        locale=locale,
        cdn_base_url=CDN,
    )


class TestLocalisation:
    def test_the_requested_locale_wins(self) -> None:
        """FR-047."""
        assert localise({"en": "Shoes", "es": "Zapatos"}, "es") == "Zapatos"

    def test_a_missing_translation_falls_back_to_english(self) -> None:
        """FR-047: never a key, never an empty screen."""
        assert localise({"en": "Shoes"}, "de") == "Shoes"

    def test_an_empty_translation_falls_back_rather_than_showing_blank(self) -> None:
        assert localise({"en": "Shoes", "de": ""}, "de") == "Shoes"

    def test_a_missing_map_returns_empty_rather_than_raising(self) -> None:
        assert localise(None, "en") == ""


class TestCdnUrls:
    def test_a_stored_path_becomes_a_public_cdn_url(self) -> None:
        assert cdn_url(CDN, "products/a/0.webp") == f"{CDN}/products/a/0.webp"

    def test_slashes_do_not_double_up(self) -> None:
        assert cdn_url(CDN + "/", "/products/a/0.webp") == f"{CDN}/products/a/0.webp"

    def test_an_absolute_url_is_passed_through(self) -> None:
        # Seeded data may already carry a full URL; rewriting it would break the image.
        assert cdn_url(CDN, "https://other.example/x.jpg") == "https://other.example/x.jpg"


class TestDiscounts:
    def test_no_discount_leaves_the_price_alone(self) -> None:
        assert discounted_minor(5000, None) == 5000
        assert discounted_minor(5000, 0) == 5000

    def test_a_discount_comes_off_the_list_price(self) -> None:
        """FR-077, and the convention documented in presentation.py."""
        assert discounted_minor(5000, 20) == 4000

    def test_rounding_is_half_up_at_the_minor_unit(self) -> None:
        # 999 * 0.895 = 894.105 -> 894
        assert discounted_minor(999, Decimal("10.5")) == 894

    def test_a_discounted_product_exposes_the_original_struck_through(self) -> None:
        """FR-077."""
        summary, _ = summarise(make_product(discount_percentage=Decimal("20")))

        assert summary.price.amount_minor == 4000
        assert summary.original_price is not None
        assert summary.original_price.amount_minor == 5000

    def test_an_undiscounted_product_invents_no_original(self) -> None:
        """FR-077: a struck-through price that equals the real one is a lie."""
        summary, _ = summarise(make_product())
        assert summary.original_price is None

    def test_price_and_original_are_always_the_same_currency(self) -> None:
        """FR-077: the failure mode is a EUR original beside a USD price."""
        summary, _ = summarise(make_product(discount_percentage=Decimal("20")), currency="USD")
        assert summary.original_price is not None
        assert summary.price.currency == summary.original_price.currency == "USD"

    def test_they_stay_paired_when_conversion_falls_back(self) -> None:
        """FR-052 + FR-077 together."""
        summary, fallback = summarise(
            make_product(discount_percentage=Decimal("20")), currency="JPY"
        )
        assert fallback is True
        assert summary.original_price is not None
        assert summary.price.currency == summary.original_price.currency == "EUR"


class TestCurrencyReporting:
    def test_a_known_currency_converts_without_fallback(self) -> None:
        summary, fallback = summarise(make_product(), currency="USD")
        assert fallback is False
        assert summary.price.currency == "USD"
        assert summary.price.amount_minor == 5450  # 50.00 x 1.09

    def test_an_unknown_currency_reports_the_fallback(self) -> None:
        """FR-052: the client must be able to explain the symbol it is showing."""
        summary, fallback = summarise(make_product(), currency="JPY")
        assert fallback is True
        assert summary.price.currency == "EUR"


class TestImages:
    def test_the_lowest_sort_order_is_the_thumbnail(self) -> None:
        """FR-006: the first image is the thumbnail, whatever order the rows arrive in."""
        product = make_product(images=[make_image(2), make_image(0), make_image(1)])
        summary, _ = summarise(product)
        assert summary.thumbnail_url.endswith("/0.webp")

    def test_the_thumbnail_carries_screen_reader_text(self) -> None:
        """FR-068."""
        summary, _ = summarise(make_product(images=[make_image(0)]))
        assert summary.thumbnail_alt == "Running shoes, view 1"

    def test_a_product_with_no_images_maps_without_raising(self) -> None:
        """FR-061: one bad product must not take the whole grid down with it."""
        summary, _ = summarise(make_product(images=[]))
        assert summary.thumbnail_url == ""
        # Falls back to the title so the tile is still announced meaningfully.
        assert summary.thumbnail_alt == "Running shoes"


class TestReviewMapping:
    def test_a_review_exposes_only_the_permitted_author_fields(self) -> None:
        """FR-079."""
        review = SimpleNamespace(
            id=uuid.uuid4(),
            rating=5,
            comment="Great",
            created_at=dt.datetime(2026, 8, 2, tzinfo=dt.UTC),
            user=SimpleNamespace(
                display_name="Sam", avatar_url="https://cdn/a.png", firebase_uid="secret-uid"
            ),
        )
        mapped = review_schema(review)  # type: ignore[arg-type]

        assert mapped.author_name == "Sam"
        assert "secret-uid" not in mapped.model_dump_json()

    def test_a_seeded_review_with_no_author_maps_cleanly(self) -> None:
        review = SimpleNamespace(
            id=uuid.uuid4(),
            rating=4,
            comment=None,
            created_at=dt.datetime(2026, 8, 2, tzinfo=dt.UTC),
            user=None,
        )
        mapped = review_schema(review)  # type: ignore[arg-type]
        assert mapped.author_name is None
        assert mapped.rating == 4
