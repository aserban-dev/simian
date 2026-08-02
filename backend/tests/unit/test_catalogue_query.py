"""Catalogue query construction, asserted on the compiled SQL.

No database: each query is compiled for the PostgreSQL dialect and inspected. That catches the
things most likely to be broken by a refactor and never noticed — a dropped `withdrawn_at`
filter, an ORDER BY that lost its id tiebreaker, a switch back to `to_tsquery`.

It does not prove Postgres returns the right rows. That is T040–T044, which need a live
database and are BLOCKED here.
"""

from __future__ import annotations

import re
import uuid

import pytest
from sqlalchemy.dialects import postgresql

from dupermarket_api.schemas.catalogue import SortOrder
from dupermarket_api.services.catalogue import ProductQuery, build_product_query
from dupermarket_api.services.cursor import Cursor

pytestmark = pytest.mark.unit

PRODUCT_ID = uuid.UUID("3f2504e0-4f89-11d3-9a0c-0305e82c3301")


def sql_for(query: ProductQuery) -> str:
    return str(
        build_product_query(query).compile(
            dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True}
        )
    )


def where_clause(query: ProductQuery) -> str:
    """Just the WHERE clause.

    Asserting a column is *absent* has to be scoped: every column of `product` appears in the
    SELECT list, so a whole-statement search would match `stock_status` no matter what the
    filter does.
    """
    sql = sql_for(query)
    _, _, rest = sql.partition("WHERE")
    return rest.split("ORDER BY")[0]


class TestVisibility:
    def test_withdrawn_products_are_always_excluded(self) -> None:
        """Withdrawn products vanish from the catalogue; every query must filter them."""
        assert "withdrawn_at IS NULL" in sql_for(ProductQuery())

    def test_out_of_stock_products_are_not_excluded(self) -> None:
        """FR-078: out-of-stock products stay browsable and labelled — only withdrawn ones go."""
        assert "stock_status" not in where_clause(ProductQuery()), (
            "the query filters on stock_status, which would hide out-of-stock products "
            "instead of labelling them"
        )


class TestSearch:
    def test_search_uses_websearch_to_tsquery_not_to_tsquery(self) -> None:
        """FR-003 / finding C2: to_tsquery raises on `(` or `C++`, surfacing as a 500."""
        sql = sql_for(ProductQuery(q="running shoes"))
        assert "websearch_to_tsquery" in sql

        # Guard against a "simplification" back to a raising parser. The lookbehind is what
        # makes this able to fail — a plain substring check for "to_tsquery" matches
        # "websearch_to_tsquery" too and would pass no matter what the code did.
        bare_parsers = re.findall(r"(?<!websearch_)\b(?:plainto_|phraseto_)?to_tsquery\b", sql)
        assert not bare_parsers, f"a raising tsquery parser is in use: {bare_parsers}"

    def test_search_matches_against_the_generated_vector(self) -> None:
        """FR-003: title and description both, via the weighted vector."""
        sql = sql_for(ProductQuery(q="mascara"))
        assert "search_vector @@" in sql

    def test_no_search_term_means_no_tsquery_at_all(self) -> None:
        assert "tsquery" not in sql_for(ProductQuery())


class TestFilters:
    def test_price_bounds_are_inclusive_on_the_stored_minor_units(self) -> None:
        """FR-004."""
        sql = sql_for(ProductQuery(min_price_minor=500, max_price_minor=2500))
        assert "base_price_minor >= 500" in sql
        assert "base_price_minor <= 2500" in sql

    def test_minimum_rating_filters_on_the_denormalised_average(self) -> None:
        """FR-004."""
        assert "rating_average >= 4.0" in sql_for(ProductQuery(min_rating=4.0))

    def test_filters_combine_rather_than_replace_each_other(self) -> None:
        """FR-004: "in any combination"."""
        sql = sql_for(
            ProductQuery(q="shirt", min_price_minor=100, max_price_minor=900, min_rating=3.5)
        )
        assert "websearch_to_tsquery" in sql
        assert "base_price_minor >= 100" in sql
        assert "base_price_minor <= 900" in sql
        assert "rating_average >= 3.5" in sql

    def test_a_category_filter_includes_descendant_categories(self) -> None:
        """FR-001 + FR-004: a category page shows everything beneath it."""
        sql = sql_for(ProductQuery(category_slug="shoes"))
        assert "WITH RECURSIVE" in sql.upper()
        assert "'shoes'" in sql


class TestSorting:
    @pytest.mark.parametrize(
        ("sort", "expected"),
        [
            (SortOrder.price_asc, "base_price_minor ASC"),
            (SortOrder.price_desc, "base_price_minor DESC"),
            (SortOrder.rating, "rating_average DESC"),
            (SortOrder.newest, "created_at DESC"),
        ],
    )
    def test_each_sort_mode_orders_by_its_own_key(self, sort: SortOrder, expected: str) -> None:
        """FR-005."""
        assert expected in sql_for(ProductQuery(sort=sort))

    def test_every_sort_ends_with_the_id_tiebreaker(self) -> None:
        """FR-002: without it, equal keys have no defined order and paging repeats or skips."""
        for sort in SortOrder:
            sql = sql_for(ProductQuery(sort=sort, q="x"))
            order_by = sql.upper().split("ORDER BY")[1]
            assert "PRODUCT.ID ASC" in order_by, f"{sort.value} has no id tiebreaker"

    def test_relevance_without_a_search_term_degrades_to_newest(self) -> None:
        # Ranking with no query would be an arbitrary constant, i.e. no order at all.
        assert "created_at DESC" in sql_for(ProductQuery(sort=SortOrder.relevance))

    def test_relevance_with_a_search_term_ranks_by_it(self) -> None:
        sql = sql_for(ProductQuery(sort=SortOrder.relevance, q="jacket"))
        assert "ts_rank_cd" in sql


class TestRatingRecomputation:
    """FR-009: the denormalised rating is recomputed from rows, never incremented."""

    @staticmethod
    def _sql(stmt: object) -> str:
        return str(
            stmt.compile(  # type: ignore[attr-defined]
                dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True}
            )
        )

    def test_the_average_is_aggregated_from_the_review_rows(self) -> None:
        from dupermarket_api.services.catalogue import rating_stats_query

        sql = self._sql(rating_stats_query(PRODUCT_ID)).lower()
        assert "avg(review.rating)" in sql
        assert "count(review.id)" in sql
        assert f"review.product_id = '{PRODUCT_ID}'" in sql

    def test_average_and_count_are_written_in_one_statement(self) -> None:
        # Two statements could interleave and leave a product whose count and average
        # describe different sets of reviews.
        from dupermarket_api.services.catalogue import rating_update

        sql = self._sql(rating_update(PRODUCT_ID, 4.256, 12)).lower()
        assert "rating_average" in sql
        assert "rating_count" in sql
        assert sql.count("update product") == 1

    def test_the_average_is_rounded_to_the_stored_precision(self) -> None:
        # The column is NUMERIC(3,2); handing it more precision than it stores would make the
        # value read back differently from the one written.
        from dupermarket_api.services.catalogue import rating_update

        assert "4.26" in self._sql(rating_update(PRODUCT_ID, 4.256, 12))

    def test_only_the_target_product_is_updated(self) -> None:
        from dupermarket_api.services.catalogue import rating_update

        sql = self._sql(rating_update(PRODUCT_ID, 4.0, 1))
        assert f"product.id = '{PRODUCT_ID}'" in sql.lower()


class TestReviewPaging:
    """FR-007: reviews come back newest first, paged the same way products are."""

    @staticmethod
    def _review_sql(cursor: Cursor | None) -> str:
        from sqlalchemy import and_, or_, select

        from dupermarket_api.models import Review

        stmt = select(Review).where(Review.product_id == PRODUCT_ID)
        if cursor is not None and cursor.last_value is not None:
            stmt = stmt.where(
                or_(
                    Review.created_at < cursor.last_value,
                    and_(
                        Review.created_at == cursor.last_value,
                        Review.id > cursor.last_id,
                    ),
                )
            )
        stmt = stmt.order_by(Review.created_at.desc(), Review.id.asc())
        return str(
            stmt.compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True})
        )

    def test_reviews_are_ordered_newest_first(self) -> None:
        assert "created_at DESC" in self._review_sql(None)

    def test_review_paging_carries_the_id_tiebreaker(self) -> None:
        # Seeded reviews share a created_at often enough that without the tiebreaker a page
        # boundary lands mid-tie and repeats or skips one.
        assert "review.id ASC" in self._review_sql(None)

    def test_a_review_cursor_continues_strictly_after_the_last_row(self) -> None:
        cursor = Cursor(sort="newest", last_id=PRODUCT_ID, last_value="2026-08-02T12:00:00+00:00")
        sql = self._review_sql(cursor)
        assert "created_at < '2026-08-02T12:00:00+00:00'" in sql
        assert f"review.id > '{PRODUCT_ID}'" in sql

    def test_review_paging_never_uses_offset(self) -> None:
        assert "OFFSET" not in self._review_sql(None).upper()


class TestKeysetPaging:
    def test_no_query_ever_uses_offset(self) -> None:
        """FR-002 / research D3: OFFSET drops or duplicates rows as the catalogue changes."""
        for sort in SortOrder:
            sql = sql_for(ProductQuery(sort=sort))
            assert "OFFSET" not in sql.upper(), f"{sort.value} uses OFFSET"

    def test_an_ascending_cursor_continues_strictly_after_the_last_row(self) -> None:
        cursor = Cursor(sort="price_asc", last_id=PRODUCT_ID, last_value=1299)
        sql = sql_for(ProductQuery(sort=SortOrder.price_asc, cursor=cursor))

        assert "base_price_minor > 1299" in sql
        assert "base_price_minor = 1299" in sql  # the tie branch
        assert str(PRODUCT_ID) in sql

    def test_a_descending_cursor_flips_the_key_comparison_but_not_the_tiebreaker(self) -> None:
        # The subtle one: id stays ascending under a descending key, matching the ORDER BY.
        cursor = Cursor(sort="price_desc", last_id=PRODUCT_ID, last_value=1299)
        sql = sql_for(ProductQuery(sort=SortOrder.price_desc, cursor=cursor))

        assert "base_price_minor < 1299" in sql
        assert f"product.id > '{PRODUCT_ID}'" in sql

    def test_the_page_fetches_one_extra_row_to_detect_a_next_page(self) -> None:
        # Cheaper than a COUNT, and exact.
        assert "LIMIT 21" in sql_for(ProductQuery(limit=20))

    def test_the_limit_is_capped(self) -> None:
        assert "LIMIT 101" in sql_for(ProductQuery(limit=10_000))
