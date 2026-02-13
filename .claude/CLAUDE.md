<!-- IDENTITY-EXCEPTION: functional internal reference — not for public exposure -->
# CLAUDE.md

This file provides guidance when working with code in this repository.

## Project Overview

**Gantry** is the Docker infrastructure suite for the Meridian Lex system and the Stratavore fleet. It contains docker-compose configurations for all services deployed on the system — the support structure from which all fleet vessels are launched and maintained.

## Repository Structure

Services are organized by functional group:

```
├── core/                    # Infrastructure management (Traefik, Authelia, Portainer)
├── storage/                 # Data persistence (PostgreSQL, Qdrant, OpenSearch, Memgraph, RabbitMQ)
├── communication/           # Agent integration (ntfy, API Gateway)
├── observability/           # Monitoring (Prometheus, Grafana, Loki, cAdvisor)
├── utilities/               # Operational tools (FileBrowser, Watchtower)
├── scripts/                 # Initialization and deployment scripts
└── docs/                    # Architecture documentation
```

## Docker Development Commands

### Building and Running Services

```bash
# Start a service group in background
docker compose -f <group>/docker-compose.yml up -d

# View logs
docker compose -f <group>/docker-compose.yml logs -f

# Stop a service group
docker compose -f <group>/docker-compose.yml down

# Stop and remove volumes
docker compose -f <group>/docker-compose.yml down -v
```

### Container Management

```bash
# List running containers
docker ps

# Execute command in running container
docker exec -it <container-name> bash

# View container logs
docker logs -f <container-name>

# Inspect container
docker inspect <container-name>
```

### Image Management

```bash
# List images
docker images

# Remove unused images
docker image prune

# Remove all unused containers, networks, images
docker system prune -a
```

## Docker Infrastructure Standards

### Dockerfile Conventions

- Use specific base image tags (never `:latest` in production)
- Implement multi-stage builds when appropriate
- Run containers as non-root user
- Include `HEALTHCHECK` instructions
- Minimize layers and image size
- Pin dependency versions
- Use `.dockerignore` to exclude unnecessary files

### docker-compose.yml Conventions

- Use version 3.8+ for compose file format
- Define explicit service dependencies with `depends_on`
- Use named volumes for persistent data
- Externalize configuration via environment variables
- Include restart policies (`restart: unless-stopped`)
- Set resource limits where appropriate
- Use networks to isolate service groups

### Security Practices

- **Never commit secrets**: Use `.env.example` templates, actual `.env` files are gitignored
- Store sensitive data in `~/.config/secrets.yaml` (checked by Meridian Lex automatically)
- Run containers with minimal privileges
- Scan images for vulnerabilities before deployment
- Use read-only root filesystems where possible
- Implement proper network segmentation

### Documentation Requirements

Each service directory must include:

- `README.md`: Purpose, configuration, deployment instructions
- `.env.example`: Template for required environment variables
- Health check endpoints and monitoring details
- Backup and recovery procedures (if applicable)

## Credential Management

**CRITICAL**: Always check `~/.config/secrets.yaml` for credentials before requesting passwords. This includes:
- Database passwords
- API keys
- Docker registry credentials
- Service authentication tokens

## Deployment Workflow

1. Run `scripts/init-docker-secrets.sh` to generate credentials
2. Review generated `docker-secrets.env`
3. Deploy with `scripts/deploy-stack.sh` or per-group compose commands
4. Validate service health via Portainer or `docker ps`

## System Context

This repository is part of the **Meridian Lex** infrastructure:
- **Platform**: Debian 12 Linux
- **User**: meridian
- **Home base**: `~/meridian-home/`
- **Docker**: Installed and configured
- **Secrets**: Managed in `~/.config/secrets.yaml`
- **GitHub**: `Meridian-Lex/Gantry`

## Common Patterns

### Service with Database

```yaml
version: '3.8'
services:
  app:
    build: .
    depends_on:
      - db
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/dbname
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    restart: unless-stopped

volumes:
  db-data:
```

## Troubleshooting

- **Port conflicts**: Check with `docker ps` and `ss -tulpn`
- **Permission errors**: Ensure correct file ownership and container user
- **Network issues**: Verify service names resolve within Docker network
- **Volume data**: Use `docker volume inspect <volume-name>` to locate data
- **Build cache issues**: Use `--no-cache` flag to force fresh build
- **Secrets missing**: Run `scripts/init-docker-secrets.sh` to regenerate
