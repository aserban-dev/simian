"""The delivery simulation (T096).

Everything about *where a parcel is and when it moves* lives here, and nothing about it lives
anywhere else. Three rules, each load-bearing:

* **The whole timeline is assigned once, at order creation** (FR-033), and the columns are never
  updated afterwards — a database trigger enforces that half (FR-034).
* **The current stage is a pure function** of those stored timestamps and the clock (FR-035).
  There is no background job, no cron, and no server-held parcel position. Reading later simply
  returns a later answer.
* **The window is deterministic** (Principle III, research D5): jitter is derived by hashing the
  order id, so the same order always produces the same timeline — including when a test
  recomputes it — while two orders placed in the same second do not look cloned.

The client computes the parcel's position itself from the endpoints and the window (FR-037), so
there is deliberately no position function in this module.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import math
import uuid
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class Warehouse:
    name: str
    lat: float
    lng: float


# Fictional. Research D5: nearest-warehouse selection keeps the map line short enough to look
# real without any logistics integration existing.
WAREHOUSES: tuple[Warehouse, ...] = (
    Warehouse("Bucharest Hub", 44.4268, 26.1025),
    Warehouse("Warsaw Hub", 52.2297, 21.0122),
    Warehouse("Berlin Hub", 52.5200, 13.4050),
    Warehouse("Paris Hub", 48.8566, 2.3522),
    Warehouse("Madrid Hub", 40.4168, -3.7038),
    Warehouse("Stockholm Hub", 59.3293, 18.0686),
    Warehouse("Dublin Hub", 53.3498, -6.2603),
)

_EARTH_RADIUS_KM = 6371.0


def great_circle_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Haversine distance. Only ever used to rank warehouses, never shown to a user."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def nearest_warehouse(lat: float, lng: float) -> Warehouse:
    return min(WAREHOUSES, key=lambda w: great_circle_km(lat, lng, w.lat, w.lng))


@dataclass(frozen=True, slots=True)
class Timeline:
    processing_at: dt.datetime
    shipped_at: dt.datetime
    out_for_delivery_at: dt.datetime
    delivered_at: dt.datetime


# Research D5's base window. Jitter is added on top and is bounded so the result always stays
# inside the 24–96 hour range the database CHECK constraint enforces.
_BASE_SHIP_HOURS = 6
_BASE_OUT_FOR_DELIVERY_HOURS = 54
_BASE_DELIVERED_HOURS = 60
_SHIP_JITTER_MINUTES = 120
_DELIVERY_JITTER_MINUTES = 360


def _jitter(order_id: uuid.UUID, salt: str, modulo: int) -> int:
    """Deterministic minutes derived from the order id (Principle III).

    Hashing rather than `random` because the same order must always produce the same timeline,
    and an unseeded RNG would break that outright.
    """
    digest = hashlib.sha256(f"{order_id}:{salt}".encode()).hexdigest()
    return int(digest[:8], 16) % modulo


def delivery_timeline(order_id: uuid.UUID, now: dt.datetime) -> Timeline:
    """All four stages, assigned once (FR-033).

    Ordering holds for every possible jitter: shipping lands 6–8h out, the van 54–60h out, and
    delivery 60–66h out, so the stages cannot cross and the window cannot leave its bounds.
    """
    ship_jitter = dt.timedelta(minutes=_jitter(order_id, "ship", _SHIP_JITTER_MINUTES))
    delivery_jitter = dt.timedelta(minutes=_jitter(order_id, "deliver", _DELIVERY_JITTER_MINUTES))

    return Timeline(
        processing_at=now,
        shipped_at=now + dt.timedelta(hours=_BASE_SHIP_HOURS) + ship_jitter,
        out_for_delivery_at=(
            now + dt.timedelta(hours=_BASE_OUT_FOR_DELIVERY_HOURS) + delivery_jitter
        ),
        delivered_at=now + dt.timedelta(hours=_BASE_DELIVERED_HOURS) + delivery_jitter,
    )


def current_stage_at(timeline: Timeline, now: dt.datetime) -> str:
    """The present stage, from stored timestamps and the clock alone (FR-035).

    Checked from the latest boundary backwards, so a clock *ahead* of the timeline reports
    `delivered` and a clock *behind* it reports `processing`. Neither can produce a stage that
    does not exist, which is what makes a wrong device clock a cosmetic problem rather than a
    crash.

    A boundary belongs to the stage it opens: at exactly `shipped_at` the order is shipped.
    """
    if now >= timeline.delivered_at:
        return "delivered"
    if now >= timeline.out_for_delivery_at:
        return "out_for_delivery"
    if now >= timeline.shipped_at:
        return "shipped"
    return "processing"
