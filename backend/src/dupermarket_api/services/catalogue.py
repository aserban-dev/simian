"""Catalogue queries: tree assembly, search, filter, sort, keyset paging.

Two decisions here carry requirements and are easy to undo by accident:

* **`websearch_to_tsquery`, never `to_tsquery`** (FR-003, finding C2). `to_tsquery` raises a
  syntax error on unbalanced parentheses, bare operators, and punctuation-only input — a 500
  for anyone typing `(` or `C++`, which is a raw error reaching the user and a Principle IV
  violation. `websearch_to_tsquery` never raises.
* **Keyset paging, never OFFSET** (FR-002, research D3). The cursor's tuple comparison is what
  keeps a page stable while the catalogue changes underneath it.

Withdrawn products are excluded everywhere. Out-of-stock products are not — they stay
browsable and labelled (FR-078).
"""

from __future__ import annotations

import uuid
from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import ColumnElement, Select, and_, func, literal_column, or_, select, update
from sqlalchemy.orm import Session, selectinload

from ..models import Category, Product, ProductImage, Review
from ..schemas.catalogue import SortOrder
from .cursor import Cursor

DEFAULT_LIMIT = 20
MAX_LIMIT = 100
FALLBACK_LOCALE = "en"


@dataclass(slots=True)
class ProductQuery:
    """Everything `GET /products` accepts."""

    category_slug: str | None = None
    q: str | None = None
    min_price_minor: int | None = None
    max_price_minor: int | None = None
    min_rating: float | None = None
    sort: SortOrder = SortOrder.newest
    cursor: Cursor | None = None
    limit: int = DEFAULT_LIMIT
    locale: str = FALLBACK_LOCALE
    _: Any = field(default=None, repr=False, compare=False)


def localised(column: Any, locale: str) -> ColumnElement[str]:
    """Read a locale from a JSONB map, falling back to English (FR-047).

    `COALESCE(col->>'<locale>', col->>'en', '')` — never a key and never an empty screen when a
    translation is missing.
    """
    return func.coalesce(column[locale].astext, column[FALLBACK_LOCALE].astext, "")


def visible_products() -> Select[tuple[Product]]:
    """Base selectable. Withdrawn products are invisible; out-of-stock ones are not (FR-078)."""
    return select(Product).where(Product.withdrawn_at.is_(None))


def _sort_key(sort: SortOrder, search: Any | None) -> tuple[Any, bool]:
    """Return (column, ascending) for a sort mode."""
    match sort:
        case SortOrder.price_asc:
            return Product.base_price_minor, True
        case SortOrder.price_desc:
            return Product.base_price_minor, False
        case SortOrder.rating:
            return Product.rating_average, False
        case SortOrder.newest:
            return Product.created_at, False
        case SortOrder.relevance:
            # Relevance is only meaningful with a search term; without one it degrades to
            # newest rather than producing an arbitrary constant ordering.
            return (search, False) if search is not None else (Product.created_at, False)


def _keyset_predicate(key: Any, ascending: bool, cursor: Cursor) -> ColumnElement[bool]:
    """Row-value comparison: (key, id) strictly after the cursor's position.

    Written out rather than using a SQL row constructor so it works for a descending key, where
    the comparison flips for the key but not for the tiebreaker.
    """
    if cursor.last_value is None:
        return Product.id > cursor.last_id

    if ascending:
        return or_(
            key > cursor.last_value,
            and_(key == cursor.last_value, Product.id > cursor.last_id),
        )
    return or_(key < cursor.last_value, and_(key == cursor.last_value, Product.id > cursor.last_id))


def build_product_query(query: ProductQuery) -> Select[tuple[Product]]:
    """Compose the full product selectable. Pure — no session, so it is unit-testable."""
    stmt = visible_products()

    search_rank: ColumnElement[Any] | None = None
    if query.q:
        # FR-003 / finding C2: literal user text, never a parsed operator expression.
        # The regconfig is a `literal_column` because it is a REGCONFIG, not a string — bound
        # as a parameter it cannot be rendered or cast. The user's text stays a bind
        # parameter, which is what keeps it un-injectable.
        tsquery = func.websearch_to_tsquery(literal_column("'simple'"), query.q)
        stmt = stmt.where(Product.search_vector.op("@@")(tsquery))
        search_rank = func.ts_rank_cd(Product.search_vector, tsquery)

    if query.category_slug:
        # Descendants included: a category page shows everything beneath it (FR-004).
        stmt = stmt.where(Product.category_id.in_(_category_and_descendants(query.category_slug)))

    if query.min_price_minor is not None:
        stmt = stmt.where(Product.base_price_minor >= query.min_price_minor)
    if query.max_price_minor is not None:
        stmt = stmt.where(Product.base_price_minor <= query.max_price_minor)
    if query.min_rating is not None:
        stmt = stmt.where(Product.rating_average >= query.min_rating)

    key, ascending = _sort_key(query.sort, search_rank)

    if query.cursor is not None:
        stmt = stmt.where(_keyset_predicate(key, ascending, query.cursor))

    # The id tiebreaker is what makes the order total. Without it, two products with the same
    # price have no defined relative order and paging can repeat or skip one (FR-002).
    stmt = stmt.order_by(key.asc() if ascending else key.desc(), Product.id.asc())

    # Fetch one extra row to learn whether another page exists, without a COUNT.
    return stmt.limit(min(query.limit, MAX_LIMIT) + 1)


def _category_and_descendants(slug: str) -> Select[tuple[uuid.UUID]]:
    """Recursive CTE over the category tree (FR-001)."""
    roots = select(Category.id).where(Category.slug == slug).cte("cat_tree", recursive=True)
    descendants = select(Category.id).join(roots, Category.parent_id == roots.c.id)
    tree = roots.union_all(descendants)
    return select(tree.c.id)


def list_products(session: Session, query: ProductQuery) -> tuple[Sequence[Product], bool]:
    """Run the query. Returns (page, has_more)."""
    limit = min(query.limit, MAX_LIMIT)
    rows = list(
        session.scalars(build_product_query(query).options(selectinload(Product.images))).all()
    )
    has_more = len(rows) > limit
    return rows[:limit], has_more


def next_cursor_for(products: Sequence[Product], sort: SortOrder, has_more: bool) -> Cursor | None:
    if not has_more or not products:
        return None
    last = products[-1]
    value: Any = {
        SortOrder.price_asc: last.base_price_minor,
        SortOrder.price_desc: last.base_price_minor,
        SortOrder.rating: float(last.rating_average),
        SortOrder.newest: last.created_at.isoformat(),
        SortOrder.relevance: last.created_at.isoformat(),
    }[sort]
    return Cursor(sort=sort.value, last_id=last.id, last_value=value)


def get_product(session: Session, product_id: uuid.UUID) -> Product | None:
    stmt = (
        visible_products()
        .where(Product.id == product_id)
        .options(selectinload(Product.images), selectinload(Product.category))
    )
    return session.scalars(stmt).first()


def category_tree(session: Session) -> list[Category]:
    """Whole tree in one query, assembled in memory (FR-001).

    The catalogue has ~20 categories, so a single fetch plus an in-memory assembly beats a
    recursive query per level. Roots are returned; children hang off them.
    """
    rows = list(
        session.scalars(select(Category).order_by(Category.sort_order, Category.slug)).all()
    )
    by_parent: dict[uuid.UUID | None, list[Category]] = {}
    for row in rows:
        by_parent.setdefault(row.parent_id, []).append(row)

    def attach(node: Category) -> Category:
        node.children = [attach(child) for child in by_parent.get(node.id, [])]
        return node

    return [attach(root) for root in by_parent.get(None, [])]


def list_reviews(
    session: Session, product_id: uuid.UUID, cursor: Cursor | None, limit: int
) -> tuple[Sequence[Review], bool]:
    """Newest first, keyset paged (FR-007)."""
    limit = min(limit, MAX_LIMIT)
    stmt = select(Review).where(Review.product_id == product_id)

    if cursor is not None and cursor.last_value is not None:
        stmt = stmt.where(
            or_(
                Review.created_at < cursor.last_value,
                and_(Review.created_at == cursor.last_value, Review.id > cursor.last_id),
            )
        )

    stmt = stmt.order_by(Review.created_at.desc(), Review.id.asc()).limit(limit + 1)
    rows = list(session.scalars(stmt).all())
    return rows[:limit], len(rows) > limit


def rating_stats_query(product_id: uuid.UUID) -> Select[tuple[Any, int]]:
    """Aggregate a product's rating from its review rows.

    Split out from :func:`recompute_rating` so the statement can be compiled and asserted
    without a database — the property that matters (recomputed, not incremented) is visible
    in the SQL.
    """
    return select(func.avg(Review.rating), func.count(Review.id)).where(
        Review.product_id == product_id
    )


def rating_update(product_id: uuid.UUID, average: float, count: int) -> Any:
    """Write both denormalised columns together, so they cannot disagree."""
    return (
        update(Product)
        .where(Product.id == product_id)
        .values(rating_average=round(average, 2), rating_count=count)
    )


def recompute_rating(session: Session, product_id: uuid.UUID) -> None:
    """FR-009: recompute the denormalised average and count after a review is written.

    Recomputed from the rows rather than incremented. An increment would drift whenever two
    reviews land concurrently, or whenever a review is anonymised on account deletion (FR-017);
    the aggregate read is cheap at this scale and correctness is not negotiable.
    """
    average, count = session.execute(rating_stats_query(product_id)).one()
    session.execute(rating_update(product_id, float(average or 0), int(count or 0)))


def primary_image(product: Product) -> ProductImage | None:
    """FR-061 relies on this being tolerant: a product with no image must not raise."""
    return product.images[0] if product.images else None
