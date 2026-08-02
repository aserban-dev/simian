"""Trigger DDL shared between the migration and the test schema builder.

The category cycle guard lives in the migration (it is not expressible in SQLAlchemy metadata).
Importing it here rather than copying it keeps the tested schema and the migrated schema from
drifting apart — a copy would let one be fixed without the other.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

_MIGRATION = Path(__file__).resolve().parents[1] / "alembic" / "versions" / "0001_initial_schema.py"

_spec = importlib.util.spec_from_file_location("_dupermarket_initial_migration", _MIGRATION)
assert _spec is not None and _spec.loader is not None
_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_module)

CATEGORY_CYCLE_GUARD_SQL: str = _module.CATEGORY_CYCLE_GUARD_SQL
