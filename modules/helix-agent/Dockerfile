# =============================================================================
# Helix Agent — Homeserver variant
# =============================================================================
# Uses the upstream uv.lock (PyPI-only) for fully reproducible builds.
# The lock file lives in the helix_agent source repo (src/uv.lock).
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1 — Builder
# ---------------------------------------------------------------------------
FROM ghcr.io/astral-sh/uv:0.6-python3.11-bookworm-slim AS builder

WORKDIR /build

# Force dependency resolution against public PyPI
ENV UV_INDEX_URL=https://pypi.org/simple

# Copy manifests and lock file (layer caching)
COPY src/pyproject.toml src/README.md* src/uv.lock* ./

# Install production deps into /build/.venv
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --extra mcp --no-install-project

# Copy source code and install the project itself
COPY src/src/ src/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --extra mcp

# ---------------------------------------------------------------------------
# Stage 2 — Runtime
# ---------------------------------------------------------------------------
FROM python:3.11-slim-bookworm AS runtime

# Install Node.js 20.x for MCP stdio skills (npx)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get purge -y gnupg && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Install gogcli
RUN curl -L https://github.com/steipete/gogcli/releases/latest/download/gog_linux_amd64 -o /usr/local/bin/gog && \
    chmod +x /usr/local/bin/gog

# Create non-root user
RUN groupadd --gid 1000 helix && \
    useradd --uid 1000 --gid helix --create-home helix

WORKDIR /app

# Copy virtual-env from builder
COPY --from=builder /build/.venv /app/.venv

# Copy application code and config
COPY src/src/ src/
COPY src/pyproject.toml ./
COPY src/config.example.yml .
# Use the homeserver module's config.yml (non-secret, customisable per deployment)
COPY config.yml ./
COPY src/prompts/ prompts/

# Create data directory (volume mount target)
RUN mkdir -p /app/data && chown -R helix:helix /app

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONPATH="/app/src" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER helix

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import helix" || exit 1

STOPSIGNAL SIGTERM

ENTRYPOINT ["python", "-m", "helix"]
