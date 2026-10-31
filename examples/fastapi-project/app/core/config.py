from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="CLAIMS_", env_file=".env")

    database_url: str  # e.g. postgresql+asyncpg://user:pass@localhost/claims (set via env)
    max_claim_amount: int = 5_000_000


@lru_cache
def get_settings() -> Settings:
    return Settings()
