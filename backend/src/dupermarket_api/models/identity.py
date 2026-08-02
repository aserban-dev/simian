"""Identity tables: app_user, address, wishlist_item, device.

`app_user` rather than `user` because `user` is reserved in PostgreSQL.

There is deliberately no payment-related column anywhere in this module, or any other.
`scripts/check_traceability.py` asserts that mechanically (SC-013) — "we did not add one" is
not a durable guarantee.
"""

from __future__ import annotations

import datetime as dt
import uuid

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, MutableTimestampMixin, TimestampMixin


class AppUser(Base, MutableTimestampMixin):
    __tablename__ = "app_user"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # The `sub` claim from the Firebase ID token. Canonical identity; the backend mints nothing.
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    display_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    language_override: Mapped[str | None] = mapped_column(String(35), nullable=True)
    currency_override: Mapped[str | None] = mapped_column(String(3), nullable=True)
    notification_prefs: Mapped[dict[str, bool]] = mapped_column(
        JSONB, nullable=False, server_default="{}"
    )
    # FR-017: a request, not an erasure. Setting this deletes device rows and nothing else.
    deletion_requested_at: Mapped[dt.datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    addresses: Mapped[list[Address]] = relationship(back_populates="user")
    devices: Mapped[list[Device]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )


class Address(Base, MutableTimestampMixin):
    __tablename__ = "address"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app_user.id", ondelete="CASCADE"), nullable=False
    )
    label: Mapped[str | None] = mapped_column(String(64), nullable=True)
    recipient_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    line1: Mapped[str] = mapped_column(Text, nullable=False)
    line2: Mapped[str | None] = mapped_column(Text, nullable=True)
    city: Mapped[str] = mapped_column(Text, nullable=False)
    postal_code: Mapped[str | None] = mapped_column(String(32), nullable=True)
    country_code: Mapped[str] = mapped_column(String(2), nullable=False)

    # FR-042: resolved once, on write. NOT NULL is what makes FR-043 unavoidable — a partial
    # address simply cannot be stored.
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)

    is_default: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    # FR-044: soft delete, because an order references the address it shipped to.
    deleted_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[AppUser] = relationship(back_populates="addresses")

    __table_args__ = (
        CheckConstraint("lat >= -90 AND lat <= 90", name="lat_range"),
        CheckConstraint("lng >= -180 AND lng <= 180", name="lng_range"),
        # FR-041: exactly one default, as a database invariant rather than application
        # etiquette. Partial so soft-deleted addresses do not occupy the slot.
        Index(
            "uq_address_one_default",
            "user_id",
            unique=True,
            postgresql_where="is_default AND deleted_at IS NULL",
        ),
        Index("ix_address_user", "user_id", "deleted_at"),
    )


class WishlistItem(Base, TimestampMixin):
    __tablename__ = "wishlist_item"

    # Composite primary key makes "add" idempotent by construction (FR-045).
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app_user.id", ondelete="CASCADE"), primary_key=True
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product.id", ondelete="CASCADE"), primary_key=True
    )


class Device(Base, TimestampMixin):
    __tablename__ = "device"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app_user.id", ondelete="CASCADE"), nullable=False
    )
    # Unique across ALL users, not per user. A shared device that signs out and back in as
    # someone else must not keep pushing the first user's order updates to the second.
    fcm_token: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    platform: Mapped[str] = mapped_column(String(16), nullable=False)
    last_seen_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    user: Mapped[AppUser] = relationship(back_populates="devices")

    __table_args__ = (CheckConstraint("platform IN ('ios', 'android')", name="platform_valid"),)
