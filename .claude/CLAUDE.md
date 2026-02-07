# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**lex-docker** is the Docker infrastructure repository for the Meridian Lex system. It contains Dockerfiles and docker-compose configurations for various services deployed on the system.

## Repository Structure

Organize services by purpose:

```
├── services/
│   ├── service-name/
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── README.md
├── shared/
│   ├── base-images/
│   └── common-configs/
└── docs/
    └── deployment-guides/
```

## Docker Development Commands

### Building and Running Services

```bash
# Build a specific service
docker-compose -f services/service-name/docker-compose.yml build

# Start service in foreground (for debugging)
docker-compose -f services/service-name/docker-compose.yml up

# Start service in background
docker-compose -f services/service-name/docker-compose.yml up -d

# View logs
docker-compose -f services/service-name/docker-compose.yml logs -f

# Stop service
docker-compose -f services/service-name/docker-compose.yml down

# Stop and remove volumes
docker-compose -f services/service-name/docker-compose.yml down -v
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

1. Develop and test locally with docker-compose
2. Document configuration in service README
3. Create `.env.example` with all required variables
4. Test build and deployment from clean state
5. Commit Dockerfile and docker-compose.yml
6. Deploy to system using documented procedure

## System Context

This repository is part of the **Meridian Lex** infrastructure:
- **Platform**: Debian 12 Linux
- **User**: meridian
- **Home base**: `~/meridian-home/`
- **Docker**: Installed and configured for non-root use
- **Secrets**: Managed in `~/.config/secrets.yaml`

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

### Multi-Stage Build

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Runtime stage
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER node
CMD ["node", "server.js"]
```

## Troubleshooting

- **Port conflicts**: Check with `docker ps` and `ss -tulpn`
- **Permission errors**: Ensure correct file ownership and container user
- **Network issues**: Verify service names resolve within Docker network
- **Volume data**: Use `docker volume inspect <volume-name>` to locate data
- **Build cache issues**: Use `--no-cache` flag to force fresh build
