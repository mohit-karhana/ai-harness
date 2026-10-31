from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.routers import claims
from app.services.claims import ClaimValidationError

app = FastAPI(title="Claims Intake", version="0.1.0")
app.include_router(claims.router)


@app.exception_handler(ClaimValidationError)
async def claim_validation_handler(_: Request, exc: ClaimValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": {"code": "claim_invalid", "message": str(exc)}},
    )
