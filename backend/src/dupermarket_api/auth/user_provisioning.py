"""Lazy user provisioning and the `current_user` dependency.

FR-014: a profile is created on a user's first authenticated request, with no separate
registration step. FR-013: anything without a valid credential is rejected before it reaches a
router.
"""

from __future__ import annotations

import datetime as dt
from functools import lru_cache
from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import Settings
from ..deps import ClockDep, DbDep, get_request_settings
from ..errors import Unauthorized
from ..models import AppUser
from .firebase import FirebaseTokenVerifier, TokenInvalid, VerifiedToken


@lru_cache(maxsize=1)
def _verifier_for(project_id: str, jwks_url: str) -> FirebaseTokenVerifier:
    return FirebaseTokenVerifier(project_id, jwks_url)


def get_verifier(
    settings: Annotated[Settings, Depends(get_request_settings)],
) -> FirebaseTokenVerifier:
    """Overridden in tests with a fake, so no test needs a real Firebase project."""
    return _verifier_for(settings.firebase_project_id, settings.firebase_jwks_url)


# Declared as a security scheme rather than read as a raw header, so that FastAPI advertises
# it in the generated OpenAPI. Without this the document would show every authenticated
# operation as public — the code would still reject anonymous callers, but generated clients and
# the contract-conformance test would both believe otherwise.
#
# auto_error=False because FastAPI's own 401 is a bare {"detail": ...}; ours is an RFC 9457
# problem document with a message safe to show a user (Principle IV).
bearer_scheme = HTTPBearer(
    scheme_name="firebaseIdToken",
    description="A Firebase ID token. The backend verifies it and issues none of its own.",
    auto_error=False,
)


def merge_provider_profile(
    stored_name: str | None,
    stored_avatar: str | None,
    claims: VerifiedToken,
) -> tuple[str | None, str | None]:
    """Decide the profile fields to keep after an authentication.

    FR-081 lives here. Apple returns the user's name **only on the first authorisation**; every
    later sign-in carries none. So an incoming empty name must never overwrite a stored one —
    otherwise the second sign-in erases what the first one learned, permanently, since there is
    no way to ask Apple again.

    Extracted from :func:`provision_user` so the rule is unit-testable without a database.
    """
    name = claims.name or stored_name
    avatar = claims.picture or stored_avatar
    return name, avatar


def provision_user(session: Session, claims: VerifiedToken, now: dt.datetime) -> AppUser:
    """Fetch the caller's row, creating it on first sight (FR-014).

    The insert races with itself when a client fires several requests at once on first launch,
    which is exactly what happens after sign-in. The `IntegrityError` path is the normal case
    for that race, not an error path.
    """
    user = session.scalar(select(AppUser).where(AppUser.firebase_uid == claims.uid))
    if user is not None:
        # Provider profile fields can change (new avatar, renamed account); keep them fresh,
        # but never regress to empty — see merge_provider_profile.
        user.display_name, user.avatar_url = merge_provider_profile(
            user.display_name, user.avatar_url, claims
        )
        return user

    user = AppUser(
        firebase_uid=claims.uid,
        display_name=claims.name,
        avatar_url=claims.picture,
        notification_prefs={},
    )
    session.add(user)
    try:
        session.flush()
    except IntegrityError:
        session.rollback()
        existing = session.scalar(select(AppUser).where(AppUser.firebase_uid == claims.uid))
        if existing is None:  # pragma: no cover - would mean the unique index is missing
            raise
        return existing
    return user


def get_current_user(
    session: DbDep,
    clock: ClockDep,
    verifier: Annotated[FirebaseTokenVerifier, Depends(get_verifier)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)] = None,
) -> AppUser:
    if credentials is None or not credentials.credentials:
        raise Unauthorized("Sign in to continue.")

    try:
        claims = verifier.verify(credentials.credentials, now=clock.now())
    except TokenInvalid as exc:
        # One message for every rejection reason — see FirebaseTokenVerifier.
        raise Unauthorized("Your session has expired. Sign in again.") from exc

    return provision_user(session, claims, clock.now())


CurrentUser = Annotated[AppUser, Depends(get_current_user)]
