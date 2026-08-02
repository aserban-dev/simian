"""US1 — browse and discover the catalogue, against a real PostgreSQL.

This is the executable form of User Story 1's Independent Test. The unit suite asserts the SQL
*says* the right thing; these assert Postgres *returns* the right rows — `tsvector` ranking,
keyset paging under concurrent writes, and the recursive category CTE all behave differently
from how the compiled text reads.

Covers T040 (paging stability), T041 (search incl. hostile input), T042 (filters),
T043 (sorts), T044 (visibility).
"""

from __future__ import annotations

import datetime as dt
import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from dupermarket_api.models import Category, Product, Review
from dupermarket_api.schemas.catalogue import SortOrder
from dupermarket_api.services import catalogue
from dupermarket_api.services.catalogue import ProductQuery

pytestmark = pytest.mark.integration

NOW = dt.datetime(2026, 8, 2, 12, tzinfo=dt.UTC)


def add_category(session: Session, slug: str, parent: Category | None = None) -> Category:
    category = Category(
        slug=slug,
        name={"en": slug.replace("-", " ").title()},
        sort_order=0,
        parent_id=parent.id if parent else None,
    )
    session.add(category)
    session.flush()
    return category


def add_product(
    session: Session,
    category: Category,
    *,
    title: str = "Thing",
    description: str = "A thing you can buy",
    price: int = 1000,
    rating: float = 4.0,
    rating_count: int = 5,
    created_offset_hours: int = 0,
    withdrawn: bool = False,
    stock: str = "in_stock",
) -> Product:
    product = Product(
        sku=f"SKU-{uuid.uuid4().hex[:8]}",
        category_id=category.id,
        title={"en": title},
        description={"en": description},
        base_price_minor=price,
        base_currency="EUR",
        rating_average=rating,
        rating_count=rating_count,
        stock_status=stock,
        created_at=NOW + dt.timedelta(hours=created_offset_hours),
        withdrawn_at=NOW if withdrawn else None,
    )
    session.add(product)
    session.flush()
    return product


def ids(products: object) -> list[str]:
    return [str(p.id) for p in products]  # type: ignore[union-attr]


class TestVisibility:
    """T044."""

    def test_withdrawn_products_never_appear(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        visible = add_product(db_session, category, title="Visible")
        add_product(db_session, category, title="Gone", withdrawn=True)

        rows, _ = catalogue.list_products(db_session, ProductQuery(category_slug="shoes"))
        assert ids(rows) == [str(visible.id)]

    def test_out_of_stock_products_do_appear(self, db_session: Session) -> None:
        """FR-078: browsable and labelled, unlike withdrawn ones."""
        category = add_category(db_session, "shoes")
        add_product(db_session, category, title="Sold out", stock="out_of_stock")

        rows, _ = catalogue.list_products(db_session, ProductQuery(category_slug="shoes"))
        assert len(rows) == 1
        assert rows[0].stock_status == "out_of_stock"


class TestSearch:
    """T041 / FR-003."""

    def test_a_description_only_match_is_found(self, db_session: Session) -> None:
        """US1 scenario 5: matching words in the description, not the title."""
        category = add_category(db_session, "shoes")
        target = add_product(
            db_session, category, title="Model 42", description="waterproof hiking boot"
        )
        add_product(db_session, category, title="Sandal", description="summer footwear")

        rows, _ = catalogue.list_products(db_session, ProductQuery(q="waterproof"))
        assert ids(rows) == [str(target.id)]

    def test_a_title_match_outranks_a_description_match(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        in_title = add_product(db_session, category, title="Waterproof Boot", description="x")
        in_description = add_product(db_session, category, title="Boot", description="waterproof")

        rows, _ = catalogue.list_products(
            db_session, ProductQuery(q="waterproof", sort=SortOrder.relevance)
        )
        assert ids(rows) == [str(in_title.id), str(in_description.id)]

    @pytest.mark.parametrize(
        "term",
        [
            '"',
            "&",
            "|",
            "!",
            ":*",
            "<->",
            "(unbalanced",
            "!!!",
            "...",
            "C++",
            "a" * 200,
            "shoes & (boots",
            "-",
        ],
    )
    def test_hostile_input_returns_a_result_set_rather_than_raising(
        self, db_session: Session, term: str
    ) -> None:
        """FR-003 / finding C2: `to_tsquery` would raise here, surfacing as a 500."""
        category = add_category(db_session, "shoes")
        add_product(db_session, category, title="Boot")

        rows, _ = catalogue.list_products(db_session, ProductQuery(q=term))
        assert isinstance(rows, list)

    def test_a_quoted_phrase_is_treated_as_a_phrase(self, db_session: Session) -> None:
        # websearch_to_tsquery supports this; users expect it and it costs nothing.
        category = add_category(db_session, "shoes")
        add_product(db_session, category, title="Red Running Shoe")
        add_product(db_session, category, title="Running Red Sock")

        rows, _ = catalogue.list_products(db_session, ProductQuery(q='"red running"'))
        assert len(rows) == 1


class TestFilters:
    """T042 / FR-004."""

    def test_price_bounds_are_inclusive(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        add_product(db_session, category, title="Cheap", price=500)
        mid = add_product(db_session, category, title="Mid", price=1500)
        add_product(db_session, category, title="Dear", price=5000)

        rows, _ = catalogue.list_products(
            db_session, ProductQuery(min_price_minor=1500, max_price_minor=1500)
        )
        assert ids(rows) == [str(mid.id)]

    def test_minimum_rating_filters(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        good = add_product(db_session, category, title="Good", rating=4.5)
        add_product(db_session, category, title="Poor", rating=2.0)

        rows, _ = catalogue.list_products(db_session, ProductQuery(min_rating=4.0))
        assert ids(rows) == [str(good.id)]

    def test_filters_combine(self, db_session: Session) -> None:
        """US1 scenario 3: every product shown satisfies both constraints."""
        category = add_category(db_session, "shoes")
        match = add_product(db_session, category, title="Match", price=1000, rating=4.5)
        add_product(db_session, category, title="TooDear", price=9000, rating=4.5)
        add_product(db_session, category, title="TooPoor", price=1000, rating=1.0)

        rows, _ = catalogue.list_products(
            db_session, ProductQuery(max_price_minor=2000, min_rating=4.0)
        )
        assert ids(rows) == [str(match.id)]

    def test_a_category_filter_includes_descendants(self, db_session: Session) -> None:
        """FR-001 + FR-004: the recursive CTE, which no compiled-SQL test can prove works."""
        clothing = add_category(db_session, "clothing")
        shirts = add_category(db_session, "shirts", parent=clothing)
        formal = add_category(db_session, "formal-shirts", parent=shirts)

        add_product(db_session, clothing, title="Generic garment")
        add_product(db_session, shirts, title="Tee")
        add_product(db_session, formal, title="Oxford")

        rows, _ = catalogue.list_products(db_session, ProductQuery(category_slug="clothing"))
        assert len(rows) == 3, "a category page shows everything beneath it, at any depth"

        rows, _ = catalogue.list_products(db_session, ProductQuery(category_slug="shirts"))
        assert len(rows) == 2, "including grandchildren, excluding the parent"


class TestSorting:
    """T043 / FR-005."""

    def test_price_ascending_and_descending(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        cheap = add_product(db_session, category, price=100)
        mid = add_product(db_session, category, price=500)
        dear = add_product(db_session, category, price=900)

        asc, _ = catalogue.list_products(db_session, ProductQuery(sort=SortOrder.price_asc))
        assert ids(asc) == [str(cheap.id), str(mid.id), str(dear.id)]

        desc, _ = catalogue.list_products(db_session, ProductQuery(sort=SortOrder.price_desc))
        assert ids(desc) == [str(dear.id), str(mid.id), str(cheap.id)]

    def test_rating_sorts_best_first(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        best = add_product(db_session, category, rating=5.0)
        worst = add_product(db_session, category, rating=1.0)

        rows, _ = catalogue.list_products(db_session, ProductQuery(sort=SortOrder.rating))
        assert ids(rows) == [str(best.id), str(worst.id)]

    def test_newest_sorts_most_recent_first(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        old = add_product(db_session, category, created_offset_hours=-48)
        new = add_product(db_session, category, created_offset_hours=0)

        rows, _ = catalogue.list_products(db_session, ProductQuery(sort=SortOrder.newest))
        assert ids(rows) == [str(new.id), str(old.id)]


class TestKeysetPaging:
    """T040 / FR-002 — the requirement keyset paging exists for."""

    def test_paging_covers_every_product_exactly_once(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        expected = {str(add_product(db_session, category, price=i * 10).id) for i in range(25)}

        seen: list[str] = []
        cursor = None
        for _ in range(10):  # generous bound; the loop breaks when exhausted
            query = ProductQuery(sort=SortOrder.price_asc, cursor=cursor, limit=7)
            rows, has_more = catalogue.list_products(db_session, query)
            seen.extend(ids(rows))
            cursor = catalogue.next_cursor_for(rows, SortOrder.price_asc, has_more)
            if cursor is None:
                break

        assert len(seen) == len(set(seen)), "a product was served twice"
        assert set(seen) == expected, "a product was skipped"

    def test_a_product_inserted_mid_traversal_does_not_shift_the_window(
        self, db_session: Session
    ) -> None:
        """The failure OFFSET produces: an insert shifts the page and drops a row.

        With OFFSET, inserting a cheap product after page 1 pushes everything down by one, so
        the row that was last on page 1 reappears at the top of page 2 — or, inserting an
        expensive one, a row is skipped entirely. Keyset paging is immune because the cursor
        names a position, not a count.
        """
        category = add_category(db_session, "shoes")
        original = {str(add_product(db_session, category, price=i * 100).id) for i in range(10)}

        query = ProductQuery(sort=SortOrder.price_asc, limit=4)
        page1, has_more = catalogue.list_products(db_session, query)
        cursor = catalogue.next_cursor_for(page1, SortOrder.price_asc, has_more)

        # Insert a product that sorts into the page already served.
        add_product(db_session, category, price=50)

        seen = ids(page1)
        for _ in range(10):
            rows, has_more = catalogue.list_products(
                db_session, ProductQuery(sort=SortOrder.price_asc, cursor=cursor, limit=4)
            )
            seen.extend(ids(rows))
            cursor = catalogue.next_cursor_for(rows, SortOrder.price_asc, has_more)
            if cursor is None:
                break

        assert len(seen) == len(set(seen)), "the insert caused a duplicate"
        assert original.issubset(set(seen)), "the insert caused a product to be skipped"

    def test_products_with_identical_sort_keys_still_page_deterministically(
        self, db_session: Session
    ) -> None:
        """The id tiebreaker. Without it, equal prices have no defined order between pages."""
        category = add_category(db_session, "shoes")
        expected = {str(add_product(db_session, category, price=1000).id) for _ in range(12)}

        seen: list[str] = []
        cursor = None
        for _ in range(10):
            rows, has_more = catalogue.list_products(
                db_session, ProductQuery(sort=SortOrder.price_asc, cursor=cursor, limit=5)
            )
            seen.extend(ids(rows))
            cursor = catalogue.next_cursor_for(rows, SortOrder.price_asc, has_more)
            if cursor is None:
                break

        assert len(seen) == len(set(seen))
        assert set(seen) == expected

    def test_the_last_page_reports_no_cursor(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        for _ in range(3):
            add_product(db_session, category)

        rows, has_more = catalogue.list_products(db_session, ProductQuery(limit=20))
        assert has_more is False
        assert catalogue.next_cursor_for(rows, SortOrder.newest, has_more) is None


class TestCategoryTree:
    """FR-001."""

    def test_the_tree_is_returned_nested(self, db_session: Session) -> None:
        clothing = add_category(db_session, "clothing")
        add_category(db_session, "shirts", parent=clothing)
        add_category(db_session, "shoes")

        roots = catalogue.category_tree(db_session)
        by_slug = {c.slug: c for c in roots}

        assert set(by_slug) == {"clothing", "shoes"}
        assert [c.slug for c in by_slug["clothing"].children] == ["shirts"]
        assert by_slug["shoes"].children == []


class TestRatingRecomputation:
    """FR-009."""

    def test_the_average_and_count_reflect_the_review_rows(self, db_session: Session) -> None:
        category = add_category(db_session, "shoes")
        product = add_product(db_session, category, rating=0.0, rating_count=0)

        for rating in (5, 4, 3):
            db_session.add(Review(product_id=product.id, user_id=None, rating=rating))
        db_session.flush()

        catalogue.recompute_rating(db_session, product.id)
        db_session.expire_all()

        refreshed = db_session.get(Product, product.id)
        assert refreshed is not None
        assert float(refreshed.rating_average) == 4.0
        assert refreshed.rating_count == 3

    def test_recomputation_is_idempotent(self, db_session: Session) -> None:
        """Principle III: running it twice must not drift, which an increment would."""
        category = add_category(db_session, "shoes")
        product = add_product(db_session, category, rating=0.0, rating_count=0)
        db_session.add(Review(product_id=product.id, user_id=None, rating=5))
        db_session.flush()

        catalogue.recompute_rating(db_session, product.id)
        catalogue.recompute_rating(db_session, product.id)
        db_session.expire_all()

        refreshed = db_session.get(Product, product.id)
        assert refreshed is not None
        assert refreshed.rating_count == 1


class TestSearchIndexIsUsed:
    def test_the_gin_index_backs_the_search_predicate(self, db_session: Session) -> None:
        """SC-002: search under a second at scale depends on this index being chosen."""
        category = add_category(db_session, "shoes")
        for i in range(60):
            add_product(db_session, category, title=f"Boot {i}", description="waterproof")
        db_session.flush()
        db_session.execute(text("ANALYZE product"))

        plan = "\n".join(
            row[0]
            for row in db_session.execute(
                text(
                    "EXPLAIN SELECT id FROM product "
                    "WHERE search_vector @@ websearch_to_tsquery('simple', 'waterproof')"
                )
            ).all()
        )
        # On a small table Postgres may still prefer a seq scan; what must be true is that the
        # index exists and is usable, which is asserted by forcing the planner's hand.
        db_session.execute(text("SET LOCAL enable_seqscan = off"))
        forced = "\n".join(
            row[0]
            for row in db_session.execute(
                text(
                    "EXPLAIN SELECT id FROM product "
                    "WHERE search_vector @@ websearch_to_tsquery('simple', 'waterproof')"
                )
            ).all()
        )
        assert "ix_product_search" in forced, f"GIN index not usable. Plan was:\n{plan}\n{forced}"
