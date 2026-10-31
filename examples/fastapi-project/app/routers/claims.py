from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.db import get_session
from app.schemas.claim import ClaimCreate, ClaimRead
from app.services.claims import ClaimService

router = APIRouter(prefix="/v1/claims", tags=["claims"])


def get_claim_service(
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> ClaimService:
    return ClaimService(session, settings.max_claim_amount)


@router.post("", response_model=ClaimRead, status_code=status.HTTP_201_CREATED,
             summary="Submit a new claim")
async def submit_claim(
    payload: ClaimCreate, service: ClaimService = Depends(get_claim_service)
) -> ClaimRead:
    return ClaimRead.model_validate(await service.submit(payload))
