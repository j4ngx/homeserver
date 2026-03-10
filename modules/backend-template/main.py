"""
Backend Template — Minimal FastAPI application.

Provides:
  GET  /         → Welcome message
  GET  /health   → Health check endpoint (used by Docker healthcheck)
  GET  /docs     → Swagger UI (auto-generated)

Copy this module and adapt it for your own backend services.
"""

import os
from datetime import datetime, timezone

from fastapi import FastAPI

APP_NAME = os.getenv("APP_NAME", "backend-template")
APP_ENV = os.getenv("APP_ENV", "production")

app = FastAPI(
    title=APP_NAME,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)


@app.get("/")
async def root():
    """Welcome endpoint."""
    return {
        "service": APP_NAME,
        "environment": APP_ENV,
        "message": "Endurance backend is running.",
    }


@app.get("/health")
async def health():
    """Health check — used by Docker healthcheck and monitoring."""
    return {
        "status": "healthy",
        "service": APP_NAME,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
