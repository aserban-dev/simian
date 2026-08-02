"""The profile request and response models (T064).

These mirror the `User` schema in `contracts/openapi.yaml`. Nothing here exposes `firebase_uid`:
the provider identity is the backend's business, and a profile is readable by its owner only.

The interesting part is [`UserUpdate`](#UserUpdate), where "absent" and "null" are deliberately
*not* the same thing — see FR-081.
"""

from __future__ import annotations

import datetime as dt
import uuid
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from .catalogue import CurrencyCode

DISPLAY_NAME_MAX = 120


class User(BaseModel):
    """A profile as its owner sees it."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    display_name: str | None = None
    avatar_url: str | None = None
    language_override: str | None = None
    currency_override: CurrencyCode | None = None
    notification_prefs: dict[str, bool]
    # FR-017: set when deletion is requested, so the client can tell the user what happens next.
    deletion_requested_at: dt.datetime | None = None


class UserUpdate(BaseModel):
    """A partial profile update.

    Every field defaults to `None`, so `model_fields_set` — not the value — is what says whether
    the client meant to change something. That distinction matters in opposite directions for
    the two kinds of field here:

    * `language_override` and `currency_override` are genuinely nullable settings. Sending null
      **clears** the override and returns the user to following their device.
    * `display_name` is never cleared by this endpoint. Apple returns the user's name only on
      the very first authorisation (FR-081, research D13), so a later sign-in that carries no
      name must leave the stored one alone. Absent, null, and empty all mean "no name to
      report", and none of them may erase what sign-up learned.
    """

    display_name: Annotated[str | None, Field(max_length=DISPLAY_NAME_MAX)] = None
    language_override: str | None = None
    currency_override: CurrencyCode | None = None
    notification_prefs: dict[str, bool] | None = None

    def was_provided(self, field: str) -> bool:
        """True when the client sent the field at all, whatever value it carried."""
        return field in self.model_fields_set
