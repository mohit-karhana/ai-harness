# Alembic environment (async). Run migrations locally only:
#   alembic upgrade head
# Never run against shared/staging/production databases from an AI session.
from app.models.claim import Base

target_metadata = Base.metadata
