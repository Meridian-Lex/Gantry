# Docker Compose Conventions

## File Format

- `version: '3.8'` on all compose files
- Services grouped by function: `core/`, `storage/`, `communication/`, `observability/`, `utilities/`
- One `docker-compose.yml` per functional group — never a single monolithic file

## Service Shape

Every service must have:

```yaml
services:
  my-service:
    image: vendor/image:SPECIFIC_TAG   # Never :latest in storage/core groups
    container_name: stratavore-<name>  # Always prefixed stratavore-
    restart: unless-stopped
    networks:
      - backend-network                # Or frontend-network / monitoring-network
    healthcheck:
      test: [...]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

- `container_name` always `stratavore-<name>` — consistent fleet naming
- `restart: unless-stopped` on all services — never `always` or omitted
- `healthcheck` required on all services — no exceptions
- Pinned image tags — `:latest` only permitted for Portainer/Authelia where upstream breaks on pin

## Secrets Injection

```yaml
env_file:
  - ../docker-secrets.env   # Relative path to root docker-secrets.env
```

- Never inline secrets as `environment:` values
- Static non-secret env vars may use `environment:` block alongside `env_file:`

## Named Volumes

```yaml
volumes:
  postgres_data:    # Declared at top of compose file
  ...
services:
  postgres:
    volumes:
      - postgres_data:/var/lib/postgresql/data
```

- All persistent data in named volumes — never bind mounts for data
- Config files bind-mounted read-only: `./config.yml:/etc/service/config.yml:ro`

## Dependencies

```yaml
depends_on:
  traefik:
    condition: service_healthy   # Always use service_healthy, not service_started
```

- Use `condition: service_healthy` whenever the dependency has a healthcheck
