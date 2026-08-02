"""Saved delivery addresses (T118).

Four operations, and three rules that are easy to state and easy to get wrong:

* **Exactly one default** (FR-041). Enforced by a partial unique index, so it is a property of
  the database rather than of every code path that touches `is_default`. The application still
  has to clear the old default before setting a new one — but if it forgets, the write fails
  loudly instead of leaving two.
* **Geocode on write only** (FR-042), through the one seam in `services/geocoding.py`.
* **Delete is soft** (FR-044). An order references the address it shipped to, and history must
  not change because a user tidied their address book.
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Path, Response, status
from sqlalchemy import Select, select
from sqlalchemy.orm import Session

from ..auth.user_provisioning import CurrentUser
from ..deps import ClockDep, DbDep
from ..errors import NotFound, UnprocessableAddress
from ..models import Address
from ..schemas.profile import Address as AddressSchema
from ..schemas.profile import AddressInput, AddressList
from ..services.geocoding import (
    AddressQuery,
    Coordinates,
    Geocoder,
    get_geocoder,
    is_location_bearing_change,
)

router = APIRouter(tags=["profile"])

GeocoderDep = Annotated[Geocoder, Depends(get_geocoder)]


def _query_from(body: AddressInput) -> AddressQuery:
    return AddressQuery(
        line1=body.line1,
        line2=body.line2,
        city=body.city,
        postal_code=body.postal_code,
        country_code=body.country_code,
    )


def _query_from_row(row: Address) -> AddressQuery:
    return AddressQuery(
        line1=row.line1,
        line2=row.line2,
        city=row.city,
        postal_code=row.postal_code,
        country_code=row.country_code,
    )


def _resolve(geocoder: Geocoder, body: AddressInput) -> Coordinates:
    """FR-043: an address that cannot be placed is not saved, and the user is told why."""
    coordinates = geocoder.resolve(_query_from(body))
    if coordinates is None:
        raise UnprocessableAddress(
            "We couldn't find that address. Check the street and city and try again — "
            "nothing was saved."
        )
    return coordinates


def _live_addresses(user_id: uuid.UUID) -> Select[tuple[Address]]:
    """Everything not soft-deleted. Soft-deleted rows still exist for their orders (FR-044)."""
    return select(Address).where(Address.user_id == user_id, Address.deleted_at.is_(None))


def _find(session: Session, user_id: uuid.UUID, address_id: uuid.UUID) -> Address | None:
    """Scoped to the owner, so another user's address is simply not found (FR-013)."""
    return session.scalar(_live_addresses(user_id).where(Address.id == address_id))


def _clear_other_defaults(session: Session, user_id: uuid.UUID, keep: uuid.UUID | None) -> None:
    """Demote every other default before promoting one.

    Flushed by the caller inside the same transaction as the promotion, so the partial unique
    index never sees two — the window in which it would is the bug this exists to close.
    """
    for row in session.scalars(_live_addresses(user_id).where(Address.is_default)):
        if row.id != keep:
            row.is_default = False


@router.get(
    "/me/addresses",
    response_model=AddressList,
    summary="List saved addresses",
    operation_id="listAddresses",
)
def list_addresses(user: CurrentUser, session: DbDep) -> AddressList:
    """FR-040. Soft-deleted rows are gone from here but still referenced by their orders."""
    rows = session.scalars(
        _live_addresses(user.id).order_by(Address.is_default.desc(), Address.created_at)
    ).all()
    return AddressList(items=[AddressSchema.model_validate(row) for row in rows])


@router.post(
    "/me/addresses",
    response_model=AddressSchema,
    status_code=status.HTTP_201_CREATED,
    summary="Save an address",
    operation_id="createAddress",
)
def create_address(
    body: AddressInput,
    user: CurrentUser,
    session: DbDep,
    geocoder: GeocoderDep,
    clock: ClockDep,
) -> AddressSchema:
    """FR-040, FR-042, FR-043. The only place in the system that geocodes, with update."""
    coordinates = _resolve(geocoder, body)

    existing = session.scalars(_live_addresses(user.id)).all()
    # FR-041: the first address is the default whatever the client asked for — "exactly one" is
    # not satisfiable otherwise, and a user with one address and no default is a broken checkout.
    is_default = body.is_default or not existing

    if is_default:
        _clear_other_defaults(session, user.id, keep=None)
        session.flush()

    address = Address(
        user_id=user.id,
        label=body.label,
        recipient_name=body.recipient_name,
        line1=body.line1,
        line2=body.line2,
        city=body.city,
        postal_code=body.postal_code,
        country_code=body.country_code,
        lat=coordinates.lat,
        lng=coordinates.lng,
        is_default=is_default,
        created_at=clock.now(),
        updated_at=clock.now(),
    )
    session.add(address)
    session.flush()
    return AddressSchema.model_validate(address)


@router.patch(
    "/me/addresses/{addressId}",
    response_model=AddressSchema,
    summary="Update an address",
    operation_id="updateAddress",
)
def update_address(
    address_id: Annotated[uuid.UUID, Path(alias="addressId")],
    body: AddressInput,
    user: CurrentUser,
    session: DbDep,
    geocoder: GeocoderDep,
    clock: ClockDep,
) -> AddressSchema:
    """Re-geocodes only when a location-bearing field changed.

    Renaming a label is free; moving the street is not. Geocoding is metered, so "only when it
    moved" is a cost rule, not an optimisation.
    """
    address = _find(session, user.id, address_id)
    if address is None:
        raise NotFound("We couldn't find that address.")

    if is_location_bearing_change(_query_from_row(address), _query_from(body)):
        coordinates = _resolve(geocoder, body)
        address.lat = coordinates.lat
        address.lng = coordinates.lng

    address.label = body.label
    address.recipient_name = body.recipient_name
    address.line1 = body.line1
    address.line2 = body.line2
    address.city = body.city
    address.postal_code = body.postal_code
    address.country_code = body.country_code
    address.updated_at = clock.now()

    if body.is_default and not address.is_default:
        _clear_other_defaults(session, user.id, keep=address.id)
        session.flush()
        address.is_default = True

    session.flush()
    return AddressSchema.model_validate(address)


@router.delete(
    "/me/addresses/{addressId}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete an address",
    operation_id="deleteAddress",
)
def delete_address(
    address_id: Annotated[uuid.UUID, Path(alias="addressId")],
    user: CurrentUser,
    session: DbDep,
    clock: ClockDep,
) -> Response:
    """Soft delete (FR-044), with default promotion.

    The row stays because an order points at it. Clearing `is_default` on the way out is what
    frees the partial unique index's slot for the promoted address.
    """
    address = _find(session, user.id, address_id)
    if address is None:
        raise NotFound("We couldn't find that address.")

    was_default = address.is_default
    address.deleted_at = clock.now()
    address.is_default = False
    session.flush()

    if was_default:
        # Most recently added of what remains — the closest available reading of the contract's
        # "most recently used" without a usage column to read.
        replacement = session.scalars(
            _live_addresses(user.id).order_by(Address.created_at.desc())
        ).first()
        if replacement is not None:
            replacement.is_default = True
            session.flush()

    return Response(status_code=status.HTTP_204_NO_CONTENT)
