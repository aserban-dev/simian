"""Profile merge rules on sign-up and subsequent sign-ins.

The row-creation half of provisioning (FR-014) needs a database and is covered by T061, which is
BLOCKED without one. What is tested here is the rule that decides *which* profile values
survive — the part with a permanent failure mode.
"""

from __future__ import annotations

import pytest

from dupermarket_api.auth.firebase import VerifiedToken
from dupermarket_api.auth.user_provisioning import merge_provider_profile

pytestmark = pytest.mark.unit


def claims(name: str | None = None, picture: str | None = None) -> VerifiedToken:
    return VerifiedToken(uid="uid-1", email=None, name=name, picture=picture)


class TestSignUp:
    def test_the_name_from_first_authorisation_is_taken(self) -> None:
        """FR-081: sign-up is the only chance Apple gives us to learn the name."""
        name, avatar = merge_provider_profile(None, None, claims(name="Sam Shopper"))
        assert name == "Sam Shopper"
        assert avatar is None

    def test_the_avatar_from_first_authorisation_is_taken(self) -> None:
        _, avatar = merge_provider_profile(None, None, claims(picture="https://cdn/a.png"))
        assert avatar == "https://cdn/a.png"


class TestReturningSignIn:
    def test_a_later_sign_in_without_a_name_does_not_erase_the_stored_one(self) -> None:
        """FR-081: this is the Apple failure mode, and it is permanent when it happens.

        Apple returns the full name only on the very first authorisation. If the second
        sign-in's empty name overwrites the first one's value, the account is unnamed forever —
        the user would have to revoke the app in iOS Settings and re-authorise to fix it.
        """
        name, avatar = merge_provider_profile("Sam Shopper", "https://cdn/a.png", claims())

        assert name == "Sam Shopper"
        assert avatar == "https://cdn/a.png"

    def test_an_empty_string_is_treated_as_no_name_not_as_a_new_name(self) -> None:
        # Providers send "" as readily as null; both must be non-destructive.
        name, _ = merge_provider_profile("Sam Shopper", None, claims(name=""))
        assert name == "Sam Shopper"

    def test_a_genuine_rename_is_still_applied(self) -> None:
        """FR-081 must not freeze the profile — Google and Facebook do send updates."""
        name, avatar = merge_provider_profile(
            "Sam Shopper",
            "https://cdn/old.png",
            claims(name="Samantha Shopper", picture="https://cdn/new.png"),
        )
        assert name == "Samantha Shopper"
        assert avatar == "https://cdn/new.png"

    def test_a_new_avatar_arrives_without_a_name_change(self) -> None:
        name, avatar = merge_provider_profile(
            "Sam Shopper", "https://cdn/old.png", claims(picture="https://cdn/new.png")
        )
        assert name == "Sam Shopper"
        assert avatar == "https://cdn/new.png"

    def test_the_merge_is_idempotent(self) -> None:
        """FR-080: signing in repeatedly must converge, not oscillate."""
        first = merge_provider_profile(None, None, claims(name="Sam", picture="p"))
        second = merge_provider_profile(*first, claims(name="Sam", picture="p"))
        assert first == second
