# Gantry Infrastructure Design

**Date:** 2026-02-07
**Status:** Approved
**Version:** 1.0

## Overview

The Gantry infrastructure provides a multi-service containerized stack for the Meridian Lex autonomous agent system. The stack deploys 15 services organized into five functional groups with automated orchestration, network segmentation, and integrated secrets management.

## Architecture

### Service Organization

Services are grouped by function, each with dedicated docker-compose configuration:

**core/** - Infrastructure management
- Portainer (container visibility)
- Traefik (reverse proxy, TLS termination)
- Authelia (authentication + 2FA)

**storage/** - Data persistence
- PostgreSQL 16 + pgvector (agent state database)
- Qdrant (vector memory)
- OpenSearch (log and artifact indexing)
- Memgraph (infrastructure knowledge graph)
- RabbitMQ (message queue coordination)

**observability/** - Monitoring and metrics
- Prometheus (metrics collection)
- Grafana (visualization)
- Loki (log aggregation)
- cAdvisor (container metrics)

**communication/** - Agent integration
- ntfy (bidirectional messaging)
- API Gateway (host-to-container bridge)

**utilities/** - Operational tools
- FileBrowser (filesystem access)
- Watchtower (automated updates)

### Network Topology

Three isolated Docker networks with explicit service membership:

**frontend-network:**
- Public-facing services: Traefik, Authelia, ntfy, API Gateway
- Exposed to homelab network (trusted VLAN)

**backend-network:**
- Internal data services: PostgreSQL, Qdrant, OpenSearch, Memgraph, RabbitMQ, Loki
- API Gateway bridges frontend ↔ backend

**monitoring-network:**
- Observability stack: Prometheus, Grafana, cAdvisor
- Prometheus joins all networks for metrics collection

### Port Exposure Strategy

Direct host access (bypass Traefik) for key services:
- Traefik: 80 (HTTP), 443 (HTTPS)
- Portainer: 9443
- ntfy: 2586
- Grafana: 3000
- PostgreSQL: 5432
- API Gateway: 8000

Provides immediate IP:port access from homelab network while Traefik routing is configured. All services remain accessible via Traefik once DNS/routing established.

## Secrets Management

Integrated with Meridian Lex `~/.config/secrets.yaml` as single source of truth.

### Initialization Script

**Location:** `scripts/init-docker-secrets.sh`

**Workflow:**
1. Reads existing credentials from `~/.config/secrets.yaml`
2. Generates strong random passwords for missing Docker service credentials
3. Updates `~/.config/secrets.yaml` with `docker_services:` section
4. Exports to `docker-secrets.env` (gitignored) for docker-compose
5. Sets proper file permissions (600)

### Secrets Structure

```yaml
# ~/.config/secrets.yaml
docker_services:
  postgres:
    postgres_password: "..."
    lex_db_password: "..."
  rabbitmq:
    admin_password: "..."
    erlang_cookie: "..."
  authelia:
    jwt_secret: "..."
    session_secret: "..."
    encryption_key: "..."
  opensearch:
    admin_password: "..."
  # Additional services...
```

### Compose Integration

Each service group references `docker-secrets.env`:
```yaml
services:
  postgres:
    env_file: ../docker-secrets.env
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

## API Gateway

### Purpose

Bridges host-based Meridian Lex agent to containerized backend services. Thin routing proxy optimized for speed with minimal overhead.

### Implementation

Lightweight HTTP proxy (nginx or Caddy) with protocol translation.

### Endpoints

- `GET/POST /postgres/*` → PostgreSQL (via PostgREST/pg_gateway)
- `POST /qdrant/*` → Qdrant HTTP API
- `POST /opensearch/*` → OpenSearch API
- `POST /rabbitmq/*` → RabbitMQ HTTP API
- `POST /ntfy/*` → ntfy publish endpoint
- `GET /health` → Gateway healthcheck

### Network Position

- Joins `frontend-network` (exposes port 8000 to host)
- Joins `backend-network` (accesses data services)
- No authentication (trusted network, future enhancement)

### Agent Usage

```bash
# Vector search
curl http://localhost:8000/qdrant/collections/memories/points/search \
  -d '{"vector": [...], "limit": 5}'

# Publish status
curl http://localhost:8000/ntfy/lex-agent-status \
  -d "Task started: analyzing codebase"
```

## Communication Layer

### ntfy Topics

**lex-agent-status** - Agent publishes:
- Task start notifications
- Task completion
- Failure alerts
- Waiting state

**lex-agent-commands** - Agent subscribes:
- Operator instructions
- Control signals

**lex-system-alerts** - Infrastructure publishes:
- Certificate expiry warnings
- Service failures
- Backup status
- Critical alerts from Prometheus

### Future Expansion

Topic structure can be refined for optimal communication patterns as operational experience dictates.

## Certificate Management

### Strategy

Self-signed certificates with 30-day validity, automated renewal every 25 days.

### Rotation Script

**Location:** `scripts/rotate-certs.sh`

```bash
# Generate new certificate
openssl req -x509 -nodes -days 30 -newkey rsa:4096 \
  -keyout /var/lib/docker/volumes/traefik_certs/_data/key.pem \
  -out /var/lib/docker/volumes/traefik_certs/_data/cert.pem \
  -subj "/CN=lex.local"

# Traefik hot-reloads via file watcher

# Notify via ntfy
curl -d "Certificate rotated. Next: $(date -d '+25 days')" \
  http://localhost:2586/lex-system-alerts
```

### Cron Schedule

```cron
0 2 */25 * * /path/to/scripts/rotate-certs.sh
```

### Future Enhancement

Internal ACME CA (step-ca) for proper certificate lifecycle management across all services. Tracked as backlog task.

## Update Policy

### Auto-Update Enabled (Watchtower)

Services with `com.centurylinklabs.watchtower.enable=true` label:
- Watchtower (self-update)
- cAdvisor
- Traefik
- FileBrowser

Uses `:latest` or major version tags. Updates checked daily at 3 AM.

### Version-Pinned (No Auto-Update)

Stateful services and observability stack pinned to specific versions:
- PostgreSQL: `ankane/pgvector:pg16`
- Qdrant: specific version tag
- OpenSearch: specific version tag
- Memgraph: specific version tag
- RabbitMQ: `rabbitmq:3.13-management`
- Prometheus, Grafana, Loki: pinned for compatibility
- Authelia: pinned (auth changes need validation)

Manual updates only after reviewing changelogs.

## Deployment Sequence

Services deploy in dependency order with only hard dependencies declared.

### Phase 1 - Core Infrastructure

```bash
docker-compose -f core/docker-compose.yml up -d
```

- Traefik (no dependencies)
- Authelia (depends_on: Traefik with healthcheck)
- Portainer (no dependencies)

### Phase 2 - Storage Layer

```bash
docker-compose -f storage/docker-compose.yml up -d
```

All start in parallel (no inter-dependencies):
- PostgreSQL
- RabbitMQ
- OpenSearch
- Memgraph
- Qdrant

### Phase 3 - Communication

```bash
docker-compose -f communication/docker-compose.yml up -d
```

- ntfy (no dependencies)
- API Gateway (depends_on: PostgreSQL, Qdrant, OpenSearch, RabbitMQ)

### Phase 4 - Observability

```bash
docker-compose -f observability/docker-compose.yml up -d
```

- Loki (no dependencies)
- Prometheus (no dependencies, retries failed scrapes)
- cAdvisor (no dependencies)
- Grafana (depends_on: Prometheus, Loki)

### Phase 5 - Utilities

```bash
docker-compose -f utilities/docker-compose.yml up -d
```

- FileBrowser (no dependencies)
- Watchtower (no dependencies)

### All-in-One Deployment

**Script:** `scripts/deploy-stack.sh`

Executes all phases sequentially with healthcheck validation between phases.

## Healthchecks

All services define healthchecks in docker-compose:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:port/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

Services with `depends_on` use `condition: service_healthy` to ensure prerequisites are actually ready.

## Observability & Alerting

### Prometheus Alert Rules

**Location:** `observability/prometheus/alerts.yml`

Critical alerts:
- **ContainerDown** - Service unavailable >2min
- **HighDiskUsage** - Disk usage >85% for >5min
- **HighMemoryUsage** - Memory usage >90% for >5min
- **CertificateExpiringSoon** - Certificate expires <5 days
- **ServiceHealthcheckFailing** - Healthcheck failed >2min

### Alertmanager

Routes all critical alerts to ntfy:

```yaml
receivers:
  - name: ntfy
    webhook_configs:
      - url: 'http://ntfy:80/lex-system-alerts'
        send_resolved: true
```

### Grafana Dashboards

Pre-configured dashboards:
- Container resource usage (CPU, memory, network, disk)
- Service health status overview
- Traefik request metrics and routing
- PostgreSQL query performance
- RabbitMQ queue depths
- Qdrant vector operations

### Log Aggregation

Loki collects logs from all containers via Docker driver. Grafana provides log exploration with filtering by service, severity, time range.

### Future Expansion

Can be extended to monitor internal Lex agent state, task execution metrics, token usage, and custom application metrics.

## Data Persistence

### Backup Strategy

VM-level snapshots provide data protection:
- Daily VM snapshots
- Backed up to NAS
- No service-level backups required

All stateful data stored in Docker named volumes:
- `postgres_data`
- `qdrant_data`
- `opensearch_data`
- `memgraph_data`
- `rabbitmq_data`
- `grafana_data`
- `prometheus_data`
- `loki_data`
- `portainer_data`
- `authelia_config`
- `traefik_certs`
- `ntfy_cache`, `ntfy_config`
- `fb_db`

## Security Model

### Network-Level Trust

VM runs in isolated VLAN on homelab network. Access from local network is trusted. Public exposure handled separately at homelab infrastructure level.

### Authentication Layer

Authelia provides authentication + 2FA for web UIs:
- Protected: Portainer, FileBrowser, Traefik dashboard, Grafana, Prometheus, RabbitMQ management, OpenSearch, Memgraph, Qdrant
- Public (on trusted network): ntfy, health check endpoints
- Internal only (backend-network): PostgreSQL, Loki, cAdvisor

### Secrets Protection

- Never committed to git (`.gitignore` enforcement)
- Stored in `~/.config/secrets.yaml` (permissions 600)
- `docker-secrets.env` generated dynamically (gitignored, permissions 600)

## Service Configurations

### Core Services

**Portainer CE:**
- Image: `portainer/portainer-ce:latest`
- Mount: `/var/run/docker.sock`, `portainer_data:/data`
- Port: 9443 (direct access)
- Network: frontend

**Traefik v3:**
- Image: `traefik:v3.0`
- Mounts: `/var/run/docker.sock`, `traefik_certs:/certs`
- Ports: 80, 443
- Networks: frontend, backend
- Docker provider enabled

**Authelia:**
- Image: `authelia/authelia`
- Mount: `authelia_config:/config`
- Port: 9091
- Network: frontend
- Depends on: Traefik

### Storage Services

**PostgreSQL + pgvector:**
- Image: `ankane/pgvector:pg16`
- Mount: `postgres_data:/var/lib/postgresql/data`
- Port: 5432 (direct access)
- Network: backend
- Databases: `lex_state`, `lex_tasks`, `lex_memory`

**Qdrant:**
- Image: `qdrant/qdrant` (pinned version)
- Mount: `qdrant_data:/qdrant/storage`
- Port: 6333 (direct access)
- Network: backend
- Collections: Agent memory vectors

**OpenSearch:**
- Image: `opensearchproject/opensearch:latest` (pinned version)
- Mount: `opensearch_data:/usr/share/opensearch/data`
- Port: 9200 (backend only, via gateway)
- Network: backend
- Single-node discovery mode

**Memgraph:**
- Image: `memgraph/memgraph-platform` (pinned version)
- Mount: `memgraph_data:/var/lib/memgraph`
- Ports: 7687 (Bolt), 3001 (UI)
- Network: backend
- Graph schema: Infrastructure relationships

**RabbitMQ:**
- Image: `rabbitmq:3.13-management`
- Mount: `rabbitmq_data:/var/lib/rabbitmq`
- Ports: 5672 (AMQP), 15672 (management)
- Network: backend
- Queues: Tool coordination, multi-model orchestration

### Observability Services

**Prometheus:**
- Image: `prom/prometheus` (pinned version)
- Mounts: `prometheus_data:/prometheus`, config
- Port: 9090
- Networks: monitoring, backend, frontend (scrapes all)
- Retention: 30 days

**Grafana:**
- Image: `grafana/grafana` (pinned version)
- Mount: `grafana_data:/var/lib/grafana`
- Port: 3000 (direct access)
- Network: monitoring
- Depends on: Prometheus, Loki

**Loki:**
- Image: `grafana/loki` (pinned version)
- Mount: `loki_data:/loki`
- Port: 3100 (internal)
- Networks: backend, monitoring

**cAdvisor:**
- Image: `gcr.io/cadvisor/cadvisor:latest`
- Mounts: `/:/rootfs:ro`, `/var/run:/var/run:rw`, `/sys:/sys:ro`, `/var/lib/docker:/var/lib/docker:ro`
- Port: 8080 (internal)
- Network: monitoring

### Communication Services

**ntfy:**
- Image: `binwiederhier/ntfy`
- Command: `serve`
- Mounts: `ntfy_cache:/var/cache/ntfy`, `ntfy_config:/etc/ntfy`
- Port: 2586 (direct access)
- Network: frontend

**API Gateway:**
- Image: `nginx:alpine` or `caddy:alpine`
- Mount: gateway config
- Port: 8000 (host access)
- Networks: frontend, backend
- Depends on: PostgreSQL, Qdrant, OpenSearch, RabbitMQ

### Utility Services

**FileBrowser:**
- Image: `gtstefaniak/filebrowser:latest`
- Mounts: `/home:/srv/home`, `fb_db:/database`
- Port: 8090
- Network: frontend

**Watchtower:**
- Image: `containrrr/watchtower`
- Mount: `/var/run/docker.sock`
- Command: `--cleanup --interval 86400 --label-enable`
- Schedule: Daily at 3 AM

## Implementation Notes

### Initial Setup

1. Run `scripts/init-docker-secrets.sh` to generate credentials
2. Review generated `docker-secrets.env`
3. Deploy services: `scripts/deploy-stack.sh`
4. Configure Authelia users and protected routes
5. Set up Traefik routing labels (when homelab DNS ready)
6. Configure Grafana dashboards and alert routing
7. Test agent connectivity via API Gateway
8. Set up certificate rotation cron job

### Operational Workflow

**Daily:**
- Watchtower checks for updates (3 AM)
- Certificate rotation check (every 25 days at 2 AM)
- VM snapshot (handled by homelab infrastructure)

**As Needed:**
- Monitor ntfy topics for agent status and system alerts
- Access Grafana dashboards for system visibility
- Use Portainer for container management
- FileBrowser for direct filesystem access

**Manual Updates:**
- Review changelogs for pinned services
- Update version tags in docker-compose files
- Deploy updated services
- Validate functionality

### Future Enhancements

Tracked as backlog tasks:
1. Internal ACME CA (step-ca) for certificate lifecycle
2. Refine ntfy topic structure based on operational patterns
3. Expand observability to monitor internal Lex agent state
4. Add request validation and rate limiting to API Gateway
5. Implement connection pooling in API Gateway
6. Network segmentation refinement if security requirements evolve

## Decision Log

| Decision | Rationale | Alternatives Considered |
|----------|-----------|-------------------------|
| Service groups by function | Clear operational boundaries, related services together | Single monolithic stack, fully isolated services |
| Automated dependency orchestration | Resilient startup, proper sequencing | Manual sequential deployment, no orchestration |
| Multi-tier network segmentation | Security boundaries from start | Single shared network, per-group networks |
| Direct port exposure (option B) | Immediate access without homelab DNS setup | Traefik-only routing |
| VM-level backups | Already handled at infrastructure level | Service-level backups, volume snapshots |
| Lex-integrated secrets | Single source of truth, matches existing patterns | Per-service .env files, Docker secrets |
| Auto-update infrastructure only | Safe for stateless tools, protect stateful services | Auto-update everything, manual only |
| Thin API Gateway | Speed, minimal overhead | Rich orchestration API, multiple gateways |
| Simple ntfy topics | Clear separation, easy subscription | Hierarchical topics, single bidirectional |
| Critical alerts only | Actionable signals, low noise | Comprehensive monitoring, minimal alerts |

---

**Design Status:** Approved and ready for implementation.
