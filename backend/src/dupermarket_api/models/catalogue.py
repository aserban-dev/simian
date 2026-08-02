"""Catalogue tables: category, product, product_image, review.

Follows data-model.md. The constraints below are the load-bearing part — several requirements
are enforced by the database rather than by application etiquette, because application code
forgets and a partial unique index does not.
"""

from __future__ import annotations

import datetime as dt
import uuid
from typing import TYPE_CHECKING

from sqlalchemy import (
    CheckConstraint,
    Computed,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import BIGINT, JSONB, TSVECTOR, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, MutableTimestampMixin, TimestampMixin

if TYPE_CHECKING:
    from .identity import AppUser

# Title matches weigh above description matches, which is the ordering users expect, while
# FR-003 still requires description-only matches to appear at all.
_SEARCH_VECTOR_SQL = (
    "setweight(to_tsvector('simple', coalesce(title->>'en', '')), 'A') || "
    "setweight(to_tsvector('simple', coalesce(description->>'en', '')), 'B')"
)


class Category(Base, TimestampMixin):
    __tablename__ = "category"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    slug: Mapped[str] = mapped_column(String(120), unique=True, nullable=False)
    # Locale map, e.g. {"en": "Shoes", "es": "Zapatos"} (FR-047 fallback happens on read).
    name: Mapped[dict[str, str]] = mapped_column(JSONB, nullable=False)
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("category.id", ondelete="RESTRICT"), nullable=True
    )
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_key: Mapped[str | None] = mapped_column(String(120), unique=True, nullable=True)

    children: Mapped[list[Category]] = relationship(back_populates="parent")
    parent: Mapped[Category | None] = relationship(
        back_populates="children", remote_side="Category.id"
    )

    __table_args__ = (
        # Serves the category grid and every drill-down from one index.
        Index("ix_category_parent_sort", "parent_id", "sort_order"),
    )


class Product(Base, MutableTimestampMixin):
    __tablename__ = "product"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sku: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    category_id: Mapped[uuid.UUID] = mapped_column(
        # RESTRICT, not CASCADE: order_item rows point here, and cascading a category delete
        # would silently take order history with it (FR-027).
        UUID(as_uuid=True),
        ForeignKey("category.id", ondelete="RESTRICT"),
        nullable=False,
    )
    title: Mapped[dict[str, str]] = mapped_column(JSONB, nullable=False)
    description: Mapped[dict[str, str]] = mapped_column(JSONB, nullable=False)

    # Research D4: money is an integer count of minor units. Never float, never numeric.
    base_price_minor: Mapped[int] = mapped_column(BIGINT, nullable=False)
    base_currency: Mapped[str] = mapped_column(String(3), nullable=False, server_default="EUR")
    discount_percentage: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)

    rating_average: Mapped[float] = mapped_column(Numeric(3, 2), nullable=False, server_default="0")
    rating_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    stock_status: Mapped[str] = mapped_column(String(16), nullable=False, server_default="in_stock")

    # FR-078 vs the catalogue: withdrawn products disappear from browsing, out-of-stock ones
    # do not. Soft withdrawal keeps order history resolvable (FR-027).
    withdrawn_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    search_vector: Mapped[str] = mapped_column(
        TSVECTOR, Computed(_SEARCH_VECTOR_SQL, persisted=True), nullable=False
    )
    source_id: Mapped[str | None] = mapped_column(String(120), unique=True, nullable=True)

    images: Mapped[list[ProductImage]] = relationship(
        back_populates="product", cascade="all, delete-orphan", order_by="ProductImage.sort_order"
    )
    category: Mapped[Category] = relationship()

    __table_args__ = (
        CheckConstraint("base_price_minor >= 0", name="price_non_negative"),
        CheckConstraint("rating_average >= 0 AND rating_average <= 5", name="rating_range"),
        CheckConstraint("rating_count >= 0", name="rating_count_non_negative"),
        CheckConstraint(
            "discount_percentage IS NULL OR (discount_percentage >= 0 "
            "AND discount_percentage <= 100)",
            name="discount_range",
        ),
        CheckConstraint(
            "stock_status IN ('in_stock', 'low_stock', 'out_of_stock')", name="stock_status_valid"
        ),
        Index("ix_product_search", "search_vector", postgresql_using="gin"),
        # Keyset cursors (research D3): the sort key plus id as tiebreaker.
        Index("ix_product_category_price", "category_id", "base_price_minor", "id"),
        Index(
            "ix_product_category_rating",
            "category_id",
            "rating_average",
            "id",
            postgresql_ops={"rating_average": "DESC"},
        ),
        Index("ix_product_created", "created_at", "id", postgresql_ops={"created_at": "DESC"}),
    )


class ProductImage(Base, TimestampMixin):
    __tablename__ = "product_image"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product.id", ondelete="CASCADE"), nullable=False
    )
    cdn_path: Mapped[str] = mapped_column(Text, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False)
    # FR-068: screen-reader text, generated at seed time from category and title.
    alt_text: Mapped[str] = mapped_column(Text, nullable=False)

    # FR-075: attribution captured at ingest, surfaced on the credits screen.
    source_name: Mapped[str] = mapped_column(String(64), nullable=False)
    source_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    photographer: Mapped[str | None] = mapped_column(Text, nullable=True)

    # FR-072: idempotency by content hash, so a changed source image is re-uploaded and an
    # unchanged one is not. "Does the key exist" cannot tell those apart.
    content_sha256: Mapped[str] = mapped_column(String(64), nullable=False)

    product: Mapped[Product] = relationship(back_populates="images")

    __table_args__ = (
        UniqueConstraint("product_id", "sort_order", name="uq_product_image_position"),
    )


class Review(Base, TimestampMixin):
    __tablename__ = "review"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product.id", ondelete="CASCADE"), nullable=False
    )
    # NULL means a seeded demo review, or an author whose account was removed. FR-017: reviews
    # are anonymised rather than deleted, so rating averages stay reproducible.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app_user.id", ondelete="SET NULL"), nullable=True
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Only the provider-supplied display name and avatar are ever read from here (FR-079).
    user: Mapped[AppUser | None] = relationship(lazy="joined")

    __table_args__ = (
        CheckConstraint("rating >= 1 AND rating <= 5", name="rating_range"),
        # FR-008: one review per user per product. Partial, so seeded reviews (user_id NULL)
        # are unconstrained and anonymised ones do not collide with each other.
        Index(
            "uq_review_one_per_user_product",
            "product_id",
            "user_id",
            unique=True,
            postgresql_where="user_id IS NOT NULL",
        ),
        Index("ix_review_product_created", "product_id", "created_at", "id"),
    )
