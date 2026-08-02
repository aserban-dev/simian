"""Application settings.

Every required value is declared here and validated at import time, so a missing environment
variable fails at startup with the variable's name rather than at first use with a confusing
404 or an empty conversion table. That behaviour is promised in `.env.example` and in
quickstart.md's troubleshooting table.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    environment: str = Field(default="dev")
    log_level: str = Field(default="INFO")

    database_url: str = Field(
        ...,
        description="SQLAlchemy URL, e.g. postgresql+psycopg://user:pass@host:5432/dupermarket",
    )

    # --- Identity ---------------------------------------------------------------------
    # The backend is a resource server: it validates Firebase ID tokens and issues none of
    # its own (constitution, Technology and Architecture Constraints).
    firebase_project_id: str = Field(...)
    firebase_jwks_url: str = Field(default="https://www.googleapis.com/service_accounts/v1/jwks")

    # --- Catalogue --------------------------------------------------------------------
    base_currency: str = Field(default="EUR", min_length=3, max_length=3)
    catalogue_cache_ttl_seconds: int = Field(default=3600, ge=0)

    # --- CDN --------------------------------------------------------------------------
    # Used only to build public URLs from stored paths. The API never proxies image bytes
    # (Principle V), so no credentials are needed here — only the seed pipeline writes.
    r2_public_base_url: str = Field(default="")

    @field_validator("database_url")
    @classmethod
    def _reject_sqlite(cls, value: str) -> str:
        # Research D11: the design leans on tsvector ranking, GIN indexes, partial unique
        # indexes and a write-once trigger, none of which exist in SQLite. A SQLite URL would
        # let the suite pass while the production query path was broken.
        if value.startswith("sqlite"):
            raise ValueError(
                "SQLite is not supported: the schema depends on PostgreSQL features "
                "(tsvector, GIN, partial unique indexes, triggers). See research.md D11."
            )
        return value

    @property
    def is_production(self) -> bool:
        return self.environment == "prod"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached settings accessor. Tests override the dependency rather than mutating this."""
    return Settings()  # type: ignore[call-arg]
