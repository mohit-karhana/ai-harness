import uuid
from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.models.claim import ClaimStatus


class ClaimCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    policy_id: uuid.UUID
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    incident_date: date


class ClaimRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    policy_id: uuid.UUID
    amount: Decimal
    incident_date: date
    status: ClaimStatus
