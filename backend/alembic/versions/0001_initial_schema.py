"""Initial schema: catalogue, identity, orders, plus the two guard triggers.

Revision ID: 0001_initial
Revises:
Create Date: 2026-08-02

Baseline migration. Tables are created from `Base.metadata`, which is the normal pattern for an
initial revision and keeps this file readable. **Every migration after this one must be
explicit** — a metadata-driven migration cannot express an ALTER, and using this shape twice is
how a schema silently stops matching its history.

Two things metadata cannot express are written out below:

* the category cycle guard — without it, one bad seed row makes tree traversal non-terminating;
* the order write-once trigger (FR-034) — the only enforcement that survives a developer who
  has not read the spec.
"""

from __future__ import annotations

from alembic import op
from dupermarket_api.models import WRITE_ONCE_TRIGGER_SQL, Base

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


CATEGORY_CYCLE_GUARD_SQL = """
CREATE OR REPLACE FUNCTION category_has_no_cycle() RETURNS trigger AS $$
DECLARE
    ancestor uuid := NEW.parent_id;
    depth int := 0;
BEGIN
    WHILE ancestor IS NOT NULL LOOP
        IF ancestor = NEW.id THEN
            RAISE EXCEPTION 'category parent_id would create a cycle';
        END IF;
        depth := depth + 1;
        IF depth > 64 THEN
            RAISE EXCEPTION 'category nesting deeper than 64 levels';
        END IF;
        SELECT parent_id INTO ancestor FROM category WHERE id = ancestor;
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_category_no_cycle ON category;

CREATE TRIGGER trg_category_no_cycle
    BEFORE INSERT OR UPDATE OF parent_id ON category
    FOR EACH ROW EXECUTE FUNCTION category_has_no_cycle();
"""


def upgrade() -> None:
    bind = op.get_bind()
    # pgcrypto is not required — UUIDs are generated client-side by SQLAlchemy defaults — but
    # the extension is cheap and lets a DBA insert rows by hand without inventing UUIDs.
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    Base.metadata.create_all(bind)

    op.execute(CATEGORY_CYCLE_GUARD_SQL)
    op.execute(WRITE_ONCE_TRIGGER_SQL)


def downgrade() -> None:
    bind = op.get_bind()
    op.execute('DROP TRIGGER IF EXISTS trg_order_stages_write_once ON "order"')
    op.execute("DROP FUNCTION IF EXISTS order_stages_are_write_once()")
    op.execute("DROP TRIGGER IF EXISTS trg_category_no_cycle ON category")
    op.execute("DROP FUNCTION IF EXISTS category_has_no_cycle()")
    Base.metadata.drop_all(bind)
