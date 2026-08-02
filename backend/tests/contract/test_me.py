"""`GET /me`, `PATCH /me` and `DELETE /me` against the published contract.

Covers T060 (success, anonymous 401, validation failure, and the FR-017 deletion-request
behaviour) and T166 (`display_name` is written once and never cleared by a later sign-in).

The response shape is asserted against `contracts/openapi.yaml` itself rather than a hand-copied
field list, so a contract change that the implementation has not followed fails here rather than
in a client months later.
"""

from __future__ import annotations

import datetime as dt
import uuid
from typing import Any

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from dupermarket_api.models import Address, AppUser, Device, Order

pytestmark = [pytest.mark.contract, pytest.mark.integration]

ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}
AUTH_B = {"Authorization": "Bearer user-b"}


@pytest.fixture
def user_schema(contract: dict[str, Any]) -> dict[str, Any]:
    return contract["components"]["schemas"]["User"]


def user_row(session: Session, token: str = "user-a") -> AppUser:
    """The row the fake verifier's UID maps to. Provisioned by any authenticated call."""
    user = session.scalar(select(AppUser).where(AppUser.firebase_uid == f"firebase-{token}"))
    assert user is not None, "the authenticated call should have provisioned a row (FR-014)"
    return user


class TestGetMe:
    def test_returns_200_with_the_contracted_shape(
        self, client: Any, user_schema: dict[str, Any]
    ) -> None:
        response = client.get(ME, headers=AUTH_A)

        assert response.status_code == 200
        body = response.json()
        for field in user_schema["required"]:
            assert field in body, f"contract requires `{field}` on User"
        undeclared = set(body) - set(user_schema["properties"])
        assert not undeclared, f"fields not declared in the contract's User schema: {undeclared}"

    def test_the_id_is_a_uuid(self, client: Any) -> None:
        uuid.UUID(client.get(ME, headers=AUTH_A).json()["id"])

    def test_the_provider_profile_is_reflected(self, client: Any) -> None:
        # The fake verifier registers "user-a" with the name "User A".
        assert client.get(ME, headers=AUTH_A).json()["display_name"] == "User A"

    def test_an_anonymous_request_is_401(self, client: Any) -> None:
        """FR-013: no credential, no user-scoped resource."""
        response = client.get(ME)

        assert response.status_code == 401
        assert response.headers["content-type"].startswith("application/problem+json")

    def test_a_rejected_token_is_401(self, client: Any) -> None:
        assert client.get(ME, headers={"Authorization": "Bearer nonsense"}).status_code == 401

    def test_the_401_body_carries_no_stack_trace(self, client: Any) -> None:
        """Principle IV: what reaches the client is safe to show a user."""
        body = client.get(ME).json()
        assert "Traceback" not in str(body)
        assert body["detail"]


class TestPatchMe:
    def test_updates_the_overrides_and_returns_the_profile(self, client: Any) -> None:
        response = client.patch(
            ME,
            headers=AUTH_A,
            json={
                "language_override": "ro-RO",
                "currency_override": "RON",
                "notification_prefs": {"promotions": False},
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert body["language_override"] == "ro-RO"
        assert body["currency_override"] == "RON"
        assert body["notification_prefs"] == {"promotions": False}

    def test_null_clears_an_override_back_to_following_the_device(self, client: Any) -> None:
        """`language_override` is explicitly nullable: null means "follow the device"."""
        client.patch(ME, headers=AUTH_A, json={"language_override": "ro-RO"})

        body = client.patch(ME, headers=AUTH_A, json={"language_override": None}).json()

        assert body["language_override"] is None

    def test_a_malformed_currency_is_400(self, client: Any) -> None:
        response = client.patch(ME, headers=AUTH_A, json={"currency_override": "euro"})

        assert response.status_code == 400
        assert response.headers["content-type"].startswith("application/problem+json")

    def test_an_overlong_display_name_is_400(self, client: Any) -> None:
        """The contract caps it at 120 characters."""
        response = client.patch(ME, headers=AUTH_A, json={"display_name": "x" * 121})

        assert response.status_code == 400

    def test_an_anonymous_request_is_401(self, client: Any) -> None:
        assert client.patch(ME, json={"language_override": "en"}).status_code == 401


class TestPatchMeDisplayName:
    """T166 / FR-081 — the Apple asymmetry, asserted at the API boundary.

    Apple returns the user's name only on the very first authorisation, and never carries it in
    the ID token. The client captures it at sign-up and writes it here; every later sign-in
    arrives nameless. So a request that omits the field, or sends null, must leave the stored
    name alone — otherwise the second sign-in erases what the first one learned, permanently.

    The identity used here is deliberately **nameless**, because that is the only case in which
    this endpoint is load-bearing. A provider that keeps sending a name (Google, Facebook) stays
    authoritative over it on every authentication — see `TestProviderSuppliedNameStillWins`.
    """

    APPLE = {"Authorization": "Bearer apple"}

    @pytest.fixture(autouse=True)
    def _nameless_identity(self, token_verifier: Any) -> None:
        token_verifier.register("apple", name=None)

    def test_a_name_sent_at_sign_up_is_stored(self, client: Any) -> None:
        body = client.patch(ME, headers=self.APPLE, json={"display_name": "Sam Shopper"}).json()

        assert body["display_name"] == "Sam Shopper"
        assert client.get(ME, headers=self.APPLE).json()["display_name"] == "Sam Shopper"

    def test_omitting_the_field_leaves_the_stored_name_unchanged(self, client: Any) -> None:
        client.patch(ME, headers=self.APPLE, json={"display_name": "Sam Shopper"})

        body = client.patch(ME, headers=self.APPLE, json={"language_override": "en"}).json()

        assert body["display_name"] == "Sam Shopper"

    def test_sending_null_leaves_the_stored_name_unchanged(self, client: Any) -> None:
        """Null never clears the name — that is the whole point of FR-081."""
        client.patch(ME, headers=self.APPLE, json={"display_name": "Sam Shopper"})

        body = client.patch(ME, headers=self.APPLE, json={"display_name": None}).json()

        assert body["display_name"] == "Sam Shopper"

    def test_an_empty_string_leaves_the_stored_name_unchanged(self, client: Any) -> None:
        # Providers send "" as readily as null; both must be non-destructive.
        client.patch(ME, headers=self.APPLE, json={"display_name": "Sam Shopper"})

        body = client.patch(ME, headers=self.APPLE, json={"display_name": ""}).json()

        assert body["display_name"] == "Sam Shopper"

    def test_a_genuine_rename_is_applied(self, client: Any) -> None:
        client.patch(ME, headers=self.APPLE, json={"display_name": "Sam Shopper"})

        body = client.patch(ME, headers=self.APPLE, json={"display_name": "Samantha"}).json()

        assert body["display_name"] == "Samantha"


class TestProviderSuppliedNameStillWins:
    """The other half of FR-081, and the reason the rule above is narrow.

    FR-081 forbids *erasing* a stored name; it does not freeze the profile. Where the provider
    does supply a name on every sign-in, that name stays authoritative — the spec describes the
    display name as the one "supplied by their authentication provider".
    """

    def test_a_renamed_provider_account_updates_on_the_next_authentication(
        self, client: Any, token_verifier: Any
    ) -> None:
        assert client.get(ME, headers=AUTH_A).json()["display_name"] == "User A"

        token_verifier.register("user-a", name="Renamed A")

        assert client.get(ME, headers=AUTH_A).json()["display_name"] == "Renamed A"


def make_address(session: Session, user: AppUser) -> Address:
    address = Address(
        user_id=user.id,
        line1="1 Test Street",
        city="Bucharest",
        country_code="RO",
        lat=44.43,
        lng=26.10,
        is_default=True,
    )
    session.add(address)
    session.flush()
    return address


def make_order_mid_delivery(session: Session, user: AppUser, now: dt.datetime) -> Order:
    """An order whose delivery window straddles `now` — in flight, not yet delivered."""
    address = make_address(session, user)
    order = Order(
        order_number=f"DM-{uuid.uuid4().hex[:8].upper()}",
        user_id=user.id,
        address_id=address.id,
        address_snapshot={"line1": address.line1, "city": address.city},
        total_minor=12_00,
        currency="EUR",
        base_total_minor=12_00,
        fx_rate=1,
        origin_lat=44.40,
        origin_lng=26.00,
        destination_lat=address.lat,
        destination_lng=address.lng,
        processing_at=now - dt.timedelta(hours=12),
        shipped_at=now - dt.timedelta(hours=6),
        out_for_delivery_at=now + dt.timedelta(hours=6),
        delivered_at=now + dt.timedelta(hours=24),
    )
    session.add(order)
    session.flush()
    return order


class TestDeleteMe:
    """FR-017 — a *request*, not an erasure."""

    def test_returns_202(self, client: Any) -> None:
        client.get(ME, headers=AUTH_A)

        assert client.delete(ME, headers=AUTH_A).status_code == 202

    def test_records_the_request_timestamp(
        self, client: Any, db_session: Session, frozen_clock: Any
    ) -> None:
        client.get(ME, headers=AUTH_A)

        client.delete(ME, headers=AUTH_A)

        assert user_row(db_session).deletion_requested_at == frozen_clock.now()

    def test_every_device_row_is_removed_so_no_further_push_can_arrive(
        self, client: Any, db_session: Session, frozen_clock: Any
    ) -> None:
        client.get(ME, headers=AUTH_A)
        user = user_row(db_session)
        for platform in ("ios", "android"):
            db_session.add(
                Device(
                    user_id=user.id,
                    fcm_token=f"token-{platform}-{uuid.uuid4().hex[:6]}",
                    platform=platform,
                    last_seen_at=frozen_clock.now(),
                )
            )
        db_session.flush()

        client.delete(ME, headers=AUTH_A)

        remaining = db_session.scalars(select(Device).where(Device.user_id == user.id)).all()
        assert remaining == [], "FR-017 requires immediate deregistration of every device"

    def test_a_request_made_mid_delivery_is_accepted_not_rejected(
        self, client: Any, db_session: Session, frozen_clock: Any
    ) -> None:
        """The case FR-017 calls out explicitly: an in-flight order must not block the request."""
        client.get(ME, headers=AUTH_A)
        user = user_row(db_session)
        make_order_mid_delivery(db_session, user, frozen_clock.now())

        assert client.delete(ME, headers=AUTH_A).status_code == 202

    def test_the_in_flight_order_remains_readable_afterwards(
        self, client: Any, db_session: Session, frozen_clock: Any
    ) -> None:
        client.get(ME, headers=AUTH_A)
        user = user_row(db_session)
        order = make_order_mid_delivery(db_session, user, frozen_clock.now())

        client.delete(ME, headers=AUTH_A)

        assert db_session.get(Order, order.id) is not None

    def test_the_account_stays_usable(self, client: Any) -> None:
        """Usable "in the meantime" (FR-017) — the credential still works after the request."""
        client.get(ME, headers=AUTH_A)
        client.delete(ME, headers=AUTH_A)

        assert client.get(ME, headers=AUTH_A).status_code == 200

    def test_the_profile_reports_the_pending_request(self, client: Any) -> None:
        client.get(ME, headers=AUTH_A)
        client.delete(ME, headers=AUTH_A)

        assert client.get(ME, headers=AUTH_A).json()["deletion_requested_at"] is not None

    def test_an_anonymous_request_is_401(self, client: Any) -> None:
        assert client.delete(ME).status_code == 401

    def test_one_user_s_request_does_not_touch_another_s_devices(
        self, client: Any, db_session: Session, frozen_clock: Any
    ) -> None:
        """The delete is scoped by user id, not by "all rows" — asserted, not assumed."""
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        other = user_row(db_session, "user-b")
        db_session.add(
            Device(
                user_id=other.id,
                fcm_token="token-b",
                platform="ios",
                last_seen_at=frozen_clock.now(),
            )
        )
        db_session.flush()

        client.delete(ME, headers=AUTH_A)

        assert db_session.scalars(select(Device).where(Device.user_id == other.id)).all() != []
        assert user_row(db_session, "user-b").deletion_requested_at is None
