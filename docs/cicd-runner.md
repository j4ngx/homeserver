# CI/CD Runner — GitHub Actions Self-Hosted Runner

Provides a GitHub Actions self-hosted runner to execute CI/CD workflows directly on the endurance server. Allows automated testing and deployment of services.

## Quick Reference

| Property | Value |
|----------|-------|
| Image (Docker) | `myoung34/github-runner:2.321.0` |
| Service (Native) | `github-runner.service` |
| Network | `endurance_backend` |
| Labels | `self-hosted,linux,endurance` |

## Deployment Options

### Option 1: Docker Container (Recommended)

```bash
# 1. Install
bash provisioning/scripts/module.sh cicd-runner install

# 2. Configure the .env file
nano modules/cicd-runner/.env

# 3. Start
bash provisioning/scripts/module.sh cicd-runner start
```

### Option 2: Native systemd Service

```bash
sudo bash modules/cicd-runner/install-native.sh
```

This installs the runner binary, creates a dedicated `github-runner` user, and enables a systemd service.

## Configuration

Edit `modules/cicd-runner/.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `RUNNER_NAME` | `endurance-runner` | Name shown in GitHub |
| `RUNNER_LABELS` | `self-hosted,linux,endurance` | Comma-separated labels |
| `RUNNER_SCOPE` | `repo` | Scope: `repo`, `org`, or `enterprise` |
| `REPO_URL` | `https://github.com/j4ngx/homeserver` | Target repository |
| `ACCESS_TOKEN` | *(empty)* | GitHub PAT with `repo` scope |

### Generating a GitHub Token

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens).
2. Generate a new **classic** token with the `repo` scope.
3. Copy the token into `ACCESS_TOKEN` in `.env`.

**Security:** The token is only used for runner registration. Store it securely and rotate periodically.

## Using in Workflows

Reference the runner in your GitHub Actions workflows:

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, endurance]
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: docker compose up -d --build
```

The `runs-on` labels must match the runner's `RUNNER_LABELS`.

## Docker-in-Docker

The Docker container mounts `/var/run/docker.sock`, allowing workflows to run Docker commands (build, push, compose) directly on the host's Docker daemon.

> **Security note:** Mounting the Docker socket grants the runner container *full control* over the host's Docker daemon. This is equivalent to root access on the host. Only use this with trusted workflows and repositories. The socket is intentionally **not** mounted read-only because the runner needs to build images and manage containers.

## Management

### Docker

```bash
# Check status
bash provisioning/scripts/module.sh cicd-runner status

# View logs
bash provisioning/scripts/module.sh cicd-runner logs

# Update runner image
bash provisioning/scripts/module.sh cicd-runner update

# Stop
bash provisioning/scripts/module.sh cicd-runner stop

# Remove
bash provisioning/scripts/module.sh cicd-runner remove
```

### Native systemd

```bash
# Check status
sudo systemctl status github-runner

# View logs
sudo journalctl -u github-runner -f

# Stop
sudo systemctl stop github-runner

# Start
sudo systemctl start github-runner

# Uninstall
sudo systemctl disable github-runner
sudo rm /etc/systemd/system/github-runner.service
sudo userdel -r github-runner
```

## Troubleshooting

### Runner Not Appearing in GitHub

1. Verify `ACCESS_TOKEN` is valid and has `repo` scope.
2. Check `REPO_URL` matches the target repository.
3. Review container logs: `docker compose -f modules/cicd-runner/docker-compose.yml logs`

### Runner Offline After Restart

The Docker container uses `restart: unless-stopped`, so it should auto-recover. If not:

```bash
bash provisioning/scripts/module.sh cicd-runner restart
```
