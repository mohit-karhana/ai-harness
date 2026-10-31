from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.claim import Claim
from app.schemas.claim import ClaimCreate


class ClaimValidationError(Exception):
    """Business-rule violation; mapped to HTTP 422 in app.main."""


class ClaimService:
    def __init__(self, session: AsyncSession, max_amount: int) -> None:
        self._session = session
        self._max_amount = max_amount

    async def submit(self, payload: ClaimCreate) -> Claim:
        if payload.incident_date > date.today():
            raise ClaimValidationError("incident_date cannot be in the future")
        if payload.amount > self._max_amount:
            raise ClaimValidationError("amount exceeds the maximum claimable amount")
        claim = Claim(**payload.model_dump())
        self._session.add(claim)
        await self._session.commit()
        return claim
