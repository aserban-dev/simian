"""Schema assertions that do not need a database.

The DDL is compiled for the PostgreSQL dialect and inspected. This does not replace the
integration tests — a compiled `CREATE TABLE` proves the constraint ships, not that Postgres
enforces it the way we think. It does catch the failure these constraints are actually prone
to: someone removing one during a refactor and nobody noticing until production.

Integration coverage for the same rules is T029 (write-once trigger) and T111 (single default
address), which need a live Postgres and are BLOCKED without one.
"""

from __future__ import annotations

import pytest
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateIndex, CreateTable

from dupermarket_api.models import WRITE_ONCE_TRIGGER_SQL, Base

pytestmark = pytest.mark.unit

DIALECT = postgresql.dialect()


def ddl_for(table_name: str) -> str:
    table = Base.metadata.tables[table_name]
    parts = [str(CreateTable(table).compile(dialect=DIALECT))]
    parts.extend(str(CreateIndex(ix).compile(dialect=DIALECT)) for ix in table.indexes)
    return "\n".join(parts)


class TestSimulationBoundary:
    def test_no_table_has_a_payment_column(self) -> None:
        """SC-013 / Principle I: the schema cannot hold a payment instrument."""
        forbidden = (
            "card_number",
            "cardnumber",
            "cvv",
            "cvc",
            "security_code",
            "expiry",
            "cardholder",
            "pan",
        )
        offenders = [
            f"{table}.{column}"
            for table, t in Base.metadata.tables.items()
            # noqa justified: SQLAlchemy's ColumnCollection iterates Column objects,
            # while .keys() yields the names this comprehension needs. Ruff's SIM118
            # autofix assumes dict semantics and silently changes the type.
            for column in t.columns.keys()  # noqa: SIM118
            if any(f in column.lower() for f in forbidden)
        ]
        assert not offenders, f"payment-shaped columns in the schema: {offenders}"

    def test_demo_card_choice_is_not_persisted(self) -> None:
        """The chosen demo card has no effect on a stored order, so it is not stored."""
        assert "demo_card_id" not in Base.metadata.tables["order"].columns


class TestSnapshots:
    def test_order_item_snapshots_title_price_and_image(self) -> None:
        """FR-027: a catalogue change must not rewrite what a user sees they paid."""
        columns = Base.metadata.tables["order_item"].columns.keys()
        for required in ("title_snapshot", "image_snapshot", "unit_price_minor"):
            assert required in columns

    def test_order_snapshots_the_delivery_address(self) -> None:
        """FR-044: deleting an address must not alter an existing order."""
        assert "address_snapshot" in Base.metadata.tables["order"].columns


class TestDeliveryTimeline:
    def test_all_four_stage_columns_are_not_null(self) -> None:
        """FR-033: all four are assigned at creation, so none may be nullable."""
        order = Base.metadata.tables["order"]
        for stage in ("processing_at", "shipped_at", "out_for_delivery_at", "delivered_at"):
            assert order.columns[stage].nullable is False, stage

    def test_timeline_is_constrained_to_be_monotonic(self) -> None:
        """FR-035: stage derivation is only total if the timeline cannot go backwards."""
        assert "timeline_monotonic" in ddl_for("order")

    def test_delivery_window_bounds_are_enforced_in_the_schema(self) -> None:
        """FR-033 (finding A1): between 24 and 96 hours, as a constraint not a convention."""
        ddl = ddl_for("order")
        assert "delivery_window_bounds" in ddl
        assert "24 hours" in ddl and "96 hours" in ddl

    def test_write_once_trigger_covers_every_immutable_column(self) -> None:
        """FR-034: application code forgets; a trigger does not."""
        for column in (
            "processing_at",
            "shipped_at",
            "out_for_delivery_at",
            "delivered_at",
            "origin_lat",
            "origin_lng",
            "destination_lat",
            "destination_lng",
        ):
            assert column in WRITE_ONCE_TRIGGER_SQL, f"{column} is not protected by the trigger"
        assert "BEFORE UPDATE" in WRITE_ONCE_TRIGGER_SQL


class TestUniquenessInvariants:
    def test_exactly_one_default_address_is_a_partial_unique_index(self) -> None:
        """FR-041: a database invariant, not application etiquette."""
        ddl = ddl_for("address")
        assert "uq_address_one_default" in ddl
        assert "UNIQUE INDEX" in ddl
        assert "WHERE is_default AND deleted_at IS NULL" in ddl

    def test_one_review_per_user_per_product_excludes_seeded_reviews(self) -> None:
        """FR-008, and FR-017's anonymised reviews must not collide with each other."""
        ddl = ddl_for("review")
        assert "uq_review_one_per_user_product" in ddl
        assert "WHERE user_id IS NOT NULL" in ddl

    def test_push_token_is_unique_across_all_users(self) -> None:
        """A shared device must not keep pushing the previous user's orders."""
        assert Base.metadata.tables["device"].columns["fcm_token"].unique is True

    def test_wishlist_add_is_idempotent_by_primary_key(self) -> None:
        """FR-045: adding twice yields the same state, by construction."""
        pk = Base.metadata.tables["wishlist_item"].primary_key.columns.keys()
        assert set(pk) == {"user_id", "product_id"}


class TestSearchAndPaging:
    def test_search_vector_is_generated_and_gin_indexed(self) -> None:
        """FR-003, SC-002: ranking and speed both depend on this index existing."""
        ddl = ddl_for("product")
        assert "search_vector" in ddl
        assert "USING gin" in ddl

    def test_title_outranks_description_in_the_search_vector(self) -> None:
        """FR-003: description-only matches must appear, but rank below title matches."""
        ddl = ddl_for("product")
        assert "'A'" in ddl and "'B'" in ddl

    def test_keyset_cursor_indexes_include_the_id_tiebreaker(self) -> None:
        """FR-002 / research D3: without the id, paging is not deterministic."""
        ddl = ddl_for("product")
        for index_name in (
            "ix_product_category_price",
            "ix_product_category_rating",
            "ix_product_created",
        ):
            assert index_name in ddl
        assert "base_price_minor, id" in ddl


class TestMoney:
    def test_money_columns_are_integers_not_floats(self) -> None:
        """Research D4: binary floating point cannot represent 0.99."""
        money_columns = [
            (table, column, str(t.columns[column].type))
            for table, t in Base.metadata.tables.items()
            # noqa justified: SQLAlchemy's ColumnCollection iterates Column objects,
            # while .keys() yields the names this comprehension needs. Ruff's SIM118
            # autofix assumes dict semantics and silently changes the type.
            for column in t.columns.keys()  # noqa: SIM118
            if column.endswith("_minor")
        ]
        assert money_columns, "expected minor-unit money columns"
        for table, column, type_name in money_columns:
            assert "BIGINT" in type_name.upper(), f"{table}.{column} is {type_name}"


class TestCategoryTree:
    def test_categories_nest_via_a_self_referential_parent(self) -> None:
        """FR-001: subcategories to arbitrary depth, so the parent must be self-referential."""
        category = Base.metadata.tables["category"]
        parent = category.columns["parent_id"]

        assert parent.nullable is True, "a top-level category has no parent"
        fk = next(iter(parent.foreign_keys))
        assert fk.column.table.name == "category"
        # RESTRICT rather than CASCADE: deleting a parent must not silently take a whole
        # subtree of products' categories with it.
        assert fk.ondelete == "RESTRICT"

    def test_the_grid_and_drilldown_are_served_by_one_index(self) -> None:
        """FR-001: category grid and every drill-down are the same query shape."""
        assert "ix_category_parent_sort" in ddl_for("category")


class TestSeedIdempotency:
    def test_images_carry_a_content_hash_and_a_source_key(self) -> None:
        """FR-072: re-running must not re-upload an unchanged image.

        Keying on "does the object exist" cannot tell an unchanged image from one that was
        uploaded broken last time; a content hash can.
        """
        image = Base.metadata.tables["product_image"].columns
        assert "content_sha256" in image
        assert image["content_sha256"].nullable is False

    def test_products_and_categories_key_on_their_source_id(self) -> None:
        """FR-072: idempotency needs a stable identifier from the source system."""
        assert Base.metadata.tables["product"].columns["source_id"].unique is True
        assert Base.metadata.tables["category"].columns["source_key"].unique is True


class TestSoftDeletion:
    def test_products_are_withdrawn_not_deleted(self) -> None:
        """FR-021/FR-027: hard deletion would orphan or cascade order history."""
        assert "withdrawn_at" in Base.metadata.tables["product"].columns

    def test_order_item_restricts_product_deletion(self) -> None:
        order_item = Base.metadata.tables["order_item"]
        fk = next(fk for fk in order_item.foreign_keys if fk.column.table.name == "product")
        assert fk.ondelete == "RESTRICT"

    def test_addresses_are_soft_deleted(self) -> None:
        """FR-044."""
        assert "deleted_at" in Base.metadata.tables["address"].columns
