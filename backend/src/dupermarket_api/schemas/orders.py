"""Order request and response models (T081).

These mirror the order half of `contracts/openapi.yaml`. Two things are worth reading twice:

* [`DemoCardId`](#DemoCardId) is a closed enum, not a string. That is the whole payment surface
  of this application — there is no field here, or anywhere else, that accepts a card number,
  expiry or security code (FR-023, constitution Principle I). `tests/contract/
  test_no_payment_fields.py` re-checks that mechanically on every run.
* [`OrderCreate.items`](#OrderCreate) requires at least one line, matching the contract's
  `minItems: 1`. An order with nothing in it is not a degenerate case to handle downstream, it
  is a bad request.
"""

from __future__ import annotations

import datetime as dt
import uuid
from enum import StrEnum
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from .catalogue import CurrencyCode, Money

MAX_QUANTITY = 99


class DemoCardId(StrEnum):
    """The built-in cosmetic cards. Not payment instruments.

    `decline` is required by FR-024: the declined path has to be reachable deterministically,
    or it cannot be demonstrated or tested.
    """

    visa_success = "visa_success"
    mastercard_success = "mastercard_success"
    decline = "decline"


class DeliveryStage(StrEnum):
    processing = "processing"
    shipped = "shipped"
    out_for_delivery = "out_for_delivery"
    delivered = "delivered"


class OrderLineInput(BaseModel):
    product_id: uuid.UUID
    quantity: Annotated[int, Field(ge=1, le=MAX_QUANTITY)]


class OrderCreate(BaseModel):
    """A checkout submission.

    `model_config` forbids nothing extra on purpose — an unknown field is ignored rather than
    rejected, so a client sending something payment-shaped gets it dropped on the floor instead
    of triggering a validation error that might tempt someone to "support" it.
    """

    items: Annotated[list[OrderLineInput], Field(min_length=1)]
    address_id: uuid.UUID
    demo_card_id: DemoCardId
    currency: CurrencyCode
    idempotency_key: Annotated[str | None, Field(max_length=128)] = None


class OrderItem(BaseModel):
    """A line as recorded, not as the catalogue reads today (FR-027)."""

    model_config = ConfigDict(frozen=True)

    product_id: uuid.UUID
    quantity: int
    unit_price: Money
    title: str
    image_url: str


class LatLng(BaseModel):
    model_config = ConfigDict(frozen=True)

    lat: float
    lng: float


class DeliveryStages(BaseModel):
    model_config = ConfigDict(frozen=True)

    processing_at: dt.datetime
    shipped_at: dt.datetime
    out_for_delivery_at: dt.datetime
    delivered_at: dt.datetime


class DeliveryTracking(BaseModel):
    """Everything the client needs to place the parcel itself (FR-036).

    The server sends endpoints and timestamps and never a position: computing it here would make
    the parcel a server-held value that has to be refreshed, which is exactly the background
    progression Principle III forbids.
    """

    model_config = ConfigDict(frozen=True)

    origin: LatLng
    destination: LatLng
    window_start: dt.datetime
    window_end: dt.datetime
    current_stage: DeliveryStage
    stages: DeliveryStages


class OrderAddress(BaseModel):
    """The address as it was at purchase time (FR-044)."""

    model_config = ConfigDict(frozen=True)

    recipient_name: str | None = None
    formatted: str


class OrderSummary(BaseModel):
    id: uuid.UUID
    order_number: str
    created_at: dt.datetime
    total: Money
    current_stage: DeliveryStage
    item_count: int
    thumbnail_url: str | None = None


class OrderDetail(OrderSummary):
    items: list[OrderItem]
    address: OrderAddress
    tracking: DeliveryTracking
