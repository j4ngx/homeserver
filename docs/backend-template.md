# Backend Template — Reference API Service

A ready-to-clone FastAPI backend service that serves as the starting point for any new backend deployed on endurance. Includes a Dockerfile, health check, test suite, and CI/CD workflow.

## Quick Reference

| Property | Value |
|----------|-------|
| Framework | FastAPI (Python 3.12) |
| Image | Built locally via Dockerfile |
| Port | 8000 |
| Networks | `endurance_frontend`, `endurance_backend` |
| Health Check | `GET /health` |

## Installation

```bash
# 1. Install
bash provisioning/scripts/module.sh backend-template install

# 2. Configure
nano modules/backend-template/.env

# 3. Start
bash provisioning/scripts/module.sh backend-template start
```

## Configuration

Edit `modules/backend-template/.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | `backend-template` | Application name |
| `APP_PORT` | `8000` | Port exposed to the host |
| `LOG_LEVEL` | `info` | Uvicorn log level |

## Project Layout

```
modules/backend-template/
├── docker-compose.yml    # Compose configuration
├── Dockerfile            # Multi-stage build (slim image)
├── .env.example          # Template for .env
├── main.py               # FastAPI application
├── requirements.txt      # Python dependencies
└── tests/
    └── test_main.py      # Pytest test suite
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Root — returns `{"message": "Endurance backend-template"}` |
| GET | `/health` | Health check — returns `{"status": "healthy"}` |

## Creating a New Service

1. **Copy the template:**
   ```bash
   cp -r modules/backend-template modules/my-service
   ```

2. **Rename the Compose service:**
   Edit `modules/my-service/docker-compose.yml` and change the service name from `backend-template` to `my-service`.

3. **Update the port:**
   Change `APP_PORT` in `.env.example` and the port mapping in `docker-compose.yml`.

4. **Implement your API:**
   Edit `main.py` with your routes and business logic.

5. **Register in the TUI:**
   Add the module to the `MODULE_DESC` and `MODULE_PORT` arrays in `tui/endurance_tui.sh`.

6. **Create CI workflow:**
   Copy `ci/backend-template.yml` to `ci/my-service.yml` and update paths and service names.

7. **Install and start:**
   ```bash
   bash provisioning/scripts/module.sh my-service install
   bash provisioning/scripts/module.sh my-service start
   ```

## Docker Build

The Dockerfile uses a multi-stage build:

1. **Builder stage:** Installs Python dependencies into a virtual environment.
2. **Runtime stage:** Copies only the venv and application code, runs as a non-root `appuser`.

This produces a minimal image (~150 MB) with no build tools.

## Running Tests

```bash
cd modules/backend-template
pip install -r requirements.txt
pytest tests/ -v
```

Or via Docker:

```bash
docker compose -f modules/backend-template/docker-compose.yml \
  run --rm backend-template python -m pytest tests/ -v
```

## CI/CD Pipeline

The `ci/backend-template.yml` workflow:

1. **Test job** (ubuntu-latest): Installs dependencies and runs pytest.
2. **Deploy job** (self-hosted runner): Builds the Docker image and deploys with Compose, then waits for the health check to pass.

Copy to `.github/workflows/backend-template.yml` in your repository.

## Management

```bash
# Check status
bash provisioning/scripts/module.sh backend-template status

# View logs
bash provisioning/scripts/module.sh backend-template logs

# Update (rebuild + deploy)
bash provisioning/scripts/module.sh backend-template update

# Stop
bash provisioning/scripts/module.sh backend-template stop

# Remove
bash provisioning/scripts/module.sh backend-template remove
```

## Access

| URL | Description |
|-----|-------------|
| `http://192.168.1.50:8000` | API root |
| `http://192.168.1.50:8000/health` | Health check |
| `http://192.168.1.50:8000/docs` | Swagger UI (auto-generated) |
