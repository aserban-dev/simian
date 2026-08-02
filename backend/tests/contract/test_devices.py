"""`POST /me/devices` against the published contract (T124).

The reassignment case is the one that matters. A token is unique across the whole system, so
when a shared device signs out and back in as somebody else, registering must *move* the token
rather than leave the previous owner still able to receive pushes on it.

That failure is invisible in a single-user test and invisible in the database — it looks like a
row that is merely out of date — so it is asserted here from both sides: the new owner has it,
and the old owner does not.
"""

from __future__ import annotations

import datetime as dt
from typing import Any

import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from dupermarket_api.models import Device
from tests.factories import user_for

pytestmark = [pytest.mark.contract, pytest.mark.integration]

DEVICES = "/v1/me/devices"
ME = "/v1/me"
AUTH_A = {"Authorization": "Bearer user-a"}
AUTH_B = {"Authorization": "Bearer user-b"}


def registration(token: str = "fcm-token-1", platform: str = "ios") -> dict[str, str]:
    return {"fcm_token": token, "platform": platform}


def device_count(session: Session) -> int:
    return session.scalar(select(func.count()).select_from(Device)) or 0


def devices_of(session: Session, token: str = "user-a") -> list[Device]:
    user = user_for(session, token)
    return list(session.scalars(select(Device).where(Device.user_id == user.id)).all())


@pytest.fixture
def signed_in(client: Any) -> None:
    client.get(ME, headers=AUTH_A)


class TestRegistration:
    def test_returns_204(self, client: Any, signed_in: None) -> None:
        assert client.post(DEVICES, headers=AUTH_A, json=registration()).status_code == 204

    def test_the_token_is_stored(self, client: Any, signed_in: None, db_session: Session) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration())

        stored = devices_of(db_session)
        assert [device.fcm_token for device in stored] == ["fcm-token-1"]

    def test_the_platform_is_stored(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration(platform="android"))

        assert devices_of(db_session)[0].platform == "android"

    def test_last_seen_is_recorded(
        self, client: Any, signed_in: None, db_session: Session, frozen_clock: Any
    ) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration())

        assert devices_of(db_session)[0].last_seen_at == frozen_clock.now()

    def test_one_user_can_register_several_devices(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        """A phone and a tablet are one account with two tokens."""
        client.post(DEVICES, headers=AUTH_A, json=registration("phone-token", "ios"))
        client.post(DEVICES, headers=AUTH_A, json=registration("tablet-token", "android"))

        assert {device.fcm_token for device in devices_of(db_session)} == {
            "phone-token",
            "tablet-token",
        }


class TestReRegistration:
    def test_registering_the_same_token_twice_creates_one_row(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        """A client re-registers on every launch; that must not accumulate rows."""
        for _ in range(3):
            client.post(DEVICES, headers=AUTH_A, json=registration())

        assert device_count(db_session) == 1

    def test_re_registering_still_returns_204(self, client: Any, signed_in: None) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration())

        assert client.post(DEVICES, headers=AUTH_A, json=registration()).status_code == 204

    def test_re_registering_refreshes_last_seen(
        self, client: Any, signed_in: None, db_session: Session, frozen_clock: Any
    ) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration())
        frozen_clock.advance(dt.timedelta(days=2))

        client.post(DEVICES, headers=AUTH_A, json=registration())

        assert devices_of(db_session)[0].last_seen_at == frozen_clock.now()

    def test_the_platform_can_change_for_a_token(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration(platform="ios"))

        client.post(DEVICES, headers=AUTH_A, json=registration(platform="android"))

        assert devices_of(db_session)[0].platform == "android"


class TestCrossUserReassignment:
    """The contract's stated behaviour, and a privacy boundary rather than a tidiness one."""

    def test_the_token_moves_to_the_new_owner(self, client: Any, db_session: Session) -> None:
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        client.post(DEVICES, headers=AUTH_A, json=registration("shared-device"))

        client.post(DEVICES, headers=AUTH_B, json=registration("shared-device"))

        assert [device.fcm_token for device in devices_of(db_session, "user-b")] == [
            "shared-device"
        ]

    def test_the_previous_owner_loses_it(self, client: Any, db_session: Session) -> None:
        """Otherwise the first user keeps receiving pushes on a phone that is not theirs."""
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        client.post(DEVICES, headers=AUTH_A, json=registration("shared-device"))

        client.post(DEVICES, headers=AUTH_B, json=registration("shared-device"))

        assert devices_of(db_session, "user-a") == []

    def test_no_duplicate_row_is_created(self, client: Any, db_session: Session) -> None:
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        client.post(DEVICES, headers=AUTH_A, json=registration("shared-device"))

        client.post(DEVICES, headers=AUTH_B, json=registration("shared-device"))

        assert device_count(db_session) == 1

    def test_the_reassignment_returns_204(self, client: Any) -> None:
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        client.post(DEVICES, headers=AUTH_A, json=registration("shared-device"))

        response = client.post(DEVICES, headers=AUTH_B, json=registration("shared-device"))

        assert response.status_code == 204

    def test_the_other_users_own_devices_are_untouched(
        self, client: Any, db_session: Session
    ) -> None:
        client.get(ME, headers=AUTH_A)
        client.get(ME, headers=AUTH_B)
        client.post(DEVICES, headers=AUTH_A, json=registration("shared-device"))
        client.post(DEVICES, headers=AUTH_A, json=registration("a-private-phone"))

        client.post(DEVICES, headers=AUTH_B, json=registration("shared-device"))

        assert [device.fcm_token for device in devices_of(db_session, "user-a")] == [
            "a-private-phone"
        ]


class TestRejectedRequests:
    def test_an_anonymous_request_is_401(self, client: Any) -> None:
        assert client.post(DEVICES, json=registration()).status_code == 401

    def test_an_empty_token_is_400(self, client: Any, signed_in: None) -> None:
        assert client.post(DEVICES, headers=AUTH_A, json=registration("")).status_code == 400

    def test_a_missing_token_is_400(self, client: Any, signed_in: None) -> None:
        assert client.post(DEVICES, headers=AUTH_A, json={"platform": "ios"}).status_code == 400

    def test_an_unknown_platform_is_400(self, client: Any, signed_in: None) -> None:
        """The column has a CHECK constraint; the schema rejects it before the database has to."""
        response = client.post(DEVICES, headers=AUTH_A, json=registration(platform="windows"))

        assert response.status_code == 400

    def test_nothing_is_stored_for_a_rejected_request(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration(platform="windows"))

        assert device_count(db_session) == 0


class TestAccountDeletionInteraction:
    """FR-017's other half, asserted from this side.

    Requesting deletion deregisters every device. Re-registering afterwards is allowed — the
    account stays usable in the meantime — so this checks the two operations compose rather than
    fight.
    """

    def test_deletion_removes_the_device(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration())

        client.delete(ME, headers=AUTH_A)

        assert device_count(db_session) == 0

    def test_a_device_can_be_registered_again_afterwards(
        self, client: Any, signed_in: None, db_session: Session
    ) -> None:
        client.post(DEVICES, headers=AUTH_A, json=registration())
        client.delete(ME, headers=AUTH_A)

        response = client.post(DEVICES, headers=AUTH_A, json=registration())

        assert response.status_code == 204
        assert device_count(db_session) == 1
