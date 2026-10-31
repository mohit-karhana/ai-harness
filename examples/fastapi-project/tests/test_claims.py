import uuid
from datetime import date, timedelta
from decimal import Decimal

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.routers.claims import get_claim_service
from app.services.claims import ClaimService


class FakeSession:
    def __init__(self) -> None:
        self.added = []

    def add(self, obj) -> None:
        obj.id = obj.id or uuid.uuid4()
        obj.status = obj.status or "submitted"
        self.added.append(obj)

    async def commit(self) -> None:
        pass


@pytest.fixture
async def client():
    app.dependency_overrides[get_claim_service] = lambda: ClaimService(FakeSession(), 1000)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()


async def test_rejects_future_incident_date(client):
    response = await client.post("/v1/claims", json={
        "policy_id": str(uuid.uuid4()),
        "amount": "100.00",
        "incident_date": str(date.today() + timedelta(days=1)),
    })
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "claim_invalid"


async def test_rejects_unknown_fields(client):
    response = await client.post("/v1/claims", json={
        "policy_id": str(uuid.uuid4()),
        "amount": str(Decimal("10")),
        "incident_date": str(date.today()),
        "approved": True,
    })
    assert response.status_code == 422
