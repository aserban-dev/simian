"""Address and wishlist models (T118, T119).

Mirrors the profile half of `contracts/openapi.yaml`. `lat`/`lng` appear on the response and
never on the input: coordinates are resolved server-side on write (FR-042), so a client that
sent them would be supplying a value the system is supposed to derive.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from .catalogue import ProductSummary


class AddressInput(BaseModel):
    label: Annotated[str | None, Field(max_length=64)] = None
    recipient_name: str | None = None
    line1: Annotated[str, Field(min_length=1)]
    line2: str | None = None
    city: Annotated[str, Field(min_length=1)]
    postal_code: Annotated[str | None, Field(max_length=32)] = None
    country_code: Annotated[str, Field(pattern=r"^[A-Z]{2}$")]
    is_default: bool = False


class Address(AddressInput):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    # Resolved once, on write (FR-042). Not nullable, because FR-043 forbids saving an address
    # that could not be placed — so an address row without coordinates cannot exist.
    lat: float
    lng: float
    is_default: bool


class AddressList(BaseModel):
    items: list[Address]


class WishlistItemInput(BaseModel):
    product_id: uuid.UUID


class WishlistPage(BaseModel):
    items: list[ProductSummary]
    next_cursor: str | None = None
