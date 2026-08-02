"""The single geocoding seam (T117).

Principle V and FR-042: an address is resolved to coordinates **once, on the write path**, and
the coordinates are stored. Nothing reads an address and geocodes it again.

That rule is a cost decision as much as a design one — geocoding is metered, and a read-path
call would bill on every order screen — so it is enforced structurally rather than by
convention: this module is only ever imported by the create and update handlers, and `address`
has `lat`/`lng` as `NOT NULL`, so a row that was never geocoded cannot exist.

FR-043 is the other half: an address that cannot be resolved is **not saved at all**. A partial
address would be a row the delivery simulation could not place on a map, discovered at checkout
rather than at save time.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True, slots=True)
class Coordinates:
    lat: float
    lng: float


@dataclass(frozen=True, slots=True)
class AddressQuery:
    """The fields a geocoder is allowed to see. Deliberately not the ORM row."""

    line1: str
    line2: str | None
    city: str
    postal_code: str | None
    country_code: str

    def as_text(self) -> str:
        parts = [self.line1, self.line2, self.postal_code, self.city, self.country_code]
        return ", ".join(part for part in parts if part)


class Geocoder(Protocol):
    """Resolve an address, or return None when it cannot be placed.

    Returning None rather than raising keeps "not found" an ordinary answer — it is the common
    case for a typo, not an exceptional one — and leaves the HTTP mapping to the router.
    """

    def resolve(self, query: AddressQuery) -> Coordinates | None: ...


# A small fixed table, in the same spirit as the fixed currency rates (spec §8.3 phase 1) and
# the fictional warehouses. It resolves the cities this demo ships to and declines everything
# else, which keeps FR-043's rejection path reachable without a network call — and keeps the
# whole test suite free of an external dependency and a metered API key.
#
# Phase 2 replaces this class with one that calls the Geocoding API. Callers do not change.
_KNOWN_CITIES: dict[tuple[str, str], Coordinates] = {
    ("RO", "bucharest"): Coordinates(44.4268, 26.1025),
    ("RO", "cluj-napoca"): Coordinates(46.7712, 23.6236),
    ("RO", "timisoara"): Coordinates(45.7489, 21.2087),
    ("PL", "warsaw"): Coordinates(52.2297, 21.0122),
    ("PL", "krakow"): Coordinates(50.0647, 19.9450),
    ("DE", "berlin"): Coordinates(52.5200, 13.4050),
    ("DE", "munich"): Coordinates(48.1351, 11.5820),
    ("FR", "paris"): Coordinates(48.8566, 2.3522),
    ("FR", "lyon"): Coordinates(45.7640, 4.8357),
    ("ES", "madrid"): Coordinates(40.4168, -3.7038),
    ("ES", "barcelona"): Coordinates(41.3874, 2.1686),
    ("SE", "stockholm"): Coordinates(59.3293, 18.0686),
    ("IE", "dublin"): Coordinates(53.3498, -6.2603),
    ("NL", "amsterdam"): Coordinates(52.3676, 4.9041),
    ("BE", "brussels"): Coordinates(50.8503, 4.3517),
    ("IT", "rome"): Coordinates(41.9028, 12.4964),
    ("IT", "milan"): Coordinates(45.4642, 9.1900),
}


class FixedTableGeocoder:
    """v1: resolves a known city to its centre, and declines anything else.

    House-number precision is not modelled, and does not need to be — the delivery map draws a
    line between a warehouse and a destination hundreds of kilometres away, where a few hundred
    metres of error is invisible.
    """

    def resolve(self, query: AddressQuery) -> Coordinates | None:
        key = (query.country_code.upper(), query.city.strip().lower())
        return _KNOWN_CITIES.get(key)


class CountingGeocoder:
    """Wraps a geocoder and counts calls.

    Exists for FR-042's test (T113): "geocoded once on write, never on read" is a claim about
    *how many times* the seam is entered, and only a counter can assert it.
    """

    def __init__(self, inner: Geocoder | None = None) -> None:
        self._inner = inner or FixedTableGeocoder()
        self.calls = 0

    def resolve(self, query: AddressQuery) -> Coordinates | None:
        self.calls += 1
        return self._inner.resolve(query)


def get_geocoder() -> Geocoder:
    """The dependency. Overridden in tests, and replaced wholesale in phase 2."""
    return FixedTableGeocoder()


def is_location_bearing_change(current: AddressQuery, incoming: AddressQuery) -> bool:
    """Whether an update needs re-geocoding.

    The contract says an update "re-geocodes only when a location-bearing field changes", so
    renaming a label or a recipient must not spend a geocoding call. `line2` is included: an
    apartment number does not move the pin, but a corrected street does, and the two arrive in
    the same field often enough that treating it as location-bearing is the safe default.
    """
    return (
        current.line1 != incoming.line1
        or current.line2 != incoming.line2
        or current.city != incoming.city
        or current.postal_code != incoming.postal_code
        or current.country_code != incoming.country_code
    )
