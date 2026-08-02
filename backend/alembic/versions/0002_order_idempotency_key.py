"""Add `order.idempotency_key` and its per-user partial unique index.

Revision ID: 0002_order_idempotency_key
Revises: 0001_initial
Create Date: 2026-08-03

**Why this migration checks before it alters**, unlike a normal explicit migration:

`0001_initial` builds the schema from `Base.metadata` rather than from written-out DDL. That
makes it a *moving* baseline — it creates whatever the models say today, so the moment a column
is added to a model it also appears in 0001. A fresh database therefore arrives here with
`idempotency_key` already present, while a database created before the model changed does not.

Both have to work, so each step is applied only if it is missing. The alternative is a schema
whose history depends on when the database was created, which is the failure 0001's own
docstring warns about. Rewriting 0001 as explicit DDL is the real fix and is deliberately not
done here: it is a change to an applied migration, not to this one.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0002_order_idempotency_key"
down_revision = "0001_initial"
branch_labels = None
depends_on = None

TABLE = "order"
COLUMN = "idempotency_key"
INDEX = "uq_order_idempotency_key"


def _has_column() -> bool:
    inspector = sa.inspect(op.get_bind())
    return COLUMN in {col["name"] for col in inspector.get_columns(TABLE)}


def _has_index() -> bool:
    inspector = sa.inspect(op.get_bind())
    return INDEX in {index["name"] for index in inspector.get_indexes(TABLE)}


def upgrade() -> None:
    if not _has_column():
        op.add_column(TABLE, sa.Column(COLUMN, sa.String(length=128), nullable=True))

    if not _has_index():
        # Partial (`WHERE idempotency_key IS NOT NULL`) because the column is optional and most
        # orders carry NULL. Postgres treats NULLs as distinct, so a plain unique index would
        # also work — but the partial form states the intent and keeps the index small.
        #
        # Scoped by user_id, not global: one user's key must never return another's order.
        op.create_index(
            INDEX,
            TABLE,
            ["user_id", COLUMN],
            unique=True,
            postgresql_where=sa.text(f"{COLUMN} IS NOT NULL"),
        )


def downgrade() -> None:
    if _has_index():
        op.drop_index(INDEX, table_name=TABLE)
    if _has_column():
        op.drop_column(TABLE, COLUMN)
