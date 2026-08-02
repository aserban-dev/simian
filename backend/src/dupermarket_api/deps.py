"""Dependency injection wiring.

This module is the *only* place in the application permitted to read the wall clock. Constitution
Principle III requires tests not to depend on wall-clock time, and the entire delivery simulation
is a function of time — so time is injected, and a ruff per-file-ignore in `pyproject.toml`
marks this file as the single exception to the `datetime.now()` ban.
"""

from __future__ import annotations

import datetime as dt
from collections.abc import AsyncIterator, Iterator
from typing import Annotated, Protocol

from fastapi import Depends, Request
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import Settings, get_settings


class Clock(Protocol):
    """Injectable time source. Tests substitute a frozen implementation."""

    def now(self) -> dt.datetime: ...


class SystemClock:
    """The one real clock. Always timezone-aware UTC — naive datetimes are a bug source."""

    def now(self) -> dt.datetime:
        return dt.datetime.now(dt.UTC)


def get_clock() -> Clock:
    return SystemClock()


def get_request_settings(request: Request) -> Settings:
    """Resolve settings from the app instance, not from the environment.

    `create_app(settings)` accepts a Settings object, so a request must use *that* object.
    Reading the environment again here would silently ignore what the caller passed — which is
    exactly what happened before, and made `create_app(settings)` a no-op for every router.

    `get_settings()` remains the accessor for non-request contexts (Alembic, scripts).
    """
    settings: Settings | None = getattr(request.app.state, "settings", None)
    return settings if settings is not None else get_settings()


_engine = None
_SessionFactory: sessionmaker[Session] | None = None


def _session_factory(settings: Settings) -> sessionmaker[Session]:
    global _engine, _SessionFactory
    if _SessionFactory is None:
        _engine = create_engine(settings.database_url, pool_pre_ping=True, future=True)
        _SessionFactory = sessionmaker(bind=_engine, expire_on_commit=False, future=True)
    return _SessionFactory


def get_db(
    settings: Annotated[Settings, Depends(get_request_settings)],
) -> Iterator[Session]:
    factory = _session_factory(settings)
    session = factory()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


async def _noop() -> AsyncIterator[None]:  # pragma: no cover - placeholder for lifespan hooks
    yield None


SettingsDep = Annotated[Settings, Depends(get_request_settings)]
ClockDep = Annotated[Clock, Depends(get_clock)]
DbDep = Annotated[Session, Depends(get_db)]
