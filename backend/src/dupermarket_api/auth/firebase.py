"""Firebase ID token verification.

Research D1: tokens are verified in-process against Google's JWKS, cached until its
`Cache-Control` max-age expires. No network call on the hot path once the key set is warm, and
no dependency on Firebase being reachable per request.

The backend issues no tokens of its own; the `sub` claim (the Firebase UID) is the canonical
user identity (constitution, Technology and Architecture Constraints).
"""

from __future__ import annotations

import datetime as dt
import logging
import re
import threading
from dataclasses import dataclass
from typing import Any

import httpx
import jwt
from jwt import PyJWKClient

logger = logging.getLogger(__name__)

_ISSUER_TEMPLATE = "https://securetoken.google.com/{project_id}"
_MAX_AGE_RE = re.compile(r"max-age=(\d+)")
_DEFAULT_CACHE_SECONDS = 3600


class TokenInvalid(Exception):
    """Raised for every rejection reason.

    Deliberately one exception type with a coarse message: telling a caller *why* their token
    failed distinguishes "expired" from "wrong audience" from "bad signature", which is free
    reconnaissance for anyone probing the endpoint.
    """


@dataclass(frozen=True, slots=True)
class VerifiedToken:
    uid: str
    email: str | None
    name: str | None
    picture: str | None


class FirebaseTokenVerifier:
    """Verifies Firebase ID tokens. Construct once per process."""

    def __init__(
        self,
        project_id: str,
        jwks_url: str,
        *,
        leeway_seconds: int = 0,
    ) -> None:
        if not project_id:
            raise ValueError("firebase project_id is required")
        self._project_id = project_id
        self._issuer = _ISSUER_TEMPLATE.format(project_id=project_id)
        self._jwks_url = jwks_url
        self._leeway = leeway_seconds
        self._lock = threading.Lock()
        self._client: PyJWKClient | None = None
        self._client_expires_at: dt.datetime | None = None

    def verify(self, token: str, *, now: dt.datetime | None = None) -> VerifiedToken:
        """Verify a token and return its identity claims, or raise :class:`TokenInvalid`.

        Expiry is checked against ``now`` rather than the process clock. PyJWT's own ``exp``
        check reads the wall clock and offers no injection point, so it is disabled and the
        comparison is done here — otherwise Principle III's "time is always injected" would be
        false in exactly the place it matters most for security.
        """
        if not token:
            raise TokenInvalid("token missing")

        current = now or dt.datetime.now(dt.UTC)

        try:
            signing_key = self._signing_key_for(token, now=now)
        except TokenInvalid:
            raise
        except Exception as exc:  # noqa: BLE001 - any JWKS failure is a rejection
            logger.warning("could not resolve signing key: %s", exc)
            raise TokenInvalid("token rejected") from exc

        try:
            claims = jwt.decode(
                token,
                signing_key,
                algorithms=["RS256"],
                audience=self._project_id,
                issuer=self._issuer,
                leeway=self._leeway,
                options={
                    "require": ["exp", "iat", "aud", "iss", "sub"],
                    # Checked below against the injected clock instead.
                    "verify_exp": False,
                },
            )
        except jwt.PyJWTError as exc:
            # Includes audience mismatch, issuer mismatch, missing claims, and signature
            # failure. Expiry is handled separately.
            raise TokenInvalid("token rejected") from exc

        self._assert_not_expired(claims, current)

        uid = claims.get("sub")
        if not uid or not isinstance(uid, str):
            raise TokenInvalid("token rejected")

        return VerifiedToken(
            uid=uid,
            email=claims.get("email"),
            name=claims.get("name"),
            picture=claims.get("picture"),
        )

    def _assert_not_expired(self, claims: dict[str, object], current: dt.datetime) -> None:
        raw_exp = claims.get("exp")
        if not isinstance(raw_exp, (int, float)):
            raise TokenInvalid("token rejected")

        expires_at = dt.datetime.fromtimestamp(float(raw_exp), tz=dt.UTC)
        if current > expires_at + dt.timedelta(seconds=self._leeway):
            raise TokenInvalid("token rejected")

        raw_iat = claims.get("iat")
        if isinstance(raw_iat, (int, float)):
            issued_at = dt.datetime.fromtimestamp(float(raw_iat), tz=dt.UTC)
            # A token issued in the future means a skewed or hostile signer.
            if issued_at > current + dt.timedelta(seconds=max(self._leeway, 60)):
                raise TokenInvalid("token rejected")

    # --- key handling ---------------------------------------------------------------

    def _signing_key_for(self, token: str, *, now: dt.datetime | None) -> Any:
        """Return the RSA public key for this token's `kid`.

        Typed `Any` because PyJWT's `PyJWK.key` is an untyped union of every backend key type
        it supports. Narrowing it to `str` would be a lie — for RS256 it is a
        `RSAPublicKey`, not a string.
        """
        client = self._jwk_client(now=now)
        return client.get_signing_key_from_jwt(token).key

    def _jwk_client(self, *, now: dt.datetime | None) -> PyJWKClient:
        current = now or dt.datetime.now(dt.UTC)
        with self._lock:
            if self._client is None or (
                self._client_expires_at is not None and current >= self._client_expires_at
            ):
                self._client = PyJWKClient(self._jwks_url, cache_keys=True)
                self._client_expires_at = current + dt.timedelta(seconds=self._fetch_max_age())
            return self._client

    def _fetch_max_age(self) -> int:
        """Read Google's `Cache-Control: max-age` so key rotation is picked up on time."""
        try:
            response = httpx.head(self._jwks_url, timeout=5.0, follow_redirects=True)
            match = _MAX_AGE_RE.search(response.headers.get("cache-control", ""))
            if match:
                return max(60, int(match.group(1)))
        except httpx.HTTPError as exc:
            logger.warning("could not read JWKS cache-control, using default: %s", exc)
        return _DEFAULT_CACHE_SECONDS
