"""Shared test fixtures.

Three groups:

* **Artifact fixtures** — the parsed OpenAPI document and spec text. Need nothing but the repo,
  so the contract-document suite runs anywhere.
* **Database fixtures** — a real PostgreSQL instance, one transaction per test, rolled back
  afterwards. Research D11: the design leans on `tsvector` ranking, GIN indexes, partial unique
  indexes and two triggers, none of which exist in SQLite, so an SQLite suite would pass while
  the production query path was broken.
* **App fixtures** — the ASGI app with the database and token verifier overridden, plus two
  distinct authenticated users, because every cross-user authorisation test needs a second one.

When no database is reachable the database-backed fixtures **skip** with the command to start
one. They do not fall back to a stub: a test that silently stops exercising Postgres is worse
than one that is visibly not running.
"""

from __future__ import annotations

import datetime as dt
import os
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

REPO_ROOT = Path(__file__).resolve().parents[2]
SPEC_DIR = REPO_ROOT / "specs" / "001-shopping-app-simulator"
CONTRACT_PATH = SPEC_DIR / "contracts" / "openapi.yaml"
SPEC_PATH = SPEC_DIR / "spec.md"

HTTP_METHODS = ("get", "post", "put", "patch", "delete", "head", "options")

DEFAULT_TEST_DATABASE_URL = "postgresql+psycopg://postgres:postgres@localhost:5432/dupermarket_test"
SKIP_REASON = (
    "no PostgreSQL reachable. Start one with `docker compose up -d postgres`, "
    "or set TEST_DATABASE_URL."
)


# --- artifact fixtures -------------------------------------------------------------------


@pytest.fixture(scope="session")
def contract() -> dict[str, Any]:
    """The parsed OpenAPI document. The source of truth for the contract suite."""
    yaml = pytest.importorskip("yaml", reason="pyyaml is required for the contract suite")
    with CONTRACT_PATH.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)


@pytest.fixture(scope="session")
def operations(contract: dict[str, Any]) -> list[dict[str, Any]]:
    """Every operation in the contract, flattened.

    ``public`` is true when the operation overrides the global security requirement with an
    empty list, which is how a genuinely unauthenticated endpoint is declared.
    """
    out: list[dict[str, Any]] = []
    for path, item in contract["paths"].items():
        for method, op in item.items():
            if method not in HTTP_METHODS:
                continue
            out.append(
                {
                    "path": path,
                    "method": method,
                    "operation_id": op.get("operationId", f"{method} {path}"),
                    "op": op,
                    "public": op.get("security") == [],
                }
            )
    return out


@pytest.fixture(scope="session")
def spec_text() -> str:
    return SPEC_PATH.read_text(encoding="utf-8")


# --- clock -------------------------------------------------------------------------------


class FrozenClock:
    """An injectable clock. Constitution Principle III: tests never read the wall clock."""

    def __init__(self, now: dt.datetime) -> None:
        self._now = now

    def now(self) -> dt.datetime:
        return self._now

    def advance(self, delta: dt.timedelta) -> None:
        self._now += delta


@pytest.fixture
def frozen_clock() -> FrozenClock:
    return FrozenClock(dt.datetime(2026, 8, 2, 12, 0, tzinfo=dt.UTC))


# --- database ----------------------------------------------------------------------------


def _database_url() -> str:
    return os.environ.get("TEST_DATABASE_URL", DEFAULT_TEST_DATABASE_URL)


@pytest.fixture(scope="session")
def engine() -> Iterator[Engine]:
    """A session-wide engine with the schema created once.

    The schema is built from `Base.metadata` plus the two trigger definitions, rather than by
    running Alembic: the migration is verified separately (it applies, downgrades and re-applies
    in CI), and rebuilding it per test session would be slow for no extra signal.
    """
    from dupermarket_api.models import WRITE_ONCE_TRIGGER_SQL, Base

    url = _database_url()
    admin_url = url.rsplit("/", 1)[0] + "/postgres"
    db_name = url.rsplit("/", 1)[1]

    # Create the test database if it is missing, so a fresh checkout needs only the container.
    try:
        admin = create_engine(admin_url, isolation_level="AUTOCOMMIT")
        with admin.connect() as conn:
            exists = conn.execute(
                text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": db_name}
            ).scalar()
            if not exists:
                conn.execute(text(f'CREATE DATABASE "{db_name}"'))
        admin.dispose()
    except Exception as exc:  # noqa: BLE001 - any connection failure means no database
        pytest.skip(f"{SKIP_REASON} ({exc.__class__.__name__})")

    eng = create_engine(url, future=True)

    from tests.trigger_sql import CATEGORY_CYCLE_GUARD_SQL

    with eng.begin() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS pgcrypto"))
        Base.metadata.drop_all(conn)
        Base.metadata.create_all(conn)
        conn.execute(text(CATEGORY_CYCLE_GUARD_SQL))
        conn.execute(text(WRITE_ONCE_TRIGGER_SQL))

    yield eng
    eng.dispose()


@pytest.fixture
def db_session(engine: Engine) -> Iterator[Session]:
    """One transaction per test, rolled back afterwards.

    The outer transaction is never committed, so tests see each other's schema but none of
    each other's rows — and nothing has to be cleaned up by hand.
    """
    connection = engine.connect()
    transaction = connection.begin()
    factory = sessionmaker(bind=connection, expire_on_commit=False, future=True)
    session = factory()

    # `session.commit()` inside the code under test commits to a SAVEPOINT, not to the
    # database, so application code can commit normally and the test still rolls back.
    session.begin_nested()

    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()


# --- app ---------------------------------------------------------------------------------


class FakeTokenVerifier:
    """Maps a bearer token straight to a UID.

    Research D1: the real verifier is exercised against locally generated RSA keys in
    `tests/unit/test_firebase_auth.py`. Here identity is a fixture, so no test needs a Firebase
    project — and a token of `"invalid"` still exercises the rejection path end to end.
    """

    def __init__(self) -> None:
        self.profiles: dict[str, dict[str, str | None]] = {}

    def register(self, token: str, *, name: str | None = None, picture: str | None = None) -> None:
        self.profiles[token] = {"name": name, "picture": picture}

    def verify(self, token: str, *, now: dt.datetime | None = None) -> Any:
        from dupermarket_api.auth.firebase import TokenInvalid, VerifiedToken

        if token not in self.profiles:
            raise TokenInvalid("token rejected")
        profile = self.profiles[token]
        return VerifiedToken(
            uid=f"firebase-{token}",
            email=None,
            name=profile["name"],
            picture=profile["picture"],
        )


@pytest.fixture
def token_verifier() -> FakeTokenVerifier:
    verifier = FakeTokenVerifier()
    verifier.register("user-a", name="User A")
    verifier.register("user-b", name="User B")
    return verifier


@pytest.fixture
def app(db_session: Session, token_verifier: FakeTokenVerifier, frozen_clock: FrozenClock) -> Any:
    """The real ASGI app, with the database session and token verifier overridden."""
    from dupermarket_api.auth.user_provisioning import get_verifier
    from dupermarket_api.config import Settings
    from dupermarket_api.deps import get_clock, get_db
    from dupermarket_api.main import create_app

    settings = Settings(
        database_url=_database_url(),
        firebase_project_id="test-project",
        r2_public_base_url="https://cdn.test",
    )
    application = create_app(settings)

    # The session is the test's, so everything the app writes is rolled back with the test.
    application.dependency_overrides[get_db] = lambda: db_session
    application.dependency_overrides[get_verifier] = lambda: token_verifier
    application.dependency_overrides[get_clock] = lambda: frozen_clock
    return application


@pytest.fixture
def client(app: Any) -> Iterator[Any]:
    from fastapi.testclient import TestClient

    with TestClient(app) as test_client:
        yield test_client
