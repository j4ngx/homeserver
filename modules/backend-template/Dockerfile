# =============================================================================
# Backend Template — Docker image
# =============================================================================
# Multi-stage build: slim Python image for production.
# =============================================================================

FROM python:3.12-slim AS base

# Prevent Python from writing .pyc and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# ── Dependencies ─────────────────────────────────────────────────────────
FROM base AS deps

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ── Application ──────────────────────────────────────────────────────────
FROM deps AS app

COPY . .

# Create non-root user
RUN groupadd -r appuser && \
    useradd -r -g appuser -d /app -s /sbin/nologin appuser && \
    mkdir -p /app/data && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
