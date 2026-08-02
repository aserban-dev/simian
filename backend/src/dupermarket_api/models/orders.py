"""Order tables.

The two load-bearing ideas here:

* **Snapshots** (FR-027). `order_item` carries its own title, unit price, and image, so a
  catalogue change cannot rewrite what a user sees they paid.
* **Write-once timestamps** (FR-034). All four delivery stages are assigned at creation and
  never change. A trigger enforces it, because that is the only place that survives a future
  developer who has not read the spec.

There is no payment column. `demo_card_id` is not persisted: it has no effect on a successful
order, and storing it would create the first payment-shaped column in the schema.
"""

from __future__ import annotations

import datetime as dt
import uuid

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import BIGINT, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimestampMixin

# Applied in the migration. Named here so the model and the migration cannot drift apart
# silently — the DDL test asserts this exact text ships.
WRITE_ONCE_TRIGGER_SQL = """
CREATE OR REPLACE FUNCTION order_stages_are_write_once() RETURNS trigger AS $$
BEGIN
    IF NEW.processing_at IS DISTINCT FROM OLD.processing_at
       OR NEW.shipped_at IS DISTINCT FROM OLD.shipped_at
       OR NEW.out_for_delivery_at IS DISTINCT FROM OLD.out_for_delivery_at
       OR NEW.delivered_at IS DISTINCT FROM OLD.delivered_at
       OR NEW.origin_lat IS DISTINCT FROM OLD.origin_lat
       OR NEW.origin_lng IS DISTINCT FROM OLD.origin_lng
       OR NEW.destination_lat IS DISTINCT FROM OLD.destination_lat
       OR NEW.destination_lng IS DISTINCT FROM OLD.destination_lng
    THEN
        RAISE EXCEPTION
            'order delivery timeline is immutable after creation (FR-034)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_stages_write_once
    BEFORE UPDATE ON "order"
    FOR EACH ROW EXECUTE FUNCTION order_stages_are_write_once();
"""


class Order(Base, TimestampMixin):
    __tablename__ = "order"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_number: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app_user.id", ondelete="RESTRICT"), nullable=False
    )
    address_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("address.id", ondelete="RESTRICT"), nullable=False
    )
    # FR-044: even a purged address leaves the order correct.
    address_snapshot: Mapped[dict[str, str]] = mapped_column(JSONB, nullable=False)

    total_minor: Mapped[int] = mapped_column(BIGINT, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    base_total_minor: Mapped[int] = mapped_column(BIGINT, nullable=False)
    # The rate actually used, so a historical total is reproducible when rates change.
    fx_rate: Mapped[float] = mapped_column(Numeric(18, 8), nullable=False)

    origin_lat: Mapped[float] = mapped_column(Float, nullable=False)
    origin_lng: Mapped[float] = mapped_column(Float, nullable=False)
    destination_lat: Mapped[float] = mapped_column(Float, nullable=False)
    destination_lng: Mapped[float] = mapped_column(Float, nullable=False)

    # FR-033: all four assigned in the same transaction as the order.
    processing_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    shipped_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    out_for_delivery_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    delivered_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    items: Mapped[list[OrderItem]] = relationship(
        back_populates="order", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint("total_minor >= 0", name="total_non_negative"),
        # A monotonic timeline is what makes stage derivation total (FR-035).
        CheckConstraint(
            "processing_at <= shipped_at "
            "AND shipped_at <= out_for_delivery_at "
            "AND out_for_delivery_at <= delivered_at",
            name="timeline_monotonic",
        ),
        # A1/FR-033: the window is between 24 and 96 hours. "Plausible" is not testable;
        # this is, and it is enforced rather than asserted.
        CheckConstraint(
            "delivered_at >= processing_at + interval '24 hours' "
            "AND delivered_at <= processing_at + interval '96 hours'",
            name="delivery_window_bounds",
        ),
        Index("ix_order_user_created", "user_id", "created_at", "id"),
    )


class OrderItem(Base, TimestampMixin):
    __tablename__ = "order_item"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("order.id", ondelete="CASCADE"), nullable=False
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        # RESTRICT: order history outlives the catalogue entry.
        UUID(as_uuid=True),
        ForeignKey("product.id", ondelete="RESTRICT"),
        nullable=False,
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)

    # The three snapshot columns are the whole point of this table (FR-027).
    unit_price_minor: Mapped[int] = mapped_column(BIGINT, nullable=False)
    title_snapshot: Mapped[str] = mapped_column(Text, nullable=False)
    image_snapshot: Mapped[str] = mapped_column(Text, nullable=False)

    order: Mapped[Order] = relationship(back_populates="items")

    __table_args__ = (
        CheckConstraint("quantity > 0", name="quantity_positive"),
        CheckConstraint("unit_price_minor >= 0", name="unit_price_non_negative"),
        Index("ix_order_item_order", "order_id"),
    )
