"""Token verification, against locally generated keys.

No Firebase project and no network are involved: the test mints its own RSA key, signs tokens
with it, and hands the verifier that key directly. That covers the cases that matter — expired,
wrong audience, wrong issuer, tampered signature, missing claims — which a fake verifier used
elsewhere in the suite deliberately does not.
"""

from __future__ import annotations

import datetime as dt

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from dupermarket_api.auth.firebase import FirebaseTokenVerifier, TokenInvalid

pytestmark = pytest.mark.unit

PROJECT_ID = "dupermarket-test"
ISSUER = f"https://securetoken.google.com/{PROJECT_ID}"
NOW = dt.datetime(2026, 8, 2, 12, 0, tzinfo=dt.UTC)


@pytest.fixture(scope="module")
def keypair() -> tuple[object, object]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private_key, private_key.public_key()


@pytest.fixture
def verifier(keypair: tuple[object, object], monkeypatch: pytest.MonkeyPatch):
    """A verifier whose key resolution is pinned to the locally generated public key."""
    _, public_key = keypair
    v = FirebaseTokenVerifier(PROJECT_ID, "https://example.invalid/jwks")
    monkeypatch.setattr(v, "_signing_key_for", lambda token, *, now=None: public_key)
    return v


def make_token(
    private_key: object,
    *,
    sub: str = "firebase-uid-123",
    aud: str = PROJECT_ID,
    iss: str = ISSUER,
    exp_delta: dt.timedelta = dt.timedelta(hours=1),
    include: dict[str, object] | None = None,
    omit: set[str] | None = None,
) -> str:
    claims: dict[str, object] = {
        "sub": sub,
        "aud": aud,
        "iss": iss,
        "iat": int(NOW.timestamp()),
        "exp": int((NOW + exp_delta).timestamp()),
        "email": "shopper@example.com",
        "name": "Sam Shopper",
        "picture": "https://cdn.example/avatar.png",
    }
    claims.update(include or {})
    for key in omit or set():
        claims.pop(key, None)
    return jwt.encode(claims, private_key, algorithm="RS256")  # type: ignore[arg-type]


class TestValidToken:
    def test_a_well_formed_token_yields_the_firebase_uid(self, verifier, keypair) -> None:
        """FR-013: the sub claim is the canonical identity the whole system keys on."""
        private_key, _ = keypair
        result = verifier.verify(make_token(private_key), now=NOW)

        assert result.uid == "firebase-uid-123"
        assert result.email == "shopper@example.com"
        assert result.name == "Sam Shopper"


class TestRejection:
    """FR-013: every one of these must be rejected, and rejected identically."""

    def test_expired_token_is_rejected(self, verifier, keypair) -> None:
        private_key, _ = keypair
        token = make_token(private_key, exp_delta=dt.timedelta(seconds=-1))
        with pytest.raises(TokenInvalid):
            verifier.verify(token, now=NOW)

    def test_wrong_audience_is_rejected(self, verifier, keypair) -> None:
        # A token minted for another Firebase project must not work here.
        private_key, _ = keypair
        token = make_token(private_key, aud="some-other-project")
        with pytest.raises(TokenInvalid):
            verifier.verify(token, now=NOW)

    def test_wrong_issuer_is_rejected(self, verifier, keypair) -> None:
        private_key, _ = keypair
        token = make_token(private_key, iss="https://evil.example/")
        with pytest.raises(TokenInvalid):
            verifier.verify(token, now=NOW)

    def test_tampered_signature_is_rejected(self, verifier, keypair) -> None:
        private_key, _ = keypair
        token = make_token(private_key)
        header, payload, signature = token.split(".")
        tampered = f"{header}.{payload}.{signature[:-4]}AAAA"
        with pytest.raises(TokenInvalid):
            verifier.verify(tampered, now=NOW)

    def test_token_signed_by_a_different_key_is_rejected(self, verifier) -> None:
        attacker_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        token = make_token(attacker_key)
        with pytest.raises(TokenInvalid):
            verifier.verify(token, now=NOW)

    def test_unsigned_token_is_rejected(self, verifier) -> None:
        # The classic alg=none downgrade. RS256 is pinned, so this must not pass.
        token = jwt.encode({"sub": "x", "aud": PROJECT_ID, "iss": ISSUER}, key="", algorithm="none")
        with pytest.raises(TokenInvalid):
            verifier.verify(token, now=NOW)

    @pytest.mark.parametrize("claim", ["exp", "iat", "aud", "iss", "sub"])
    def test_missing_required_claim_is_rejected(self, verifier, keypair, claim: str) -> None:
        private_key, _ = keypair
        token = make_token(private_key, omit={claim})
        with pytest.raises(TokenInvalid):
            verifier.verify(token, now=NOW)

    def test_empty_token_is_rejected(self, verifier) -> None:
        with pytest.raises(TokenInvalid):
            verifier.verify("", now=NOW)

    def test_garbage_is_rejected_without_raising_something_else(self, verifier) -> None:
        with pytest.raises(TokenInvalid):
            verifier.verify("not-a-jwt-at-all", now=NOW)

    def test_rejection_reason_is_not_disclosed(self, verifier, keypair) -> None:
        """Every rejection carries the same message, so probing learns nothing."""
        private_key, _ = keypair
        messages = set()
        for token in (
            make_token(private_key, exp_delta=dt.timedelta(seconds=-1)),
            make_token(private_key, aud="other"),
            make_token(private_key, iss="https://evil.example/"),
        ):
            with pytest.raises(TokenInvalid) as excinfo:
                verifier.verify(token, now=NOW)
            messages.add(str(excinfo.value))

        assert len(messages) == 1, f"rejection messages differ and leak the reason: {messages}"


class TestConstruction:
    def test_a_verifier_without_a_project_id_is_a_startup_error(self) -> None:
        # Fail loudly at construction rather than accepting every token at runtime.
        with pytest.raises(ValueError, match="project_id"):
            FirebaseTokenVerifier("", "https://example.invalid/jwks")
