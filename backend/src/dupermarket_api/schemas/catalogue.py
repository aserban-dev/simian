"""Response models for the catalogue.

These mirror `contracts/openapi.yaml`. The contract is the source of truth; a meta-test compares
the generated schema against it so the two cannot drift silently.

`Review` is deliberately a closed set (FR-079) — reviews are readable anonymously, so any field
added here is published to the world.
"""

from __future__ import annotations

import datetime as dt
import uuid
from enum import StrEnum
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

CurrencyCode = Annotated[str, Field(pattern=r"^[A-Z]{3}$", examples=["EUR"])]


class StockStatus(StrEnum):
    in_stock = "in_stock"
    low_stock = "low_stock"
    out_of_stock = "out_of_stock"


class SortOrder(StrEnum):
    price_asc = "price_asc"
    price_desc = "price_desc"
    rating = "rating"
    newest = "newest"
    relevance = "relevance"


class Money(BaseModel):
    """Research D4: an exact integer count of minor units. Never a float."""

    model_config = ConfigDict(frozen=True)

    amount_minor: int
    currency: CurrencyCode


class Category(BaseModel):
    id: uuid.UUID
    slug: str
    # Resolved for the requested locale with an English fallback (FR-047).
    name: str
    image_url: str | None = None
    sort_order: int
    children: list[Category] = Field(default_factory=list)


class ImageAttribution(BaseModel):
    """FR-075: populated when the source's licence requires credit."""

    source: str
    photographer: str | None = None
    source_url: str | None = None


class ProductImage(BaseModel):
    url: str
    sort_order: int
    # FR-068: screen-reader text.
    alt_text: str
    attribution: ImageAttribution | None = None


class ProductSummary(BaseModel):
    id: uuid.UUID
    title: str
    price: Money
    # FR-077: present only when discounted; rendered struck through, converted through the
    # same call as `price` so the two can never appear in different currencies.
    original_price: Money | None = None
    thumbnail_url: str
    thumbnail_alt: str
    rating_average: float
    rating_count: int
    # FR-078: out-of-stock products stay browsable and are labelled; only withdrawn ones vanish.
    stock_status: StockStatus


class ProductDetail(ProductSummary):
    description: str
    sku: str
    category_slug: str
    images: list[ProductImage] = Field(min_length=1)


class Review(BaseModel):
    """FR-079: a closed set. Nothing beyond these fields may be exposed, to anyone."""

    id: uuid.UUID
    rating: int = Field(ge=1, le=5)
    comment: str | None = None
    author_name: str | None = None
    author_avatar_url: str | None = None
    created_at: dt.datetime


class ReviewCreate(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000)


class CategoryList(BaseModel):
    items: list[Category]


class ProductPage(BaseModel):
    items: list[ProductSummary]
    # Null on the last page (FR-002).
    next_cursor: str | None = None
    currency: CurrencyCode
    # FR-052: true when the requested currency had no rate and prices are in the base currency.
    currency_fallback: bool = False


class ReviewPage(BaseModel):
    items: list[Review]
    next_cursor: str | None = None


Category.model_rebuild()
