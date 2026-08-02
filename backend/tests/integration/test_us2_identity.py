"""US2 — sign up or sign in and be recognised, against a real PostgreSQL.

The executable form of User Story 2's Independent Test. Covers:

* T167 / FR-080 — authorising twice with the same provider identity signs in to the existing
  account and creates no second row.
* T164 / FR-081 — a returning sign-in that carries no name does not erase the stored one. The
  unit suite asserts the *rule* (`merge_provider_profile`); this asserts the rule survives a
  round trip through the database, which is where "unchanged" actually has to hold.
* T062 / FR-013 — one user never sees another's data, and the API never distinguishes "not
  yours" from "does not exist".

The unique index on `firebase_uid` is the thing under test for T167, and a unique index is
exactly what an in-memory fake would not have.
"""

from __future__ import annotations

from typing import Any

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from dupermarket_api.models import AppUser

pytestmark = pytest.mark.integration

ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}
AUTH_B = {"Authorization": "Bearer user-b"}


def user_count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(AppUser)) or 0


class TestLazyProvisioning:
    """FR-014 — the profile appears on the first authenticated call, with no registration step."""

    def test_the_first_authenticated_call_creates_exactly_one_row(
        self, client: Any, db_session: Session
    ) -> None:
        before = user_count(db_session)

        client.get(ME, headers=AUTH_A)

        assert user_count(db_session) == before + 1

    def test_an_anonymous_call_creates_nothing(self, client: Any, db_session: Session) -> None:
        before = user_count(db_session)

        client.get(ME)

        assert user_count(db_session) == before


class TestReturningSignIn:
    """FR-080 — authorising again signs in; it does not create a second account."""

    def test_a_second_authorisation_creates_no_second_row(
        self, client: Any, db_session: Session
    ) -> None:
        client.get(ME, headers=AUTH_A)
        after_first = user_count(db_session)

        client.get(ME, headers=AUTH_A)

        assert user_count(db_session) == after_first

    def test_repeated_authorisation_returns_the_same_account(self, client: Any) -> None:
        first = client.get(ME, headers=AUTH_A).json()["id"]

        assert client.get(ME, headers=AUTH_A).json()["id"] == first

    def test_many_authorisations_still_leave_one_row(
        self, client: Any, db_session: Session
    ) -> None:
        """First launch after sign-in fires several requests at once; each provisions."""
        for _ in range(5):
            client.get(ME, headers=AUTH_A)

        rows = db_session.scalars(
            select(AppUser).where(AppUser.firebase_uid == "firebase-user-a")
        ).all()
        assert len(rows) == 1

    def test_two_different_identities_get_two_accounts(
        self, client: Any, db_session: Session
    ) -> None:
        before = user_count(db_session)

        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)

        assert user_count(db_session) == before + 2


class TestNameSurvivesAReturningSignIn:
    """T164 / FR-081 — Apple gives the name once. The database must not lose it.

    `token_verifier` is re-registered between calls to model exactly what Apple does: the same
    UID authorises again, and the second identity token carries no name at all.
    """

    def test_a_name_learned_at_sign_up_survives_a_nameless_sign_in(
        self, client: Any, token_verifier: Any
    ) -> None:
        token_verifier.register("apple", name="Sam Shopper")
        signed_up = client.get(ME, headers={"Authorization": "Bearer apple"})
        assert signed_up.json()["display_name"] == "Sam Shopper"

        # The same account authorises again; Apple sends no name this time.
        token_verifier.register("apple", name=None)
        returning = client.get(ME, headers={"Authorization": "Bearer apple"})

        assert returning.json()["display_name"] == "Sam Shopper"

    def test_the_nameless_sign_in_still_returns_the_same_account(
        self, client: Any, token_verifier: Any
    ) -> None:
        token_verifier.register("apple", name="Sam Shopper")
        first = client.get(ME, headers={"Authorization": "Bearer apple"}).json()["id"]

        token_verifier.register("apple", name=None)

        assert client.get(ME, headers={"Authorization": "Bearer apple"}).json()["id"] == first

    def test_an_empty_name_is_as_harmless_as_a_missing_one(
        self, client: Any, token_verifier: Any
    ) -> None:
        token_verifier.register("apple", name="Sam Shopper")
        client.get(ME, headers={"Authorization": "Bearer apple"})

        token_verifier.register("apple", name="")
        returning = client.get(ME, headers={"Authorization": "Bearer apple"})

        assert returning.json()["display_name"] == "Sam Shopper"

    def test_a_name_written_by_the_client_survives_a_later_sign_in(
        self, client: Any, token_verifier: Any
    ) -> None:
        """The full D13 round trip: the client captures the name and PATCHes it at sign-up.

        This is the path Apple actually takes — the ID token never carries the name, so without
        the client's write there is nothing to preserve.
        """
        token_verifier.register("apple", name=None)
        client.get(ME, headers={"Authorization": "Bearer apple"})
        client.patch(
            ME,
            headers={"Authorization": "Bearer apple"},
            json={"display_name": "Sam Shopper"},
        )

        returning = client.get(ME, headers={"Authorization": "Bearer apple"})

        assert returning.json()["display_name"] == "Sam Shopper"


class TestUserIsolation:
    """T062 / FR-013 — never leak another user's data, and never confirm it exists."""

    def test_each_credential_resolves_to_its_own_account(self, client: Any) -> None:
        a = client.get(ME, headers=AUTH_A).json()
        b = client.get(ME, headers=AUTH_B).json()

        assert a["id"] != b["id"]
        assert a["display_name"] == "User A"
        assert b["display_name"] == "User B"

    def test_one_user_s_write_is_invisible_to_another(self, client: Any) -> None:
        client.patch(ME, headers=AUTH_A, json={"language_override": "ro-RO"})

        assert client.get(ME, headers=AUTH_B).json()["language_override"] is None

    def test_a_users_own_row_is_never_reachable_with_another_credential(
        self, client: Any, db_session: Session
    ) -> None:
        """`/me` is resolved from the token, never from a client-supplied id."""
        client.get(ME, headers=AUTH_A)
        a_id = client.get(ME, headers=AUTH_A).json()["id"]

        b_view = client.get(ME, headers=AUTH_B).json()

        assert b_view["id"] != a_id
        stored_b = db_session.scalar(
            select(AppUser).where(AppUser.firebase_uid == "firebase-user-b")
        )
        assert stored_b is not None and str(stored_b.id) == b_view["id"]

    def test_no_operation_in_the_contract_declares_403(
        self, operations: list[dict[str, Any]]
    ) -> None:
        """Research D10: 403 confirms the identifier is real, so it is never the answer.

        Asserted across the whole contract rather than per endpoint, so a user-scoped resource
        added later cannot quietly introduce the leak. The cross-user request itself becomes
        testable with the first id-addressable user-scoped resource (orders, T084).
        """
        offenders = [
            op["operation_id"] for op in operations if "403" in op["op"].get("responses", {})
        ]
        assert not offenders, (
            f"operations declaring 403: {offenders}. FR-013 requires 404 — a 403 confirms the "
            "resource exists, which is the leak the requirement exists to prevent."
        )
