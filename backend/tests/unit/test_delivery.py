"""Stage derivation, warehouse assignment and window generation (T090, T092, T093).

FR-035 makes the current stage a *pure function* of four stored timestamps and the clock. That
is what removes the background job, and it is also what makes it testable at every boundary
rather than "after waiting a while".

Research D5 adds determinism (Principle III): the same order id must always produce the same
window, or the simulation stops being reproducible and SC-008 fails.
"""

from __future__ import annotations

import datetime as dt
import uuid

import pytest

from dupermarket_api.services.delivery import (
    WAREHOUSES,
    Timeline,
    current_stage_at,
    delivery_timeline,
    great_circle_km,
    nearest_warehouse,
)

pytestmark = pytest.mark.unit

NOW = dt.datetime(2026, 8, 2, 12, tzinfo=dt.UTC)


def timeline(
    processing: int = 0,
    shipped: int = 6,
    out_for_delivery: int = 54,
    delivered: int = 60,
) -> Timeline:
    return Timeline(
        processing_at=NOW + dt.timedelta(hours=processing),
        shipped_at=NOW + dt.timedelta(hours=shipped),
        out_for_delivery_at=NOW + dt.timedelta(hours=out_for_delivery),
        delivered_at=NOW + dt.timedelta(hours=delivered),
    )


class TestStageAtEveryBoundary:
    """T090 / FR-035 — every boundary, and both sides of each one."""

    def test_before_processing_the_order_is_still_processing(self) -> None:
        # A clock behind the server's must not produce a stage that does not exist.
        assert current_stage_at(timeline(), NOW - dt.timedelta(hours=1)) == "processing"

    def test_exactly_at_processing(self) -> None:
        assert current_stage_at(timeline(), NOW) == "processing"

    def test_between_processing_and_shipped(self) -> None:
        assert current_stage_at(timeline(), NOW + dt.timedelta(hours=3)) == "processing"

    def test_exactly_at_shipped(self) -> None:
        """The boundary belongs to the stage it opens, not the one it closes."""
        assert current_stage_at(timeline(), NOW + dt.timedelta(hours=6)) == "shipped"

    def test_between_shipped_and_out_for_delivery(self) -> None:
        assert current_stage_at(timeline(), NOW + dt.timedelta(hours=30)) == "shipped"

    def test_exactly_at_out_for_delivery(self) -> None:
        assert current_stage_at(timeline(), NOW + dt.timedelta(hours=54)) == "out_for_delivery"

    def test_between_out_for_delivery_and_delivered(self) -> None:
        assert current_stage_at(timeline(), NOW + dt.timedelta(hours=57)) == "out_for_delivery"

    def test_exactly_at_delivered(self) -> None:
        assert current_stage_at(timeline(), NOW + dt.timedelta(hours=60)) == "delivered"

    def test_after_delivered_it_stays_delivered(self) -> None:
        assert current_stage_at(timeline(), NOW + dt.timedelta(days=365)) == "delivered"

    def test_a_microsecond_before_a_boundary_is_the_earlier_stage(self) -> None:
        just_before = NOW + dt.timedelta(hours=6) - dt.timedelta(microseconds=1)
        assert current_stage_at(timeline(), just_before) == "processing"

    def test_derivation_reads_nothing_but_its_arguments(self) -> None:
        """FR-035: no background job means calling twice at the same instant cannot differ."""
        at = NOW + dt.timedelta(hours=30)
        assert current_stage_at(timeline(), at) == current_stage_at(timeline(), at)

    def test_a_collapsed_timeline_still_yields_a_stage(self) -> None:
        # Degenerate but representable: every stage at the same instant. Must not fall through.
        collapsed = timeline(shipped=0, out_for_delivery=0, delivered=0)
        assert current_stage_at(collapsed, NOW) == "delivered"


class TestWarehouseAssignment:
    """T092 / research D5 — nearest by great-circle, and stable for a destination."""

    def test_a_bucharest_destination_gets_the_bucharest_hub(self) -> None:
        assert nearest_warehouse(44.43, 26.10).name == "Bucharest Hub"

    def test_a_madrid_destination_gets_the_madrid_hub(self) -> None:
        assert nearest_warehouse(40.41, -3.70).name == "Madrid Hub"

    def test_a_dublin_destination_gets_the_dublin_hub(self) -> None:
        assert nearest_warehouse(53.34, -6.26).name == "Dublin Hub"

    def test_assignment_is_stable_for_a_given_destination(self) -> None:
        first = nearest_warehouse(52.37, 4.90)
        for _ in range(5):
            assert nearest_warehouse(52.37, 4.90).name == first.name

    def test_every_destination_resolves_to_a_warehouse(self) -> None:
        for lat in (-60.0, -30.0, 0.0, 30.0, 60.0):
            for lng in (-170.0, -60.0, 0.0, 60.0, 170.0):
                assert nearest_warehouse(lat, lng) in WAREHOUSES

    def test_the_chosen_warehouse_is_genuinely_the_closest(self) -> None:
        destination = (48.85, 2.35)
        chosen = nearest_warehouse(*destination)
        closest = min(
            WAREHOUSES,
            key=lambda w: great_circle_km(destination[0], destination[1], w.lat, w.lng),
        )
        assert chosen.name == closest.name

    def test_distance_is_symmetric(self) -> None:
        assert great_circle_km(44.43, 26.10, 52.23, 21.01) == pytest.approx(
            great_circle_km(52.23, 21.01, 44.43, 26.10)
        )

    def test_distance_to_itself_is_zero(self) -> None:
        assert great_circle_km(44.43, 26.10, 44.43, 26.10) == pytest.approx(0, abs=1e-9)


class TestTheGeneratedWindow:
    """T092 / FR-033 — monotonic, and inside the bounds the database enforces."""

    def test_the_four_stages_are_non_decreasing(self) -> None:
        for warehouse in WAREHOUSES:
            line = delivery_timeline(uuid.uuid5(uuid.NAMESPACE_DNS, warehouse.name), NOW)
            assert line.processing_at <= line.shipped_at
            assert line.shipped_at <= line.out_for_delivery_at
            assert line.out_for_delivery_at <= line.delivered_at

    def test_the_window_is_between_24_and_96_hours_for_every_warehouse(self) -> None:
        """The CHECK constraint rejects anything outside this; generation must never try."""
        for warehouse in WAREHOUSES:
            line = delivery_timeline(uuid.uuid5(uuid.NAMESPACE_DNS, warehouse.name), NOW)
            hours = (line.delivered_at - line.processing_at).total_seconds() / 3600
            assert 24 <= hours <= 96, f"{warehouse.name}: {hours}h"

    def test_the_bounds_hold_across_many_ids(self) -> None:
        # The jitter is id-derived, so coverage means many ids rather than many clocks.
        for index in range(200):
            line = delivery_timeline(uuid.uuid5(uuid.NAMESPACE_DNS, f"order-{index}"), NOW)
            hours = (line.delivered_at - line.processing_at).total_seconds() / 3600
            assert 24 <= hours <= 96
            assert line.processing_at <= line.shipped_at <= line.out_for_delivery_at
            assert line.out_for_delivery_at <= line.delivered_at

    def test_processing_starts_at_the_moment_of_creation(self) -> None:
        assert delivery_timeline(uuid.uuid4(), NOW).processing_at == NOW


class TestDeterminism:
    """T093 / Principle III, SC-008 — the same order always yields the same timeline."""

    def test_repeated_generation_is_identical(self) -> None:
        order_id = uuid.UUID("11111111-1111-1111-1111-111111111111")

        first = delivery_timeline(order_id, NOW)
        second = delivery_timeline(order_id, NOW)

        assert first == second

    def test_it_is_identical_across_many_repeats(self) -> None:
        order_id = uuid.UUID("22222222-2222-2222-2222-222222222222")
        generated = {delivery_timeline(order_id, NOW) for _ in range(20)}

        assert len(generated) == 1

    def test_different_orders_at_the_same_instant_differ(self) -> None:
        """Research D5's other half: simultaneous orders must not look cloned."""
        stamps = {
            delivery_timeline(uuid.uuid5(uuid.NAMESPACE_DNS, f"o{i}"), NOW).delivered_at
            for i in range(20)
        }

        assert len(stamps) > 1

    def test_the_timeline_shifts_with_creation_time_but_keeps_its_shape(self) -> None:
        order_id = uuid.UUID("33333333-3333-3333-3333-333333333333")
        later = NOW + dt.timedelta(days=1)

        first = delivery_timeline(order_id, NOW)
        second = delivery_timeline(order_id, later)

        assert second.processing_at - first.processing_at == dt.timedelta(days=1)
        assert second.delivered_at - first.delivered_at == dt.timedelta(days=1)
