"""FastAPI application factory.

Routers are added per user story from Phase 3 onward (T052, T053, T065, …). What exists here
now is the shell every router inherits: error handlers that guarantee no raw error escapes
(Principle IV), and a health endpoint.
"""

from __future__ import annotations

import logging

from fastapi import FastAPI

from .api import addresses, categories, devices, me, orders, products, wishlist
from .config import Settings, get_settings
from .errors import install_error_handlers
from .logging_config import configure_logging

logger = logging.getLogger(__name__)

API_PREFIX = "/v1"


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    # Structured, and with a formatter that cannot emit a card-shaped string (T160).
    configure_logging(settings.log_level)

    app = FastAPI(
        title="DuperMarket Shopping App Simulator API",
        version="1.0.0",
        description=(
            "Simulated e-commerce backend. No payment integration exists, by design "
            "(constitution, Principle I)."
        ),
        docs_url=None if settings.is_production else "/docs",
        openapi_url=None if settings.is_production else "/openapi.json",
    )

    # The single source of settings for every request in this app instance.
    app.state.settings = settings

    install_error_handlers(app)

    @app.get("/healthz", include_in_schema=False)
    async def healthz() -> dict[str, str]:
        return {"status": "ok", "environment": settings.environment}

    # US1 — the browsable catalogue. Public reads (FR-010).
    app.include_router(categories.router, prefix=API_PREFIX)
    app.include_router(products.router, prefix=API_PREFIX)

    # US2 — the authenticated user's own profile. Lazily provisioned (FR-014).
    app.include_router(me.router, prefix=API_PREFIX)

    # US3 — the simulated checkout. No payment integration exists (Principle I).
    app.include_router(orders.router, prefix=API_PREFIX)

    # US6 — addresses and wishlist.
    app.include_router(addresses.router, prefix=API_PREFIX)
    app.include_router(wishlist.router, prefix=API_PREFIX)

    # US7 — push token registration. No per-stage push is sent from here (research D6).
    app.include_router(devices.router, prefix=API_PREFIX)

    return app


app = create_app  # module-level factory reference; uvicorn uses `create_app` via --factory
