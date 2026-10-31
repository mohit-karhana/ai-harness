FROM python:3.12-slim AS base
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home app
USER app
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]
